import 'package:flutter/material.dart';
import 'app_providers.dart';
import 'core/database/app_database.dart';
import 'core/remote/remote_sync_service.dart';
import 'data/repositories/settings_repository.dart';
import 'data/repositories/sync_queue_repository.dart';
import 'screens/login_screen.dart';
import 'widgets/theme_widgets.dart';

/// ════════════════════════════════════════════════════════════════════════
///  FIT.NET – Sistema de Gestión de Gimnasios
/// ════════════════════════════════════════════════════════════════════════
///
///  Proyecto: Distribución e Integración de Bases de Datos
///
///  Autores:
///    • Leonardo Yael
///    • Jesús Alejandro
///    • Raúl Adrián
///
///  Descripción:
///    Aplicación multiplataforma desarrollada en Flutter que demuestra
///    los conceptos de distribución e integración de bases de datos
///    en un sistema de gestión de cadena de gimnasios.
///
///  Arquitectura:
///    ┌──────────────────────────────────────────────────────────┐
///    │         SERVIDOR CENTRAL (BD GLOBAL)                    │
///    │  ─ Autenticación de usuarios (roles)                    │
///    │  ─ Consolidación de ingresos (integración)              │
///    └──────────────┬─────────────────────┬─────────────────────┘
///                   │                     │
///        ┌──────────┴──────┐    ┌─────────┴───────┐
///        │ SUCURSAL CENTRO │    │ SUCURSAL NORTE  │
///        │ (BD Local)      │    │ (BD Local)      │
///        │ ─ Clientes      │    │ ─ Clientes      │
///        │ ─ Tarjetas      │    │ ─ Tarjetas      │
///        │ ─ Movimientos   │    │ ─ Movimientos   │
///        └─────────────────┘    └─────────────────┘
///
///  Modelos de datos:
///    ─ Usuario (id, username, password, rol)
///    ─ ClienteTarjeta (id_tarjeta, nombre, saldo)
///    ─ MovimientoFinanciero (id, id_tarjeta, tipo, monto, fecha)
///
///  Pantallas:
///    1. LoginScreen → Autenticación con enrutamiento por rol
///    2. CajeroDashboard → Operación local de una sucursal
///    3. AdminDashboard → Vista consolidada global
///
/// ════════════════════════════════════════════════════════════════════════

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Inicializar base de datos local (Drift + SQLite) ────────────────
  final db = AppDatabase();
  final settingsRepo = SettingsRepository(db);
  final syncQueueRepo = SyncQueueRepository(db);
  // ── Inicializar servicio de sincronización remota ─────────────────
  final RemoteSyncService syncService;
  if (remoteSyncEnabled) {
    final supabaseService = SupabaseRemoteSyncService(
      db: db,
      syncQueueRepo: syncQueueRepo,
    );
    await supabaseService.initialize();
    
    // Auto-pull en background al iniciar la app para tener los datos más recientes
    supabaseService.pullRemoteChanges().catchError((e) {
      // ignore: avoid_print
      print('Auto-pull error en startup: $e');
    });

    syncService = supabaseService;
  } else {
    syncService = const DisabledRemoteSyncService();
  }

  runApp(
    AppProviders(
      db: db,
      syncService: syncService,
      settingsRepo: settingsRepo,
      syncQueueRepo: syncQueueRepo,
      child: const FitNetApp(),
    ),
  );
}

/// Widget raíz de la aplicación Fit.Net.
class FitNetApp extends StatelessWidget {
  const FitNetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fit.Net – Gestión de Gimnasios',
      debugShowCheckedModeBanner: false,

      // ── Tema oscuro premium con acentos dorados ──
      theme: FitNetTheme.theme,

      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: MediaQuery.of(context).textScaler.clamp(
              minScaleFactor: 0.85,
              maxScaleFactor: 1.25,
            ),
          ),
          child: child!,
        );
      },

      // ── Pantalla inicial: Login ──
      home: const LoginScreen(),
    );
  }
}
