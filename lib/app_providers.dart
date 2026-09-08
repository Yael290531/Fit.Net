import 'package:flutter/widgets.dart';

import '../core/database/app_database.dart';
import '../core/remote/remote_sync_service.dart';
import '../data/repositories/clientes_repository.dart';
import '../data/repositories/movimientos_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../data/repositories/sync_queue_repository.dart';
import '../data/repositories/tarjetas_repository.dart';

// ═══════════════════════════════════════════════════════════════════════
// AppProviders – InheritedWidget sencillo para inyección de dependencias.
//
// Provee la instancia de AppDatabase y todos los repositorios a la
// jerarquía de widgets, sin dependencias externas de DI.
//
// Uso:
//   final repos = AppProviders.of(context);
//   final clientes = await repos.clientesRepo.obtenerClientes();
// ═══════════════════════════════════════════════════════════════════════
class AppProviders extends InheritedWidget {
  /// Base de datos Drift.
  final AppDatabase db;

  /// Servicio de sincronización remota (deshabilitado hasta Supabase).
  final RemoteSyncService syncService;

  /// Repositorios globales (sin sucursal específica).
  final SettingsRepository settingsRepo;
  final SyncQueueRepository syncQueueRepo;

  const AppProviders({
    super.key,
    required this.db,
    required this.syncService,
    required this.settingsRepo,
    required this.syncQueueRepo,
    required super.child,
  });

  /// Obtiene la instancia de AppProviders más cercana en el árbol.
  static AppProviders of(BuildContext context) {
    final result = context.dependOnInheritedWidgetOfExactType<AppProviders>();
    assert(result != null, 'No AppProviders found in context');
    return result!;
  }

  /// Crea un [ClientesRepository] filtrado por [sucursalId].
  ClientesRepository clientesRepo(String sucursalId) =>
      ClientesRepository(db, sucursalId: sucursalId);

  /// Crea un [TarjetasRepository] filtrado por [sucursalId].
  TarjetasRepository tarjetasRepo(String sucursalId) =>
      TarjetasRepository(db, sucursalId: sucursalId);

  /// Crea un [MovimientosRepository] filtrado por [sucursalId].
  MovimientosRepository movimientosRepo(String sucursalId) =>
      MovimientosRepository(db, sucursalId: sucursalId);

  @override
  bool updateShouldNotify(AppProviders oldWidget) =>
      db != oldWidget.db || syncService != oldWidget.syncService;
}
