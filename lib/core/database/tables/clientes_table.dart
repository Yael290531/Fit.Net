import 'package:drift/drift.dart';

// ═══════════════════════════════════════════════════════════════════════
// TABLA: clientes
// Almacena los clientes registrados en cada sucursal.
// Campo sucursalId garantiza la separación por sucursal.
// ═══════════════════════════════════════════════════════════════════════
class Clientes extends Table {
  /// UUID generado en Dart antes de insertar.
  TextColumn get id => text()();

  /// Nombre completo del cliente. Obligatorio.
  TextColumn get nombre => text()();

  /// Teléfono opcional.
  TextColumn get telefono => text().nullable()();

  /// ID de la sucursal a la que pertenece ('Sucursal Centro', 'Sucursal Norte').
  TextColumn get sucursalId => text()();

  /// Timestamps de auditoría.
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  /// Estado de sincronización. Valores: 'pending', 'synced', 'failed'.
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

  @override
  Set<Column> get primaryKey => {id};
}
