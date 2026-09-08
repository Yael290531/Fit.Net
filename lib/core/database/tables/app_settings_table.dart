import 'package:drift/drift.dart';

// ═══════════════════════════════════════════════════════════════════════
// TABLA: app_settings
// Almacén de clave-valor para configuraciones locales.
// Claves usadas:
//   'sucursal_id'     → ID de la sucursal configurada en el dispositivo
//   'sucursal_nombre' → Nombre legible de la sucursal
//   'last_sync_at'    → Timestamp de la última sincronización exitosa
//   'usuario_id'      → ID del usuario en sesión (temporal, sin password)
//   'usuario_rol'     → Rol: 'adminGlobal' o 'cajero'
// ═══════════════════════════════════════════════════════════════════════
class AppSettings extends Table {
  /// Clave única (PK).
  TextColumn get key => text()();

  /// Valor almacenado como texto.
  TextColumn get value => text()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {key};
}
