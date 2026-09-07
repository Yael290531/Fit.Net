import 'package:flutter/material.dart';
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

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // TODO: Inicializar conexiones a bases de datos aquí.
  // Ejemplo con mysql_client:
  //   final conn = await MySQLConnection.createConnection(
  //     host: '127.0.0.1',
  //     port: 3306,
  //     userName: 'root',
  //     password: 'password',
  //     databaseName: 'fitnet_global',
  //   );
  //   await conn.connect();

  runApp(const FitNetApp());
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

      // ── Pantalla inicial: Login ──
      home: const LoginScreen(),
    );
  }
}
