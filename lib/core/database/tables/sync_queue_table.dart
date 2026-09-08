import 'package:drift/drift.dart';

// ═══════════════════════════════════════════════════════════════════════
// TABLA: sync_queue
// Cola de operaciones locales pendientes de enviar a Supabase.
// Por ahora todos los registros quedan en estado 'pending'.
//
// TODO (Supabase): La etapa de sincronización leerá esta tabla,
// intentará enviar cada entrada y actualizará su status.
// ═══════════════════════════════════════════════════════════════════════
class SyncQueue extends Table {
  /// UUID de la entrada en la cola (PK).
  TextColumn get id => text()();

  /// Tipo de entidad. Valores: 'cliente', 'tarjeta', 'movimiento'.
  TextColumn get entityType => text()();

  /// ID del registro relacionado (UUID del cliente/tarjeta/movimiento).
  TextColumn get entityId => text()();

  /// Operación realizada. Valores: 'insert', 'update', 'delete'.
  TextColumn get operation => text()();

  /// Datos serializados en JSON para enviar al servidor.
  TextColumn get payload => text()();

  /// Estado de la cola. Valores: 'pending', 'processing', 'done', 'failed'.
  TextColumn get status => text().withDefault(const Constant('pending'))();

  /// Número de intentos realizados.
  IntColumn get attempts => integer().withDefault(const Constant(0))();

  /// Mensaje del último error.
  TextColumn get lastError => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  /// Fecha en que se puede volver a intentar (backoff exponencial futuro).
  DateTimeColumn get nextRetryAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
