// ignore_for_file: type=lint
// GENERATED FILE – No editar manualmente.
// Ejecuta: dart run build_runner build --delete-conflicting-outputs
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables/clientes_table.dart';
import 'tables/tarjetas_table.dart';
import 'tables/movimientos_table.dart';
import 'tables/sync_queue_table.dart';
import 'tables/app_settings_table.dart';

part 'app_database.g.dart';

// ═══════════════════════════════════════════════════════════════════════
// BASE DE DATOS PRINCIPAL – Fit.Net Local DB
//
// Persistencia en:
//   Windows : %USERPROFILE%\Documents\fitnet_db.sqlite
//   Android : /data/data/<pkg>/databases/fitnet_db.sqlite
//   iOS/macOS: ~/Documents/fitnet_db.sqlite
//   Linux   : ~/Documents/fitnet_db.sqlite
//
// Para conectar Supabase en el futuro, ver:
//   lib/core/remote/remote_sync_service.dart
// ═══════════════════════════════════════════════════════════════════════
@DriftDatabase(tables: [Clientes, Tarjetas, Movimientos, SyncQueue, AppSettings])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Constructor alternativo para tests (base en memoria).
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
          // Activar llaves foráneas en SQLite.
          await customStatement('PRAGMA foreign_keys = ON');
        },
        onUpgrade: (Migrator m, int from, int to) async {
          // Futuras migraciones se agregan aquí:
          // if (from < 2) { await m.addColumn(clientes, clientes.telefono); }
        },
        beforeOpen: (details) async {
          // Garantizar que las llaves foráneas estén habilitadas en cada apertura.
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}

/// Abre la BD en la carpeta de documentos del dispositivo.
/// drift_flutter selecciona la ubicación correcta según la plataforma.
QueryExecutor _openConnection() {
  return driftDatabase(name: 'fitnet_db');
}
