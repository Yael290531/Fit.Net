import 'package:drift/drift.dart';
import 'clientes_table.dart';

// ═══════════════════════════════════════════════════════════════════════
// TABLA: suscripciones
// Registra las suscripciones temporales (mensual, semanal, diaria)
// de cada cliente. Una suscripción activa es aquella cuya fechaFin
// es posterior a DateTime.now().
// ═══════════════════════════════════════════════════════════════════════
class Suscripciones extends Table {
  /// UUID de la suscripción (PK).
  TextColumn get id => text()();

  /// FK → clientes.id
  TextColumn get clienteId =>
      text().references(Clientes, #id, onDelete: KeyAction.cascade)();

  /// Sucursal donde se registró la suscripción.
  TextColumn get sucursalId => text()();

  /// Tipo de plan. Valores: 'mensual', 'semanal', 'diaria'.
  TextColumn get tipoSuscripcion => text()();

  /// Monto pagado por la suscripción (500, 150, 80).
  RealColumn get montoPagado => real()();

  /// Fecha/hora de inicio de la suscripción.
  DateTimeColumn get fechaInicio => dateTime()();

  /// Fecha/hora de expiración de la suscripción.
  DateTimeColumn get fechaFin => dateTime()();

  /// Estado de sincronización. Valores: 'pending', 'synced', 'failed'.
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
