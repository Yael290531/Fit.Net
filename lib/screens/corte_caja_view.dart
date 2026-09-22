import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../app_providers.dart';
import '../core/database/app_database.dart';
import '../data/repositories/cortes_repository.dart';
import '../models/models.dart';
import '../services/corte_pdf_service.dart';
import '../widgets/theme_widgets.dart';

/// Vista completa para el módulo de Corte de Caja y Cierre de Turno.
///
/// Implementa la ideología Fit.Net:
/// - Fondo inicial: $2,000.00 MXN.
/// - Conteo de ventas en vivo durante el turno.
/// - Cierre: se retira la venta acumulada y el siguiente turno entra con el mismo fondo ($2,000.00).
/// - Generación nativa de PDF profesional para impresión de ticket o auditoría.
class CorteCajaView extends StatefulWidget {
  final Usuario usuario;
  final String sucursal;
  final bool esModoAdmin;

  const CorteCajaView({
    super.key,
    required this.usuario,
    required this.sucursal,
    this.esModoAdmin = false,
  });

  @override
  State<CorteCajaView> createState() => _CorteCajaViewState();
}

class _CorteCajaViewState extends State<CorteCajaView> {
  final _currencyFormat =
      NumberFormat.currency(symbol: '\$', decimalDigits: 2, locale: 'es_MX');
  final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  // Controladores de apertura
  final _fondoInicialCtrl = TextEditingController(text: '2000.00');

  // Controladores de arqueo rápido y denominaciones
  final _efectivoContadoCtrl = TextEditingController();
  final _observacionesCtrl = TextEditingController();
  bool _modoDesgloseBilletes = false;

  // Calculadora de denominaciones: billetes y monedas
  final Map<int, TextEditingController> _denominacionesCtrl = {
    1000: TextEditingController(),
    500: TextEditingController(),
    200: TextEditingController(),
    100: TextEditingController(),
    50: TextEditingController(),
    20: TextEditingController(),
    10: TextEditingController(),
    5: TextEditingController(),
    2: TextEditingController(),
    1: TextEditingController(),
  };

  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    for (final entry in _denominacionesCtrl.entries) {
      entry.value.addListener(_calcularTotalDesdeDenominaciones);
    }
  }

  @override
  void dispose() {
    _fondoInicialCtrl.dispose();
    _efectivoContadoCtrl.dispose();
    _observacionesCtrl.dispose();
    for (final ctrl in _denominacionesCtrl.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  void _calcularTotalDesdeDenominaciones() {
    if (!_modoDesgloseBilletes) return;
    double suma = 0.0;
    for (final entry in _denominacionesCtrl.entries) {
      final cantidad = int.tryParse(entry.value.text.trim()) ?? 0;
      suma += entry.key * cantidad;
    }
    _efectivoContadoCtrl.text = suma.toStringAsFixed(2);
    setState(() {});
  }

  void _limpiarDesglose() {
    for (final ctrl in _denominacionesCtrl.values) {
      ctrl.clear();
    }
    _efectivoContadoCtrl.clear();
    setState(() {});
  }

  void _showSnackBar(String msg, {bool isError = false, bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline
                  : isSuccess
                      ? Icons.check_circle_outline
                      : Icons.info_outline,
              color: isError
                  ? FitNetTheme.error
                  : isSuccess
                      ? FitNetTheme.success
                      : FitNetTheme.gold,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: FitNetTheme.cardDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ACCIONES: INICIAR TURNO
  // ═══════════════════════════════════════════════════════════
  Future<void> _iniciarTurno(CortesRepository repo) async {
    final fondo = double.tryParse(_fondoInicialCtrl.text.trim()) ?? 2000.0;
    if (fondo <= 0) {
      _showSnackBar('El fondo inicial debe ser mayor a cero', isError: true);
      return;
    }

    setState(() => _isProcessing = true);
    try {
      await repo.iniciarTurno(
        cajeroUsername: widget.usuario.username,
        fondoInicial: fondo,
      );
      _efectivoContadoCtrl.clear();
      _observacionesCtrl.clear();
      _limpiarDesglose();
      _showSnackBar(
        '✓ Turno iniciado con éxito · Fondo base: ${_currencyFormat.format(fondo)}',
        isSuccess: true,
      );
    } catch (e) {
      _showSnackBar('Error al iniciar turno: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ACCIONES: REALIZAR CORTE DE CAJA
  // ═══════════════════════════════════════════════════════════
  Future<void> _confirmarYRealizarCorte({
    required CortesRepository repo,
    required CortesCajaData turno,
    required ResumenTurno resumen,
  }) async {
    final efectivoText = _efectivoContadoCtrl.text.trim();
    if (efectivoText.isEmpty) {
      _showSnackBar('Por favor ingresa el total de efectivo contado en caja',
          isError: true);
      return;
    }

    final efectivoContado = double.tryParse(efectivoText);
    if (efectivoContado == null || efectivoContado < 0) {
      _showSnackBar('Monto de efectivo inválido', isError: true);
      return;
    }

    final totalEsperado = resumen.totalEsperado;
    final diferencia = efectivoContado - totalEsperado;
    final esExacto = diferencia.abs() < 0.01;
    final esSobrante = diferencia > 0.01;

    // Diálogo de confirmación
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FitNetTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: FitNetTheme.gold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.point_of_sale_rounded,
                  color: FitNetTheme.gold, size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              'Confirmar Corte de Turno',
              style: TextStyle(
                color: FitNetTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '¿Estás seguro de cerrar el turno y realizar el arqueo?',
              style: TextStyle(color: FitNetTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: FitNetTheme.cardLighter,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Column(
                children: [
                  _dialogRow('Fondo Inicial en Gaveta:',
                      _currencyFormat.format(turno.fondoInicial)),
                  const SizedBox(height: 6),
                  _dialogRow('Recargas en Efectivo (+):',
                      _currencyFormat.format(resumen.totalRecargas),
                      color: FitNetTheme.gold),
                  const SizedBox(height: 6),
                  _dialogRow('Cobros vía Tarjeta/Saldo:',
                      _currencyFormat.format(resumen.totalSuscripciones)),
                  const SizedBox(height: 6),
                  _dialogRow('Efectivo Esperado en Gaveta:',
                      _currencyFormat.format(totalEsperado)),
                  const SizedBox(height: 6),
                  _dialogRow('Efectivo Físico Contado:',
                      _currencyFormat.format(efectivoContado)),
                  const Divider(color: Colors.white12, height: 16),
                  _dialogRow(
                    'Diferencia en Gaveta:',
                    esExacto
                        ? 'Exacto (\$0.00)'
                        : esSobrante
                            ? '+${_currencyFormat.format(diferencia)} (Sobrante)'
                            : '${_currencyFormat.format(diferencia)} (Faltante)',
                    color: esExacto
                        ? FitNetTheme.success
                        : (esSobrante ? FitNetTheme.warning : FitNetTheme.error),
                    bold: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: FitNetTheme.gold.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: FitNetTheme.gold.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      color: FitNetTheme.gold, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Se retirará el efectivo de las recargas (${_currencyFormat.format(resumen.totalRecargas)}) y '
                      'quedarán ${_currencyFormat.format(turno.fondoInicial)} para el siguiente turno. Las suscripciones fueron debitadas del saldo de tarjeta.',
                      style: const TextStyle(
                        color: FitNetTheme.textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar',
                style: TextStyle(color: FitNetTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: FitNetTheme.gold,
              foregroundColor: FitNetTheme.backgroundDark,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text('Realizar Corte y Generar PDF',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() => _isProcessing = true);
    try {
      // Recopilar desglose de denominaciones
      final mapDesglose = <String, int>{};
      for (final entry in _denominacionesCtrl.entries) {
        final cant = int.tryParse(entry.value.text.trim()) ?? 0;
        if (cant > 0) {
          mapDesglose['\$${entry.key}'] = cant;
        }
      }

      final corteFinal = await repo.realizarCorte(
        turnoId: turno.id,
        efectivoContado: efectivoContado,
        fondoSiguienteTurno: turno.fondoInicial,
        desgloseJson:
            mapDesglose.isNotEmpty ? jsonEncode(mapDesglose) : null,
        observaciones: _observacionesCtrl.text.trim().isNotEmpty
            ? _observacionesCtrl.text.trim()
            : null,
      );

      _efectivoContadoCtrl.clear();
      _observacionesCtrl.clear();
      _limpiarDesglose();

      if (!mounted) return;
      _showSnackBar('✓ Corte de turno realizado con éxito', isSuccess: true);

      // Mostrar visor e impresión del PDF generado
      await _mostrarVisorPdf(corteFinal, resumen);
    } catch (e) {
      _showSnackBar('Error al realizar corte: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Widget _dialogRow(String label, String value,
      {Color? color, bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: FitNetTheme.textSecondary, fontSize: 12),
        ),
        Text(
          value,
          style: TextStyle(
            color: color ?? FitNetTheme.textPrimary,
            fontSize: 12,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // VISOR MODAL DE PDF
  // ═══════════════════════════════════════════════════════════
  Future<void> _mostrarVisorPdf(
      CortesCajaData corte, ResumenTurno resumen) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: FitNetTheme.cardDark,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 850, maxHeight: 750),
          child: Column(
            children: [
              // Header del visor
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: FitNetTheme.surfaceDark,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  border: Border(
                    bottom: BorderSide(
                        color: Colors.white.withValues(alpha: 0.06)),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: FitNetTheme.gold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.picture_as_pdf_rounded,
                          color: FitNetTheme.gold, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Comprobante de Corte · Folio #${corte.id.substring(0, 8).toUpperCase()}',
                            style: const TextStyle(
                              color: FitNetTheme.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Cajero: ${corte.cajeroUsername} · ${_dateFormat.format(corte.fechaCierre ?? DateTime.now())}',
                            style: const TextStyle(
                              color: FitNetTheme.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: FitNetTheme.textSecondary),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),

              // Visor interactivo nativo con PdfPreview
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                  child: PdfPreview(
                    build: (format) => CortePdfService.generarReporteCorte(
                      corte: corte,
                      resumen: resumen,
                    ),
                    canChangeOrientation: false,
                    canChangePageFormat: false,
                    canDebug: false,
                    actions: const [],
                    loadingWidget: const Center(
                      child: CircularProgressIndicator(
                          color: FitNetTheme.gold),
                    ),
                    pdfFileName:
                        'Corte_Turno_${corte.id.substring(0, 8)}.pdf',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // CONSTRUCCIÓN PRINCIPAL DE LA VISTA
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final providers = AppProviders.of(context);
    final repo = providers.cortesRepo(widget.sucursal);

    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 900;

    return StreamBuilder<CortesCajaData?>(
      stream: widget.esModoAdmin
          ? repo.watchTurnoActivoSucursal()
          : repo.watchTurnoActivo(widget.usuario.username),
      builder: (context, turnoSnap) {
        final turno = turnoSnap.data;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Sección 1: Turno Activo o Apertura ──
            if (turno == null)
              _buildCardAperturaTurno(repo, isWide)
            else
              _buildTurnoActivoCard(repo, turno, isWide),

            const SizedBox(height: 32),

            // ── Sección 2: Historial de Cortes de la Sucursal ──
            _buildHistorialCortes(repo, isWide),
          ],
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════
  // WIDGET: CARD DE APERTURA DE TURNO
  // ═══════════════════════════════════════════════════════════
  Widget _buildCardAperturaTurno(CortesRepository repo, bool isWide) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isWide ? 28 : 18),
      decoration: BoxDecoration(
        color: FitNetTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: FitNetTheme.gold.withValues(alpha: 0.25),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: FitNetTheme.gold.withValues(alpha: 0.05),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: FitNetTheme.goldGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.point_of_sale_rounded,
                  color: FitNetTheme.backgroundDark,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Apertura de Turno de Caja',
                      style: TextStyle(
                        color: FitNetTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'No hay ningún turno abierto actualmente en ${widget.sucursal}. Inicia tu turno registrando el fondo base.',
                      style: const TextStyle(
                        color: FitNetTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Divider(color: Colors.white.withValues(alpha: 0.06)),
          const SizedBox(height: 20),

          // Explicación de la regla de los $2,000
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: FitNetTheme.gold.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: FitNetTheme.gold.withValues(alpha: 0.2),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.shield_outlined,
                    color: FitNetTheme.gold, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Regla Operativa Fit.Net: Todo cajero inicia con un fondo base de \$2,000.00 MXN para dar cambio. '
                    'Al final del turno, se retiran las ventas y el siguiente cajero entra con este mismo fondo.',
                    style: TextStyle(
                      color: FitNetTheme.textPrimary,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Formulario de apertura
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Fondo Inicial de Caja (MXN)',
                      style: TextStyle(
                        color: FitNetTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _fondoInicialCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      style: const TextStyle(
                        color: FitNetTheme.gold,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.attach_money_rounded),
                        hintText: '2000.00',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 3,
                child: GoldButton(
                  label: 'Iniciar Turno con \$2,000.00',
                  icon: Icons.play_arrow_rounded,
                  isLoading: _isProcessing,
                  onPressed: () => _iniciarTurno(repo),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // WIDGET: TURNO EN CURSO Y ARQUEO
  // ═══════════════════════════════════════════════════════════
  Widget _buildTurnoActivoCard(
      CortesRepository repo, CortesCajaData turno, bool isWide) {
    return StreamBuilder<ResumenTurno>(
      stream: repo.watchResumenTurno(turno),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(color: FitNetTheme.gold),
            ),
          );
        }

        final resumen = snap.data!;
        final totalEsperado = resumen.totalEsperado;
        final efectivoContado =
            double.tryParse(_efectivoContadoCtrl.text.trim()) ?? 0.0;
        final hayEfectivoIngresado =
            _efectivoContadoCtrl.text.trim().isNotEmpty;
        final diferencia = efectivoContado - totalEsperado;

        final esExacto = hayEfectivoIngresado && diferencia.abs() < 0.01;
        final esSobrante = hayEfectivoIngresado && diferencia > 0.01;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner de Estado Activo
            _buildBannerTurnoActivo(turno, isWide),
            const SizedBox(height: 20),

            // Métricas del turno en curso
            _buildMetricasTurno(turno, resumen, totalEsperado, isWide),
            const SizedBox(height: 24),

            // Panel de Arqueo y Cierre
            Container(
              padding: EdgeInsets.all(isWide ? 28 : 18),
              decoration: BoxDecoration(
                color: FitNetTheme.cardDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.calculate_rounded,
                              color: FitNetTheme.gold, size: 22),
                          SizedBox(width: 10),
                          Text(
                            'Arqueo de Caja y Cierre de Turno',
                            style: TextStyle(
                              color: FitNetTheme.textPrimary,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      // Toggle de modo billetes
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _modoDesgloseBilletes = !_modoDesgloseBilletes;
                            if (!_modoDesgloseBilletes) {
                              _limpiarDesglose();
                            }
                          });
                        },
                        icon: Icon(
                          _modoDesgloseBilletes
                              ? Icons.view_headline_rounded
                              : Icons.format_list_numbered_rounded,
                          color: FitNetTheme.gold,
                          size: 18,
                        ),
                        label: Text(
                          _modoDesgloseBilletes
                              ? 'Conteo Directo'
                              : 'Desglose por Billetes',
                          style: const TextStyle(
                            color: FitNetTheme.gold,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Cuenta el dinero físico que hay en la gaveta y digítalo a continuación para calcular el balance.',
                    style: TextStyle(
                        color: FitNetTheme.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 20),

                  // Si activó el desglose por billetes
                  if (_modoDesgloseBilletes) ...[
                    _buildCalculadoraDenominaciones(isWide),
                    const SizedBox(height: 20),
                  ],

                  // Campo principal de Efectivo Físico
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Efectivo Físico Total Contado en Gaveta',
                              style: TextStyle(
                                color: FitNetTheme.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _efectivoContadoCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              readOnly: _modoDesgloseBilletes,
                              onChanged: (_) => setState(() {}),
                              style: const TextStyle(
                                color: FitNetTheme.textPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                              decoration: InputDecoration(
                                prefixIcon:
                                    const Icon(Icons.attach_money_rounded),
                                hintText: '0.00',
                                helperText: _modoDesgloseBilletes
                                    ? 'Calculado automáticamente desde las denominaciones'
                                    : 'Digita el total físico contado',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Indicador de Diferencia en Vivo
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Estado de Balance (Diferencia)',
                              style: TextStyle(
                                color: FitNetTheme.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              height: 60,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16),
                              decoration: BoxDecoration(
                                color: !hayEfectivoIngresado
                                    ? FitNetTheme.cardLighter
                                    : esExacto
                                        ? FitNetTheme.success
                                            .withValues(alpha: 0.12)
                                        : (esSobrante
                                            ? FitNetTheme.warning
                                                .withValues(alpha: 0.12)
                                            : FitNetTheme.error
                                                .withValues(alpha: 0.12)),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: !hayEfectivoIngresado
                                      ? Colors.white.withValues(alpha: 0.08)
                                      : esExacto
                                          ? FitNetTheme.success
                                          : (esSobrante
                                              ? FitNetTheme.warning
                                              : FitNetTheme.error),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    !hayEfectivoIngresado
                                        ? Icons.hourglass_empty_rounded
                                        : esExacto
                                            ? Icons.check_circle_rounded
                                            : (esSobrante
                                                ? Icons.arrow_upward_rounded
                                                : Icons.arrow_downward_rounded),
                                    color: !hayEfectivoIngresado
                                        ? FitNetTheme.textSecondary
                                        : esExacto
                                            ? FitNetTheme.success
                                            : (esSobrante
                                                ? FitNetTheme.warning
                                                : FitNetTheme.error),
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          !hayEfectivoIngresado
                                              ? 'Esperando conteo...'
                                              : esExacto
                                                  ? 'Caja Cuadrada Exacta'
                                                  : (esSobrante
                                                      ? 'Sobrante en Caja'
                                                      : 'Faltante en Caja'),
                                          style: TextStyle(
                                            color: !hayEfectivoIngresado
                                                ? FitNetTheme.textSecondary
                                                : esExacto
                                                    ? FitNetTheme.success
                                                    : (esSobrante
                                                        ? FitNetTheme.warning
                                                        : FitNetTheme.error),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        Text(
                                          !hayEfectivoIngresado
                                              ? 'Ingresa el efectivo'
                                              : _currencyFormat
                                                  .format(diferencia),
                                          style: TextStyle(
                                            color: !hayEfectivoIngresado
                                                ? FitNetTheme.textSecondary
                                                : esExacto
                                                    ? FitNetTheme.success
                                                    : (esSobrante
                                                        ? FitNetTheme.warning
                                                        : FitNetTheme.error),
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
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
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Regla Fit.Net: Retiro de efectivo de recargas y fondo remanente
                  _buildCardIdeologia(resumen.totalRecargas, turno.fondoInicial,
                      resumen.totalSuscripciones),
                  const SizedBox(height: 20),

                  // Observaciones
                  TextFormField(
                    controller: _observacionesCtrl,
                    maxLines: 2,
                    style: const TextStyle(
                        color: FitNetTheme.textPrimary, fontSize: 13),
                    decoration: const InputDecoration(
                      labelText: 'Observaciones o notas del corte (opcional)',
                      prefixIcon: Icon(Icons.notes_rounded),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Botón de acción principal
                  GoldButton(
                    label: 'Realizar Corte de Caja y Generar PDF',
                    icon: Icons.picture_as_pdf_rounded,
                    isLoading: _isProcessing,
                    onPressed: () => _confirmarYRealizarCorte(
                      repo: repo,
                      turno: turno,
                      resumen: resumen,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBannerTurnoActivo(CortesCajaData turno, bool isWide) {
    final duracion = DateTime.now().difference(turno.fechaApertura);
    final duracionTexto =
        '${duracion.inHours}h ${duracion.inMinutes.remainder(60)}m';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: FitNetTheme.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: FitNetTheme.success.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: FitNetTheme.success,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'TURNO ACTIVO EN CURSO',
                      style: TextStyle(
                        color: FitNetTheme.success,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Tiempo activo: $duracionTexto',
                        style: const TextStyle(
                          color: FitNetTheme.textSecondary,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Responsable: ${turno.cajeroUsername} · Abierto el ${_dateFormat.format(turno.fechaApertura)}',
                  style: const TextStyle(
                    color: FitNetTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricasTurno(CortesCajaData turno, ResumenTurno resumen,
      double totalEsperado, bool isWide) {
    final metricas = [
      MetricIndicator(
        label: 'Fondo Inicial',
        value: _currencyFormat.format(turno.fondoInicial),
        icon: Icons.savings_outlined,
        subtitle: 'Base inicial del turno',
      ),
      MetricIndicator(
        label: 'Recargas Efectivo',
        value: _currencyFormat.format(resumen.totalRecargas),
        icon: Icons.add_card_rounded,
        valueColor: FitNetTheme.gold,
        subtitle: 'Entrada física a gaveta',
      ),
      MetricIndicator(
        label: 'Cobros Tarjeta',
        value: _currencyFormat.format(resumen.totalSuscripciones),
        icon: Icons.credit_card_rounded,
        valueColor: Colors.cyanAccent,
        subtitle: 'Suscripciones (Saldo/Puntos)',
      ),
      MetricIndicator(
        label: 'Esperado en Gaveta',
        value: _currencyFormat.format(totalEsperado),
        icon: Icons.account_balance_wallet_rounded,
        valueColor: FitNetTheme.success,
        subtitle: 'Fondo + Recargas',
      ),
    ];

    if (isWide) {
      return Row(
        children: metricas
            .map((m) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: m,
                  ),
                ))
            .toList(),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: metricas[0]),
            const SizedBox(width: 8),
            Expanded(child: metricas[1]),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: metricas[2]),
            const SizedBox(width: 8),
            Expanded(child: metricas[3]),
          ],
        ),
      ],
    );
  }

  Widget _buildCalculadoraDenominaciones(bool isWide) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FitNetTheme.cardLighter,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Calculadora por Denominaciones de Billetes y Monedas',
                style: TextStyle(
                  color: FitNetTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextButton(
                onPressed: _limpiarDesglose,
                child: const Text('Limpiar conteo',
                    style: TextStyle(color: FitNetTheme.error, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: _denominacionesCtrl.entries.map((entry) {
              final denom = entry.key;
              final ctrl = entry.value;
              return SizedBox(
                width: 140,
                child: TextFormField(
                  controller: ctrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(
                      color: FitNetTheme.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: '\$$denom MXN',
                    hintText: '0 pzas',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCardIdeologia(double totalRecargas, double fondoRemanente,
      double totalSuscripciones) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            FitNetTheme.cardLighter,
            FitNetTheme.gold.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: FitNetTheme.gold.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: FitNetTheme.gold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.swap_horiz_rounded,
                color: FitNetTheme.gold, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'POLÍTICA FIT.NET: ARQUEO Y FONDOS',
                  style: TextStyle(
                    color: FitNetTheme.gold,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                        color: FitNetTheme.textPrimary, fontSize: 12),
                    children: [
                      const TextSpan(
                          text: 'Se retira de gaveta el efectivo de recargas: '),
                      TextSpan(
                        text: _currencyFormat.format(totalRecargas),
                        style: const TextStyle(
                          color: FitNetTheme.gold,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const TextSpan(
                          text: '. El siguiente turno entra con el mismo fondo base de '),
                      TextSpan(
                        text: _currencyFormat.format(fondoRemanente),
                        style: const TextStyle(
                          color: FitNetTheme.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const TextSpan(
                          text: '. (Los pagos de suscripción por '),
                      TextSpan(
                        text: _currencyFormat.format(totalSuscripciones),
                        style: const TextStyle(
                          color: Colors.cyanAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const TextSpan(
                          text:
                              ' se debitan directo del saldo de la tarjeta y no ingresan como billetes físicos).'),
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

  // ═══════════════════════════════════════════════════════════
  // WIDGET: HISTORIAL DE CORTES DE CAJA
  // ═══════════════════════════════════════════════════════════
  Widget _buildHistorialCortes(CortesRepository repo, bool isWide) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.history_rounded, color: FitNetTheme.gold, size: 20),
            SizedBox(width: 10),
            Text(
              'Historial de Cortes Realizados',
              style: TextStyle(
                color: FitNetTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Registro auditable de turnos anteriores cerrados y comprobantes oficiales',
          style: TextStyle(color: FitNetTheme.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 16),

        StreamBuilder<List<CortesCajaData>>(
          stream: widget.esModoAdmin
              ? repo.watchHistorialGlobalCortes()
              : repo.watchHistorialCortes(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(color: FitNetTheme.gold),
                ),
              );
            }

            final cortes = snap.data!;
            if (cortes.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: FitNetTheme.cardDark,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.receipt_long_outlined,
                        color: FitNetTheme.textSecondary, size: 36),
                    SizedBox(height: 12),
                    Text(
                      'No hay cortes registrados en esta sucursal todavía.',
                      style: TextStyle(
                          color: FitNetTheme.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: cortes.map((corte) {
                final shortId = corte.id.length >= 8
                    ? corte.id.substring(0, 8).toUpperCase()
                    : corte.id.toUpperCase();

                final esExacto = corte.diferencia.abs() < 0.01;
                final esSobrante = corte.diferencia > 0.01;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: FitNetTheme.cardDark,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: FitNetTheme.gold.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.receipt_long_rounded,
                          color: FitNetTheme.gold,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Corte #$shortId',
                                  style: const TextStyle(
                                    color: FitNetTheme.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: esExacto
                                        ? FitNetTheme.success
                                            .withValues(alpha: 0.15)
                                        : (esSobrante
                                            ? FitNetTheme.warning
                                                .withValues(alpha: 0.15)
                                            : FitNetTheme.error
                                                .withValues(alpha: 0.15)),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    esExacto
                                        ? 'Exacto'
                                        : (esSobrante
                                            ? 'Sobrante ${_currencyFormat.format(corte.diferencia)}'
                                            : 'Faltante ${_currencyFormat.format(corte.diferencia)}'),
                                    style: TextStyle(
                                      color: esExacto
                                          ? FitNetTheme.success
                                          : (esSobrante
                                              ? FitNetTheme.warning
                                              : FitNetTheme.error),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Cajero: ${corte.cajeroUsername} · Sucursal: ${corte.sucursalId}',
                              style: const TextStyle(
                                  color: FitNetTheme.textSecondary,
                                  fontSize: 11),
                            ),
                            Text(
                              'Cierre: ${corte.fechaCierre != null ? _dateFormat.format(corte.fechaCierre!) : 'N/A'}',
                              style: const TextStyle(
                                  color: FitNetTheme.textSecondary,
                                  fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Venta Retirada: ${_currencyFormat.format(corte.montoRetirado)}',
                            style: const TextStyle(
                              color: FitNetTheme.gold,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Fondo Dejado: ${_currencyFormat.format(corte.fondoSiguienteTurno)}',
                            style: const TextStyle(
                              color: FitNetTheme.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 6),
                          OutlinedButton.icon(
                            onPressed: () async {
                              final resumen =
                                  await repo.obtenerResumenTurno(corte);
                              await _mostrarVisorPdf(corte, resumen);
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: FitNetTheme.gold,
                              side: BorderSide(
                                  color:
                                      FitNetTheme.gold.withValues(alpha: 0.5)),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.picture_as_pdf_rounded,
                                size: 14),
                            label: const Text('Ver / Imprimir PDF',
                                style: TextStyle(fontSize: 11)),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}
