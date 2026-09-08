import 'package:drift/drift.dart';

import '../../core/database/app_database.dart';

/// Repositorio para consulta de movimientos financieros.
///
/// Los movimientos son inmutables: nunca se editan, solo se crean.
/// Para correcciones se usa tipo 'ajuste' o 'reversion' (futuro).
class MovimientosRepository {
  final AppDatabase _db;
  final String sucursalId;

  MovimientosRepository(this._db, {required this.sucursalId});

  // ── Streams ────────────────────────────────────────────────────────
  /// Stream de movimientos del día actual para esta sucursal.
  Stream<List<Movimiento>> watchMovimientosHoy() {
    final hoy = DateTime.now();
    final inicioDia = DateTime(hoy.year, hoy.month, hoy.day);
    final finDia = inicioDia.add(const Duration(days: 1));

    return (_db.select(_db.movimientos)
          ..where(
            (t) =>
                t.sucursalId.equals(sucursalId) &
                t.fecha.isBiggerOrEqualValue(inicioDia) &
                t.fecha.isSmallerThanValue(finDia),
          )
          ..orderBy([
            (t) => OrderingTerm(
                  expression: t.fecha,
                  mode: OrderingMode.desc,
                ),
          ]))
        .watch();
  }

  // ── Lecturas ───────────────────────────────────────────────────────
  /// Movimientos del día actual.
  Future<List<Movimiento>> obtenerMovimientosHoy() async {
    final hoy = DateTime.now();
    final inicioDia = DateTime(hoy.year, hoy.month, hoy.day);
    final finDia = inicioDia.add(const Duration(days: 1));

    return (_db.select(_db.movimientos)
          ..where(
            (t) =>
                t.sucursalId.equals(sucursalId) &
                t.fecha.isBiggerOrEqualValue(inicioDia) &
                t.fecha.isSmallerThanValue(finDia),
          )
          ..orderBy([
            (t) => OrderingTerm(
                  expression: t.fecha,
                  mode: OrderingMode.desc,
                ),
          ]))
        .get();
  }

  /// Total de ingresos del día (solo tipo 'pago' = cobros de acceso).
  Future<double> obtenerIngresosHoy() async {
    final movimientos = await obtenerMovimientosHoy();
    double total = 0.0;
    for (final m in movimientos) {
      if (m.tipo == 'pago') total += m.monto;
    }
    return total;
  }

  /// Cuenta movimientos de hoy.
  Future<int> contarMovimientosHoy() async {
    final movimientos = await obtenerMovimientosHoy();
    return movimientos.length;
  }

  /// Todos los movimientos de la sucursal (para reportes).
  Future<List<Movimiento>> obtenerTodosLosMovimientos() async {
    return (_db.select(_db.movimientos)
          ..where((t) => t.sucursalId.equals(sucursalId))
          ..orderBy([
            (t) => OrderingTerm(
                  expression: t.fecha,
                  mode: OrderingMode.desc,
                ),
          ]))
        .get();
  }

  /// Stream de todos los movimientos de la sucursal (panel admin).
  Stream<List<Movimiento>> watchTodosLosMovimientos() {
    return (_db.select(_db.movimientos)
          ..where((t) => t.sucursalId.equals(sucursalId))
          ..orderBy([
            (t) => OrderingTerm(
                  expression: t.fecha,
                  mode: OrderingMode.desc,
                ),
          ]))
        .watch();
  }
}
