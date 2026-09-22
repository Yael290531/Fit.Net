import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';

/// Información de resumen de ventas y movimientos durante un turno.
class ResumenTurno {
  final double fondoInicial;
  final double totalSuscripciones;
  final double totalRecargas;
  final double totalVentas;
  final double totalEsperado;
  final int totalTransacciones;
  final List<MovimientoTurnoDetalle> movimientos;

  const ResumenTurno({
    required this.fondoInicial,
    required this.totalSuscripciones,
    required this.totalRecargas,
    required this.totalVentas,
    required this.totalEsperado,
    required this.totalTransacciones,
    required this.movimientos,
  });
}

/// Detalle de cada movimiento ocurrido en el turno.
class MovimientoTurnoDetalle {
  final String id;
  final String idTarjeta;
  final String tipo; // 'recarga', 'pago', etc.
  final double monto;
  final DateTime fecha;
  final String? clienteNombre;

  const MovimientoTurnoDetalle({
    required this.id,
    required this.idTarjeta,
    required this.tipo,
    required this.monto,
    required this.fecha,
    this.clienteNombre,
  });
}

/// Repositorio para la gestión de turnos, arqueos y cortes de caja.
///
/// Implementa la ideología Fit.Net:
/// - Fondo base inicial: $2,000.00 MXN.
/// - Conteo de ventas en tiempo real durante el turno.
/// - Cierre de turno: se retira el monto vendido ("se quita la venta").
/// - El fondo remanente para el siguiente turno queda exactamente en $2,000.00 MXN.
class CortesRepository {
  final AppDatabase _db;
  final String sucursalId;
  final _uuid = const Uuid();

  CortesRepository(this._db, {required this.sucursalId});

  // ── Streams ────────────────────────────────────────────────────────

  /// Stream del turno actualmente abierto para la sucursal y/o cajero.
  Stream<CortesCajaData?> watchTurnoActivo(String cajeroUsername) {
    return (_db.select(_db.cortesCaja)
          ..where((t) =>
              t.sucursalId.equals(sucursalId) &
              t.estado.equals('abierto') &
              t.cajeroUsername.equals(cajeroUsername))
          ..orderBy([
            (t) => OrderingTerm(
                  expression: t.fechaApertura,
                  mode: OrderingMode.desc,
                ),
          ])
          ..limit(1))
        .watchSingleOrNull();
  }

  /// Stream de cualquier turno abierto en la sucursal (para cajero o admin).
  Stream<CortesCajaData?> watchTurnoActivoSucursal() {
    return (_db.select(_db.cortesCaja)
          ..where((t) =>
              t.sucursalId.equals(sucursalId) & t.estado.equals('abierto'))
          ..orderBy([
            (t) => OrderingTerm(
                  expression: t.fechaApertura,
                  mode: OrderingMode.desc,
                ),
          ])
          ..limit(1))
        .watchSingleOrNull();
  }

  /// Stream de todo el historial de cortes cerrados en la sucursal.
  Stream<List<CortesCajaData>> watchHistorialCortes() {
    return (_db.select(_db.cortesCaja)
          ..where((t) =>
              t.sucursalId.equals(sucursalId) & t.estado.equals('cerrado'))
          ..orderBy([
            (t) => OrderingTerm(
                  expression: t.fechaCierre,
                  mode: OrderingMode.desc,
                ),
          ]))
        .watch();
  }

  /// Stream global de todos los cortes cerrados (para el Administrador Global).
  Stream<List<CortesCajaData>> watchHistorialGlobalCortes() {
    return (_db.select(_db.cortesCaja)
          ..where((t) => t.estado.equals('cerrado'))
          ..orderBy([
            (t) => OrderingTerm(
                  expression: t.fechaCierre,
                  mode: OrderingMode.desc,
                ),
          ]))
        .watch();
  }

  // ── Lecturas ───────────────────────────────────────────────────────

  /// Obtiene el turno activo actual del cajero si existe.
  Future<CortesCajaData?> obtenerTurnoActivo(String cajeroUsername) async {
    return (_db.select(_db.cortesCaja)
          ..where((t) =>
              t.sucursalId.equals(sucursalId) &
              t.estado.equals('abierto') &
              t.cajeroUsername.equals(cajeroUsername))
          ..orderBy([
            (t) => OrderingTerm(
                  expression: t.fechaApertura,
                  mode: OrderingMode.desc,
                ),
          ])
          ..limit(1))
        .getSingleOrNull();
  }

  /// Obtiene cualquier turno abierto en la sucursal.
  Future<CortesCajaData?> obtenerTurnoActivoSucursal() async {
    return (_db.select(_db.cortesCaja)
          ..where((t) =>
              t.sucursalId.equals(sucursalId) & t.estado.equals('abierto'))
          ..orderBy([
            (t) => OrderingTerm(
                  expression: t.fechaApertura,
                  mode: OrderingMode.desc,
                ),
          ])
          ..limit(1))
        .getSingleOrNull();
  }

  /// Construye la consulta de movimientos para un turno dado.
  JoinedSelectStatement _buildMovimientosTurnoQuery(CortesCajaData turno) {
    final desde = turno.fechaApertura;
    final hasta = turno.fechaCierre;

    final query = _db.select(_db.movimientos).join([
      leftOuterJoin(
        _db.tarjetas,
        _db.tarjetas.idTarjeta.equalsExp(_db.movimientos.idTarjeta),
      ),
      leftOuterJoin(
        _db.clientes,
        _db.clientes.id.equalsExp(_db.tarjetas.clienteId),
      ),
    ]);

    // Filtrar por sucursal y fecha de apertura del turno.
    // Si el turno está abierto (fechaCierre == null), no restringimos límite superior
    // para capturar instantáneamente cualquier movimiento nuevo sin desfases de reloj.
    if (hasta != null) {
      query.where(
        _db.movimientos.sucursalId.equals(sucursalId) &
            _db.movimientos.fecha.isBiggerOrEqualValue(desde) &
            _db.movimientos.fecha.isSmallerOrEqualValue(hasta),
      );
    } else {
      query.where(
        _db.movimientos.sucursalId.equals(sucursalId) &
            _db.movimientos.fecha.isBiggerOrEqualValue(desde),
      );
    }

    query.orderBy([
      OrderingTerm(
        expression: _db.movimientos.fecha,
        mode: OrderingMode.desc,
      ),
    ]);

    return query;
  }

  /// Procesa las filas de la consulta para calcular el desglose del turno.
  ResumenTurno _procesarFilasResumen(CortesCajaData turno, List<TypedResult> rows) {
    double totalSuscripciones = 0.0;
    double totalRecargas = 0.0;
    final movimientosDetalle = <MovimientoTurnoDetalle>[];

    for (final row in rows) {
      final mov = row.readTable(_db.movimientos);
      final cliente = row.readTableOrNull(_db.clientes);

      if (mov.tipo == 'pago') {
        totalSuscripciones += mov.monto;
      } else if (mov.tipo == 'recarga') {
        totalRecargas += mov.monto;
      }

      movimientosDetalle.add(
        MovimientoTurnoDetalle(
          id: mov.id,
          idTarjeta: mov.idTarjeta,
          tipo: mov.tipo,
          monto: mov.monto,
          fecha: mov.fecha,
          clienteNombre: cliente?.nombre,
        ),
      );
    }

    // ── LÓGICA DE TARJETA CON SALDO/PUNTOS ──
    // 1. El cliente recarga saldo/puntos a su tarjeta entregando efectivo físico al cajero.
    //    Por tanto, el efectivo que ingresa a la gaveta de caja proviene de las RECARGAS.
    // 2. El pago de suscripciones se debita del saldo/puntos de la tarjeta,
    //    por lo que no entra dinero en billetes en ese momento a la gaveta.
    // 3. El efectivo físico esperado en caja = Fondo Inicial ($2,000) + Total Recargas.
    final totalEfectivoCaja = totalRecargas;
    final totalEsperado = turno.fondoInicial + totalEfectivoCaja;

    return ResumenTurno(
      fondoInicial: turno.fondoInicial,
      totalSuscripciones: totalSuscripciones,
      totalRecargas: totalRecargas,
      totalVentas: totalEfectivoCaja, // Dinero físico que entra a caja
      totalEsperado: totalEsperado,
      totalTransacciones: movimientosDetalle.length,
      movimientos: movimientosDetalle,
    );
  }

  /// Stream reactivo del resumen de movimientos del turno en tiempo real.
  /// Emite automáticamente cada vez que se registra un nuevo cliente, recarga o pago.
  Stream<ResumenTurno> watchResumenTurno(CortesCajaData turno) {
    return _buildMovimientosTurnoQuery(turno)
        .watch()
        .map((rows) => _procesarFilasResumen(turno, rows));
  }

  /// Obtiene el resumen de ventas y movimientos registrados para un turno dado (Future puntual).
  Future<ResumenTurno> obtenerResumenTurno(CortesCajaData turno) async {
    final rows = await _buildMovimientosTurnoQuery(turno).get();
    return _procesarFilasResumen(turno, rows);
  }

  // ── Escrituras ─────────────────────────────────────────────────────

  /// Inicia un nuevo turno para el cajero con fondo base ($2,000 por defecto).
  Future<CortesCajaData> iniciarTurno({
    required String cajeroUsername,
    double fondoInicial = 2000.0,
  }) async {
    // Validar si ya hay un turno abierto
    final existente = await obtenerTurnoActivoSucursal();
    if (existente != null) {
      if (existente.cajeroUsername == cajeroUsername) {
        return existente;
      }
      throw Exception(
        'Ya existe un turno abierto en $sucursalId a cargo de ${existente.cajeroUsername}. '
        'Debes realizar el corte de ese turno antes de iniciar uno nuevo.',
      );
    }

    final id = _uuid.v4();
    final now = DateTime.now();

    final companion = CortesCajaCompanion.insert(
      id: id,
      sucursalId: sucursalId,
      cajeroUsername: cajeroUsername,
      fechaApertura: now,
      fondoInicial: Value(fondoInicial),
      totalVentas: const Value(0.0),
      totalEsperado: Value(fondoInicial),
      diferencia: const Value(0.0),
      montoRetirado: const Value(0.0),
      fondoSiguienteTurno: Value(fondoInicial),
      totalMovimientos: const Value(0),
      totalSuscripciones: const Value(0.0),
      totalRecargas: const Value(0.0),
      estado: const Value('abierto'),
      createdAt: now,
      updatedAt: now,
    );

    await _db.into(_db.cortesCaja).insert(companion);

    return (await (_db.select(_db.cortesCaja)
          ..where((t) => t.id.equals(id)))
        .getSingle());
  }

  /// Realiza el corte de caja y cierre de turno:
  /// - Calcula ventas y transacciones.
  /// - Aplica el arqueo con el efectivo físico contado.
  /// - Calcula la diferencia: `efectivoContado - totalEsperado`.
  /// - Retira la venta total ("se quita la venta").
  /// - Deja el fondo fijo ($2,000.00) para el siguiente turno.
  /// - Cierra el registro en la base de datos.
  Future<CortesCajaData> realizarCorte({
    required String turnoId,
    required double efectivoContado,
    double fondoSiguienteTurno = 2000.0,
    String? desgloseJson,
    String? observaciones,
  }) async {
    final turno = await (_db.select(_db.cortesCaja)
          ..where((t) => t.id.equals(turnoId)))
        .getSingleOrNull();

    if (turno == null) {
      throw Exception('Turno con ID $turnoId no encontrado.');
    }

    if (turno.estado == 'cerrado') {
      throw Exception('Este turno ya ha sido cerrado previamente.');
    }

    final now = DateTime.now();
    final resumen = await obtenerResumenTurno(turno);

    final totalEsperado = turno.fondoInicial + resumen.totalVentas;
    final diferencia = efectivoContado - totalEsperado;

    // "Se quita la venta": el monto retirado para corte/resguardo es el total vendido
    // (o el excedente sobre el fondo que queda para el siguiente turno)
    final montoRetirado = resumen.totalVentas;

    await (_db.update(_db.cortesCaja)..where((t) => t.id.equals(turnoId))).write(
      CortesCajaCompanion(
        fechaCierre: Value(now),
        totalVentas: Value(resumen.totalVentas),
        totalEsperado: Value(totalEsperado),
        efectivoContado: Value(efectivoContado),
        diferencia: Value(diferencia),
        montoRetirado: Value(montoRetirado),
        fondoSiguienteTurno: Value(fondoSiguienteTurno),
        totalMovimientos: Value(resumen.totalTransacciones),
        totalSuscripciones: Value(resumen.totalSuscripciones),
        totalRecargas: Value(resumen.totalRecargas),
        desgloseJson: Value(desgloseJson),
        observaciones: Value(observaciones),
        estado: const Value('cerrado'),
        updatedAt: Value(now),
      ),
    );

    // Registrar en cola de sincronización para cuando haya backend central
    await _db.into(_db.syncQueue).insert(
          SyncQueueCompanion.insert(
            id: _uuid.v4(),
            entityType: 'corte_caja',
            entityId: turnoId,
            operation: 'update',
            payload: jsonEncode({
              'id': turnoId,
              'sucursal_id': sucursalId,
              'cajero_username': turno.cajeroUsername,
              'fecha_apertura': turno.fechaApertura.toIso8601String(),
              'fecha_cierre': now.toIso8601String(),
              'fondo_inicial': turno.fondoInicial,
              'total_ventas': resumen.totalVentas,
              'efectivo_contado': efectivoContado,
              'diferencia': diferencia,
              'monto_retirado': montoRetirado,
              'fondo_siguiente_turno': fondoSiguienteTurno,
            }),
            createdAt: now,
          ),
        );

    return (await (_db.select(_db.cortesCaja)
          ..where((t) => t.id.equals(turnoId)))
        .getSingle());
  }

  /// Obtiene un corte específico por su ID.
  Future<CortesCajaData?> obtenerCortePorId(String id) async {
    return (_db.select(_db.cortesCaja)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }
}
