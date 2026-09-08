// ═══════════════════════════════════════════════════════════════════════
// SERVICIO DE SINCRONIZACIÓN REMOTA
//
// Este archivo es el punto de conexión para Supabase en el futuro.
// Actualmente está completamente deshabilitado.
//
// TODO (Fase 2 – Supabase):
//   1. Agregar dependencia: supabase_flutter: ^2.x.x
//   2. Implementar SupabaseRemoteSyncService
//   3. Cambiar remoteSyncEnabled = true
//   4. En pushPendingChanges():
//      - Leer sync_queue WHERE status = 'pending'
//      - Upsert en tablas de Supabase
//      - Actualizar status a 'done' o 'failed'
// ═══════════════════════════════════════════════════════════════════════

/// Controla si la sincronización remota está activa.
/// Mientras sea false, la app trabaja completamente offline con Drift.
const bool remoteSyncEnabled = false;

/// Abstracción del servicio de sincronización remota.
/// La implementación real se conectará a Supabase.
abstract class RemoteSyncService {
  /// Inicializa la conexión al servidor remoto.
  /// TODO: Llamar a Supabase.initialize() aquí.
  Future<void> initialize();

  /// Envía los registros pendientes en sync_queue al servidor.
  /// TODO: Leer sync_queue, hacer upsert en Supabase, marcar como 'done'.
  Future<void> pushPendingChanges();

  /// Descarga cambios remotos al almacenamiento local.
  /// TODO: SELECT de tablas Supabase y merge con Drift local.
  Future<void> pullRemoteChanges();
}

/// Implementación temporal que no hace nada.
/// Reemplazar con SupabaseRemoteSyncService cuando se active la Fase 2.
class DisabledRemoteSyncService implements RemoteSyncService {
  const DisabledRemoteSyncService();

  @override
  Future<void> initialize() async {
    // TODO: Inicializar Supabase client aquí (Fase 2).
    // await Supabase.initialize(url: ..., anonKey: ...);
  }

  @override
  Future<void> pushPendingChanges() async {
    // TODO: Enviar sync_queue a Supabase (Fase 2).
    // Los registros permanecen como 'pending' hasta que esto se implemente.
  }

  @override
  Future<void> pullRemoteChanges() async {
    // TODO: Descargar cambios de Supabase (Fase 2).
  }
}
