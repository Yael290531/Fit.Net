import 'package:drift/drift.dart';
import 'clientes_table.dart';

// ═══════════════════════════════════════════════════════════════════════
// TABLA: tarjetas
// Asocia una tarjeta de acceso a un cliente.
// El saldo real vive aquí; los movimientos son el registro histórico.
// ═══════════════════════════════════════════════════════════════════════
class Tarjetas extends Table {
  /// UUID de la tarjeta (PK).
  TextColumn get idTarjeta => text()();

  /// FK → clientes.id
  TextColumn get clienteId =>
      text().references(Clientes, #id, onDelete: KeyAction.cascade)();

  /// Saldo disponible. Mínimo 0.
  RealColumn get saldo => real().withDefault(const Constant(0.0))();

  /// Sucursal a la que pertenece la tarjeta.
  TextColumn get sucursalId => text()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  /// Estado de sincronización. Valores: 'pending', 'synced', 'failed'.
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

  @override
  Set<Column> get primaryKey => {idTarjeta};
}
