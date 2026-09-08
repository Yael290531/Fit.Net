import 'package:drift/drift.dart';
import 'tarjetas_table.dart';

// ═══════════════════════════════════════════════════════════════════════
// TABLA: movimientos
// Registro inmutable de cada operación financiera.
// Para correcciones se crea un movimiento de tipo 'ajuste' o 'reversion'.
// ═══════════════════════════════════════════════════════════════════════
class Movimientos extends Table {
  /// UUID del movimiento (PK).
  TextColumn get id => text()();

  /// FK → tarjetas.id_tarjeta
  TextColumn get idTarjeta =>
      text().references(Tarjetas, #idTarjeta, onDelete: KeyAction.restrict)();

  /// Sucursal donde se generó el movimiento.
  TextColumn get sucursalId => text()();

  /// Tipo de operación. Valores: 'recarga', 'pago', 'ajuste', 'reversion'.
  TextColumn get tipo => text()();

  /// Monto de la operación. Siempre positivo.
  RealColumn get monto => real()();

  /// Fecha/hora de la operación.
  DateTimeColumn get fecha => dateTime()();

  // ── Campos de sincronización ───────────────────────────────────────
  /// Estado de sync. Valores: 'pending', 'syncing', 'synced', 'failed'.
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

  /// Número de intentos de sincronización realizados.
  IntColumn get syncAttempts => integer().withDefault(const Constant(0))();

  /// Último mensaje de error de sincronización.
  TextColumn get lastSyncError => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
