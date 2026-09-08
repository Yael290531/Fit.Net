import '../../core/database/app_database.dart';

/// Repositorio para configuraciones locales (clave-valor en app_settings).
class SettingsRepository {
  final AppDatabase _db;

  SettingsRepository(this._db);

  /// Lee el valor de una clave, o [defaultValue] si no existe.
  Future<String?> get(String key) async {
    final row = await (_db.select(_db.appSettings)
          ..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  /// Guarda o actualiza un valor.
  Future<void> set(String key, String value) async {
    await _db.into(_db.appSettings).insertOnConflictUpdate(
          AppSettingsCompanion.insert(
            key: key,
            value: value,
            updatedAt: DateTime.now(),
          ),
        );
  }

  /// Elimina una clave.
  Future<void> delete(String key) async {
    await (_db.delete(_db.appSettings)
          ..where((t) => t.key.equals(key)))
        .go();
  }

  // ── Helpers específicos ────────────────────────────────────────────
  Future<String?> getSucursalId() => get('sucursal_id');
  Future<void> setSucursalId(String id) => set('sucursal_id', id);

  Future<String?> getSucursalNombre() => get('sucursal_nombre');
  Future<void> setSucursalNombre(String nombre) =>
      set('sucursal_nombre', nombre);

  Future<String?> getUsuarioRol() => get('usuario_rol');
  Future<void> setUsuarioRol(String rol) => set('usuario_rol', rol);

  Future<String?> getUsuarioId() => get('usuario_id');
  Future<void> setUsuarioId(String id) => set('usuario_id', id);

  Future<String?> getLastSyncAt() => get('last_sync_at');
  Future<void> setLastSyncAt(DateTime dt) =>
      set('last_sync_at', dt.toIso8601String());
}
