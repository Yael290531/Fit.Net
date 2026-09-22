import 'dart:convert';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../core/database/app_database.dart';
import '../data/repositories/cortes_repository.dart';

/// Servicio especializado en la generación de documentos y tickets PDF
/// para los cortes de caja y cierres de turno en Fit.Net.
class CortePdfService {
  static final _currencyFormat =
      NumberFormat.currency(symbol: '\$', decimalDigits: 2, locale: 'es_MX');
  static final _dateFormat = DateFormat('dd/MM/yyyy HH:mm:ss');
  static final _shortDateFormat = DateFormat('dd/MM/yyyy HH:mm');

  // Colores institucionales Fit.Net adaptados para PDF
  static const PdfColor _goldColor = PdfColor.fromInt(0xFFD4A84B);
  static const PdfColor _goldDark = PdfColor.fromInt(0xFFB8912F);
  static const PdfColor _darkHeader = PdfColor.fromInt(0xFF141414);
  static const PdfColor _lightBg = PdfColor.fromInt(0xFFF9F9F9);
  static const PdfColor _borderGray = PdfColor.fromInt(0xFFE0E0E0);
  static const PdfColor _textDark = PdfColor.fromInt(0xFF212121);
  static const PdfColor _textMuted = PdfColor.fromInt(0xFF757575);
  static const PdfColor _successGreen = PdfColor.fromInt(0xFF2E7D32);
  static const PdfColor _errorRed = PdfColor.fromInt(0xFFC62828);

  /// Genera el documento PDF formal (tamaño Carta) del corte de turno.
  static Future<Uint8List> generarReporteCorte({
    required CortesCajaData corte,
    required ResumenTurno resumen,
    String? nombreGimnasio = 'FIT.NET GYM & FITNESS',
  }) async {
    final pdf = pw.Document();

    final duracion = corte.fechaCierre != null
        ? corte.fechaCierre!.difference(corte.fechaApertura)
        : DateTime.now().difference(corte.fechaApertura);

    final duracionTexto =
        '${duracion.inHours}h ${duracion.inMinutes.remainder(60)}m';

    // Deserializar desglose de denominaciones si existe
    Map<String, dynamic> desglose = {};
    if (corte.desgloseJson != null && corte.desgloseJson!.isNotEmpty) {
      try {
        desglose = jsonDecode(corte.desgloseJson!);
      } catch (_) {}
    }

    // Datos QR para verificación
    final qrData =
        'FITNET-CORTE|ID:${corte.id}|SUC:${corte.sucursalId}|CAJ:${corte.cajeroUsername}|VENTAS:${corte.totalVentas}|FONDO_SIG:${corte.fondoSiguienteTurno}';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(36),
        header: (context) => _buildHeader(corte, nombreGimnasio!),
        footer: (context) => _buildFooter(context, corte),
        build: (context) => [
          pw.SizedBox(height: 14),

          // ── Datos Generales del Turno ──
          _buildInfoTurno(corte, duracionTexto),
          pw.SizedBox(height: 16),

          // ── Cuadro Principal de Conciliación Financiera ──
          _buildResumenFinanciero(corte),
          pw.SizedBox(height: 16),

          // ── Regla Operativa Fit.Net (Retiro de Venta y Fondo Remanente) ──
          _buildTraspasoTurnoCard(corte),
          pw.SizedBox(height: 16),

          // ── Desglose de Ventas y Arqueo ──
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                flex: 5,
                child: _buildDesgloseOperaciones(corte, resumen),
              ),
              pw.SizedBox(width: 14),
              pw.Expanded(
                flex: 5,
                child: _buildDesgloseEfectivo(corte, desglose),
              ),
            ],
          ),
          pw.SizedBox(height: 16),

          // ── Observaciones (si las hay) ──
          if (corte.observaciones != null && corte.observaciones!.isNotEmpty) ...[
            _buildObservaciones(corte.observaciones!),
            pw.SizedBox(height: 16),
          ],

          // ── Bitácora de Transacciones ──
          _buildTablaMovimientos(resumen.movimientos),
          pw.SizedBox(height: 24),

          // ── Firmas de Conformidad y Código QR ──
          _buildFirmasYQr(corte, qrData),
        ],
      ),
    );

    return pdf.save();
  }

  /// Encabezado con branding Fit.Net y folio del corte
  static pw.Widget _buildHeader(CortesCajaData corte, String nombreGimnasio) {
    final folioCorto = corte.id.length >= 8
        ? corte.id.substring(0, 8).toUpperCase()
        : corte.id.toUpperCase();

    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: _goldColor, width: 2),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                nombreGimnasio,
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: _darkHeader,
                  letterSpacing: 1.2,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'COMPROBANTE OFICIAL DE CORTE DE CAJA Y CIERRE DE TURNO',
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: _textMuted,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: pw.BoxDecoration(
              color: _darkHeader,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'FOLIO DE CORTE',
                  style: pw.TextStyle(
                    color: _goldColor,
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  '#CORT-$folioCorto',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Datos del turno: cajero, sucursal, fechas
  static pw.Widget _buildInfoTurno(CortesCajaData corte, String duracion) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _lightBg,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: _borderGray),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildInfoItem('SUCURSAL', corte.sucursalId),
              pw.SizedBox(height: 6),
              _buildInfoItem('CAJERO EN TURNO', corte.cajeroUsername),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildInfoItem(
                  'APERTURA', _shortDateFormat.format(corte.fechaApertura)),
              pw.SizedBox(height: 6),
              _buildInfoItem(
                'CIERRE / CORTE',
                corte.fechaCierre != null
                    ? _shortDateFormat.format(corte.fechaCierre!)
                    : 'En curso',
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildInfoItem('DURACIÓN TURNO', duracion),
              pw.SizedBox(height: 6),
              _buildInfoItem(
                'ESTADO',
                corte.estado.toUpperCase(),
                color: corte.estado == 'cerrado' ? _successGreen : _goldDark,
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildInfoItem(String label, String value,
      {PdfColor? color}) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 7, color: _textMuted),
        ),
        pw.SizedBox(height: 1),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: color ?? _textDark,
          ),
        ),
      ],
    );
  }

  /// Tabla de Arqueo y Conciliación Financiera
  static pw.Widget _buildResumenFinanciero(CortesCajaData corte) {
    final dif = corte.diferencia;
    final esExacto = dif.abs() < 0.01;
    final esSobrante = dif > 0.01;

    final estadoDifTexto = esExacto
        ? 'CUADRADO EXACTO'
        : esSobrante
            ? '(+) SOBRANTE: ${_currencyFormat.format(dif)}'
            : '(-) FALTANTE: ${_currencyFormat.format(dif.abs())}';

    final colorDif = esExacto
        ? _successGreen
        : esSobrante
            ? PdfColors.orange800
            : _errorRed;

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _borderGray),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const pw.BoxDecoration(
              color: _darkHeader,
              borderRadius: pw.BorderRadius.only(
                topLeft: pw.Radius.circular(5),
                topRight: pw.Radius.circular(5),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'RESUMEN Y CONCILIACIÓN DE CAJA',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 9,
                  ),
                ),
                pw.Text(
                  estadoDifTexto,
                  style: pw.TextStyle(
                    color: colorDif,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(12),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _buildMetricaBox(
                  'FONDO INICIAL',
                  _currencyFormat.format(corte.fondoInicial),
                  'Base de apertura',
                ),
                _buildMetricaBox(
                  '(+) RECARGAS EFECTIVO',
                  _currencyFormat.format(corte.totalRecargas),
                  'Entrada a gaveta',
                  color: _goldDark,
                ),
                _buildMetricaBox(
                  '(=) ESPERADO EN CAJA',
                  _currencyFormat.format(corte.totalEsperado),
                  'Fondo + Recargas',
                ),
                _buildMetricaBox(
                  '(~) EFECTIVO CONTADO',
                  corte.efectivoContado != null
                      ? _currencyFormat.format(corte.efectivoContado!)
                      : 'N/A',
                  'Arqueo físico',
                  color: colorDif,
                ),
                _buildMetricaBox(
                  'DIFERENCIA',
                  _currencyFormat.format(corte.diferencia),
                  esExacto ? 'Sin desfase' : (esSobrante ? 'Sobrante' : 'Faltante'),
                  color: colorDif,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildMetricaBox(String titulo, String valor, String subtitulo,
      {PdfColor? color}) {
    return pw.Column(
      children: [
        pw.Text(
          titulo,
          style: const pw.TextStyle(fontSize: 7, color: _textMuted),
        ),
        pw.SizedBox(height: 3),
        pw.Text(
          valor,
          style: pw.TextStyle(
            fontSize: 13,
            fontWeight: pw.FontWeight.bold,
            color: color ?? _textDark,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          subtitulo,
          style: const pw.TextStyle(fontSize: 6, color: _textMuted),
        ),
      ],
    );
  }

  /// Tarjeta destacada que aplica la ideología Fit.Net
  static pw.Widget _buildTraspasoTurnoCard(CortesCajaData corte) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFFFF9E6), // Dorado muy suave
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: _goldColor, width: 1.5),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            flex: 6,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'POLÍTICA FIT.NET · TRASPASO AL SIGUIENTE TURNO (MODELO TARJETA/SALDO)',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: _goldDark,
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  'El efectivo físico en gaveta proviene de las recargas a las tarjetas. '
                  'Los cobros de suscripción se descuentan del saldo de la tarjeta del cliente (sin entrada de billetes en ese momento). '
                  'Se retira el efectivo cobrado por recargas y la caja queda lista para el siguiente turno con su fondo de \$2,000.00.',
                  style: const pw.TextStyle(fontSize: 7.5, color: _textDark),
                ),
              ],
            ),
          ),
          pw.SizedBox(width: 12),
          pw.Expanded(
            flex: 4,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'RETIRO DE EFECTIVO',
                      style: const pw.TextStyle(fontSize: 7, color: _textMuted),
                    ),
                    pw.Text(
                      _currencyFormat.format(corte.montoRetirado),
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: _textDark,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(width: 14),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: pw.BoxDecoration(
                    color: _darkHeader,
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Text(
                        'FONDO SIG. TURNO',
                        style: pw.TextStyle(
                          color: _goldColor,
                          fontSize: 7,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        _currencyFormat.format(corte.fondoSiguienteTurno),
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 13,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Desglose por concepto de operaciones
  static pw.Widget _buildDesgloseOperaciones(
      CortesCajaData corte, ResumenTurno resumen) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _borderGray),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'DESGLOSE DE OPERACIONES DEL TURNO',
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: _darkHeader,
            ),
          ),
          pw.SizedBox(height: 8),
          _buildFilaConcepto(
            'Recargas en Efectivo (Ingreso a gaveta)',
            _currencyFormat.format(corte.totalRecargas),
            color: _goldDark,
            esNegrita: true,
          ),
          pw.Divider(color: _borderGray, thickness: 0.5),
          _buildFilaConcepto(
            'Suscripciones Cobradas (Vía saldo tarjeta)',
            _currencyFormat.format(corte.totalSuscripciones),
          ),
          pw.Divider(color: _borderGray, thickness: 0.5),
          _buildFilaConcepto(
            'Transacciones Totales',
            '${corte.totalMovimientos} movimientos',
          ),
          pw.Divider(color: _borderGray, thickness: 1),
          _buildFilaConcepto(
            'Total Efectivo a Retirar',
            _currencyFormat.format(corte.montoRetirado),
            esNegrita: true,
            color: _goldDark,
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            '* Los cobros de suscripción se descuentan del saldo de la tarjeta del cliente; el efectivo físico en gaveta proviene de las recargas.',
            style: const pw.TextStyle(fontSize: 6.5, color: _textMuted),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFilaConcepto(String concepto, String monto,
      {bool esNegrita = false, PdfColor? color}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          concepto,
          style: pw.TextStyle(
            fontSize: 8,
            fontWeight: esNegrita ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: color ?? _textDark,
          ),
        ),
        pw.Text(
          monto,
          style: pw.TextStyle(
            fontSize: 8,
            fontWeight: esNegrita ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: color ?? _textDark,
          ),
        ),
      ],
    );
  }

  /// Desglose de billetes y monedas capturados
  static pw.Widget _buildDesgloseEfectivo(
      CortesCajaData corte, Map<String, dynamic> desglose) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _borderGray),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'ARQUEO DE EFECTIVO (DENOMINACIONES)',
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: _darkHeader,
            ),
          ),
          pw.SizedBox(height: 8),
          if (desglose.isEmpty)
            pw.Text(
              'No se capturó desglose de billetes individuales.',
              style: const pw.TextStyle(fontSize: 8, color: _textMuted),
            )
          else ...[
            pw.Wrap(
              spacing: 8,
              runSpacing: 4,
              children: desglose.entries
                  .where((e) => (int.tryParse('${e.value}') ?? 0) > 0)
                  .map(
                    (e) => pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: pw.BoxDecoration(
                        color: _lightBg,
                        borderRadius: pw.BorderRadius.circular(4),
                        border: pw.Border.all(color: _borderGray),
                      ),
                      child: pw.Text(
                        '${e.key}: ${e.value} piezas',
                        style: const pw.TextStyle(
                          fontSize: 7,
                          color: _textDark,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            pw.SizedBox(height: 6),
          ],
          pw.Divider(color: _borderGray, thickness: 1),
          _buildFilaConcepto(
            'Total Físico Contado',
            corte.efectivoContado != null
                ? _currencyFormat.format(corte.efectivoContado!)
                : '\$0.00',
            esNegrita: true,
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildObservaciones(String obs) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: _lightBg,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: _borderGray),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'OBSERVACIONES / NOTAS DEL CAJERO:',
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: _darkHeader,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            obs,
            style: const pw.TextStyle(fontSize: 8, color: _textDark),
          ),
        ],
      ),
    );
  }

  /// Tabla de movimientos ocurridos en el turno
  static pw.Widget _buildTablaMovimientos(
      List<MovimientoTurnoDetalle> movimientos) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'DETALLE DE MOVIMIENTOS REGISTRADOS EN ESTE TURNO',
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            color: _darkHeader,
          ),
        ),
        pw.SizedBox(height: 6),
        if (movimientos.isEmpty)
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _borderGray),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Center(
              child: pw.Text(
                'No se registraron ventas ni transacciones durante este turno.',
                style: const pw.TextStyle(fontSize: 8, color: _textMuted),
              ),
            ),
          )
        else
          pw.TableHelper.fromTextArray(
            headers: ['HORA', 'FOLIO TARJETA', 'CLIENTE', 'CONCEPTO', 'MONTO'],
            data: movimientos.map((m) {
              final shortTarjeta = m.idTarjeta.length >= 8
                  ? m.idTarjeta.substring(0, 8).toUpperCase()
                  : m.idTarjeta;
              return [
                DateFormat('HH:mm:ss').format(m.fecha),
                '#$shortTarjeta',
                m.clienteNombre ?? 'Cliente',
                m.tipo == 'pago' ? 'Cobro Suscripción' : 'Recarga Tarjeta',
                _currencyFormat.format(m.monto),
              ];
            }).toList(),
            headerStyle: pw.TextStyle(
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
              fontSize: 7.5,
            ),
            headerDecoration: const pw.BoxDecoration(color: _darkHeader),
            cellStyle: const pw.TextStyle(fontSize: 7.5, color: _textDark),
            cellAlignment: pw.Alignment.centerLeft,
            cellAlignments: {
              4: pw.Alignment.centerRight,
            },
            rowDecoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: _borderGray, width: 0.5),
              ),
            ),
          ),
      ],
    );
  }

  /// Firmas y Código QR para auditoría
  static pw.Widget _buildFirmasYQr(CortesCajaData corte, String qrData) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        // Código QR
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.BarcodeWidget(
              barcode: pw.Barcode.qrCode(),
              data: qrData,
              width: 55,
              height: 55,
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Escanea para verificar autenticidad',
              style: const pw.TextStyle(fontSize: 6, color: _textMuted),
            ),
          ],
        ),

        // Firma Cajero Saliente
        pw.Expanded(
          child: pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 16),
            child: pw.Column(
              children: [
                pw.Container(
                  height: 35,
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                      bottom: pw.BorderSide(color: _textDark, width: 1),
                    ),
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'ENTREGA: ${corte.cajeroUsername}',
                  style: pw.TextStyle(
                    fontSize: 7.5,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  'Cajero(a) en Turno',
                  style: const pw.TextStyle(fontSize: 6.5, color: _textMuted),
                ),
              ],
            ),
          ),
        ),

        // Firma Supervisor / Siguiente Turno
        pw.Expanded(
          child: pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 16),
            child: pw.Column(
              children: [
                pw.Container(
                  height: 35,
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                      bottom: pw.BorderSide(color: _textDark, width: 1),
                    ),
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'RECIBE FONDO (\$2,000.00)',
                  style: pw.TextStyle(
                    fontSize: 7.5,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  'Supervisor / Cajero Entrante',
                  style: const pw.TextStyle(fontSize: 6.5, color: _textMuted),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Pie de página con numeración y fecha de impresión
  static pw.Widget _buildFooter(pw.Context context, CortesCajaData corte) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: _borderGray, width: 0.5),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Fit.Net System · Impreso el ${_dateFormat.format(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 7, color: _textMuted),
          ),
          pw.Text(
            'Página ${context.pageNumber} de ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 7, color: _textMuted),
          ),
        ],
      ),
    );
  }

  /// Permite imprimir directamente o abrir la vista previa de impresión
  static Future<void> imprimirReporte({
    required CortesCajaData corte,
    required ResumenTurno resumen,
  }) async {
    final pdfBytes = await generarReporteCorte(
      corte: corte,
      resumen: resumen,
    );
    await Printing.layoutPdf(
      onLayout: (format) async => pdfBytes,
      name: 'Corte_Turno_${corte.id.substring(0, 8)}.pdf',
    );
  }
}
