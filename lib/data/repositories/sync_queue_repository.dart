import 'package:drift/drift.dart';

import '../../core/database/app_database.dart';

/// Repositorio para la cola de sincronización pendiente.
///
/// Cada operación financiera agrega entradas aquí.
/// En el futuro, RemoteSyncService leerá y procesará estas entradas.
class SyncQueueRepository {
  final AppDatabase _db;

  SyncQueueRepository(this._db);

  /// Devuelve todos los registros pendientes.
  Future<List<SyncQueueData>> obtenerPendientes() async {
    return (_db.select(_db.syncQueue)
          ..where((t) => t.status.equals('pending'))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
        .get();
  }

  /// Stream de la cantidad total de registros pendientes.
  Stream<int> watchContadorPendientes() {
    return (_db.select(_db.syncQueue)
          ..where((t) => t.status.equals('pending')))
        .watch()
        .map((list) => list.length);
  }

  /// Cuenta los registros pendientes.
  Future<int> contarPendientes() async {
    final list = await obtenerPendientes();
    return list.length;
  }

  /// Marca una entrada como procesada exitosamente.
  Future<void> marcarComoSincronizado(String id) async {
    await (_db.update(_db.syncQueue)..where((t) => t.id.equals(id))).write(
      const SyncQueueCompanion(status: Value('done')),
    );
  }

  /// Marca una entrada como fallida con mensaje de error.
  Future<void> marcarComoFallido(String id, String error) async {
    await (_db.update(_db.syncQueue)..where((t) => t.id.equals(id))).write(
      SyncQueueCompanion(
        status: const Value('failed'),
        lastError: Value(error),
      ),
    );
  }
}
