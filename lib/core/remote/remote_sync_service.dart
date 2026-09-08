import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:supabase/supabase.dart';

import '../../core/database/app_database.dart';
import '../../data/repositories/sync_queue_repository.dart';

// ═══════════════════════════════════════════════════════════════════════
// SERVICIO DE SINCRONIZACIÓN REMOTA – Supabase
//
// Conecta la BD local (Drift/SQLite) con Supabase para:
//   1. Subir cambios locales pendientes (push)
//   2. Descargar cambios remotos (pull)
//
// Credenciales del proyecto:
//   URL:  https://jwxqwvvqymfwchinrqve.supabase.co
//   Key:  sb_publishable_eSnw-apEUrBLmXhDr5ZVLQ_TZw0mGPd
// ═══════════════════════════════════════════════════════════════════════

/// URL base del proyecto Supabase.
const String supabaseUrl = 'https://jwxqwvvqymfwchinrqve.supabase.co';

/// Publishable key (anon key) – segura para uso en cliente.
const String supabaseAnonKey = 'sb_publishable_eSnw-apEUrBLmXhDr5ZVLQ_TZw0mGPd';

/// Controla si la sincronización remota está activa.
const bool remoteSyncEnabled = true;

/// Abstracción del servicio de sincronización remota.
abstract class RemoteSyncService {
  /// Inicializa la conexión al servidor remoto.
  Future<void> initialize();

  /// Envía los registros pendientes en sync_queue al servidor.
  Future<void> pushPendingChanges();

  /// Descarga cambios remotos al almacenamiento local.
  Future<void> pullRemoteChanges();
}

/// Implementación temporal que no hace nada.
/// Se usa cuando [remoteSyncEnabled] es false.
class DisabledRemoteSyncService implements RemoteSyncService {
  const DisabledRemoteSyncService();

  @override
  Future<void> initialize() async {}

  @override
  Future<void> pushPendingChanges() async {}

  @override
  Future<void> pullRemoteChanges() async {}
}

// ═══════════════════════════════════════════════════════════════════════
// IMPLEMENTACIÓN REAL – Supabase
// ═══════════════════════════════════════════════════════════════════════

/// Servicio que sincroniza la BD local con Supabase.
///
/// Flujo de push:
///   1. Lee sync_queue WHERE status = 'pending'
///   2. Para cada entrada, hace upsert en la tabla Supabase correspondiente
///   3. Actualiza status a 'done' o 'failed'
///
/// Flujo de pull:
///   1. Consulta las tablas remotas con filtro por sucursal
///   2. Hace upsert en las tablas locales de Drift
class SupabaseRemoteSyncService implements RemoteSyncService {
  final AppDatabase _db;
  final SyncQueueRepository _syncQueueRepo;

  SupabaseRemoteSyncService({
    required AppDatabase db,
    required SyncQueueRepository syncQueueRepo,
  })  : _db = db,
        _syncQueueRepo = syncQueueRepo;

  /// Cliente Supabase (inicializado en initialize()).
  late final SupabaseClient _client;

  /// Tablas de Supabase que corresponden a entityType en sync_queue.
  static const Map<String, String> _tableMap = {
    'cliente': 'clientes',
    'tarjeta': 'tarjetas',
    'movimiento': 'movimientos',
  };

  @override
  Future<void> initialize() async {
    _client = SupabaseClient(supabaseUrl, supabaseAnonKey);
  }

  @override
  Future<void> pushPendingChanges() async {
    final pendientes = await _syncQueueRepo.obtenerPendientes();

    for (final entry in pendientes) {
      try {
        final tableName = _tableMap[entry.entityType];
        if (tableName == null) {
          await _syncQueueRepo.marcarComoFallido(
            entry.id,
            'Tipo de entidad desconocido: ${entry.entityType}',
          );
          continue;
        }

        final payload = jsonDecode(entry.payload) as Map<String, dynamic>;

        // ── Limpieza de payloads antiguos/mal formados ──
        if (tableName == 'clientes') {
          payload.remove('tarjeta_id');
          payload.remove('saldo_inicial');
        }

        switch (entry.operation) {
          case 'insert':
          case 'update':
            // Upsert: inserta o actualiza si ya existe.
            await _client.from(tableName).upsert(payload);

          case 'delete':
            // Soft delete: marcar deleted_at, o hard delete.
            final entityId = entry.entityId;
            if (tableName == 'movimientos') {
              // Movimientos se borran por 'id'.
              await _client.from(tableName).delete().eq('id', entityId);
            } else if (tableName == 'tarjetas') {
              await _client
                  .from(tableName)
                  .delete()
                  .eq('id_tarjeta', entityId);
            } else {
              await _client.from(tableName).delete().eq('id', entityId);
            }

          default:
            await _syncQueueRepo.marcarComoFallido(
              entry.id,
              'Operación desconocida: ${entry.operation}',
            );
            continue;
        }

        // Éxito → marcar como sincronizado.
        await _syncQueueRepo.marcarComoSincronizado(entry.id);
      } catch (e) {
        // Error → marcar como fallido con el mensaje de error.
        await _syncQueueRepo.marcarComoFallido(entry.id, e.toString());
      }
    }
  }

  @override
  Future<void> pullRemoteChanges() async {
    try {
      // ── Descargar clientes ──
      final clientesRemoto =
          await _client.from('clientes').select() as List<dynamic>;
      for (final row in clientesRemoto) {
        final data = row as Map<String, dynamic>;
        await _db.into(_db.clientes).insertOnConflictUpdate(
              ClientesCompanion.insert(
                id: data['id'] as String,
                nombre: data['nombre'] as String,
                telefono: Value(data['telefono'] as String?),
                sucursalId: data['sucursal_id'] as String,
                createdAt: DateTime.parse(data['created_at'] as String),
                updatedAt: DateTime.parse(data['updated_at'] as String),
                deletedAt: data['deleted_at'] != null
                    ? Value(DateTime.parse(data['deleted_at'] as String))
                    : const Value.absent(),
                syncStatus: const Value('synced'),
              ),
            );
      }

      // ── Descargar tarjetas ──
      final tarjetasRemoto =
          await _client.from('tarjetas').select() as List<dynamic>;
      for (final row in tarjetasRemoto) {
        final data = row as Map<String, dynamic>;
        await _db.into(_db.tarjetas).insertOnConflictUpdate(
              TarjetasCompanion.insert(
                idTarjeta: data['id_tarjeta'] as String,
                clienteId: data['cliente_id'] as String,
                saldo: Value((data['saldo'] as num).toDouble()),
                sucursalId: data['sucursal_id'] as String,
                createdAt: DateTime.parse(data['created_at'] as String),
                updatedAt: DateTime.parse(data['updated_at'] as String),
                deletedAt: data['deleted_at'] != null
                    ? Value(DateTime.parse(data['deleted_at'] as String))
                    : const Value.absent(),
                syncStatus: const Value('synced'),
              ),
            );
      }

      // ── Descargar movimientos ──
      final movimientosRemoto =
          await _client.from('movimientos').select() as List<dynamic>;
      for (final row in movimientosRemoto) {
        final data = row as Map<String, dynamic>;
        await _db.into(_db.movimientos).insertOnConflictUpdate(
              MovimientosCompanion.insert(
                id: data['id'] as String,
                idTarjeta: data['id_tarjeta'] as String,
                sucursalId: data['sucursal_id'] as String,
                tipo: data['tipo'] as String,
                monto: (data['monto'] as num).toDouble(),
                fecha: DateTime.parse(data['fecha'] as String),
                syncStatus: const Value('synced'),
                syncAttempts: const Value(0),
                lastSyncError: const Value.absent(),
                createdAt: DateTime.parse(data['created_at'] as String),
                updatedAt: DateTime.parse(data['updated_at'] as String),
              ),
            );
      }
    } catch (e) {
      // En caso de error, el pull falla silenciosamente.
      // Los datos locales se mantienen intactos.
      // ignore: avoid_print
      print('[Supabase Pull] Error: $e');
    }
  }
}
