import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/database_service.dart';
import '../widgets/theme_widgets.dart';
import 'login_screen.dart';

/// Dashboard del Administrador – Vista de Integración Global.
///
/// Consolida y muestra los ingresos de TODAS las sucursales:
/// - Ingresos Totales de Hoy (suma global)
/// - Desglose por sucursal (Centro, Norte, etc.)
/// - Indicadores por sucursal
///
/// Esta vista demuestra el concepto de INTEGRACIÓN de bases de datos:
/// un servidor central que consulta múltiples BDs distribuidas.
class AdminDashboard extends StatefulWidget {
  final Usuario usuario;

  const AdminDashboard({super.key, required this.usuario});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with SingleTickerProviderStateMixin {
  final _db = DatabaseService();

  late AnimationController _animController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _scaleAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.elasticOut),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _logout() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const LoginScreen(),
        transitionsBuilder: (_, anim, secondAnimation, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  void _refreshData() {
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.sync, color: FitNetTheme.gold, size: 18),
            SizedBox(width: 12),
            Text('Datos actualizados desde las sucursales'),
          ],
        ),
        backgroundColor: FitNetTheme.cardDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ═══════════════════════════════════════════════════════════
    // TODO: Reemplazar con consultas reales al servidor central.
    // Ejemplo:
    //   SELECT sucursal, SUM(monto) as ingresos
    //   FROM movimientos_financieros
    //   WHERE tipo_movimiento IN ('cobroAcceso', 'compra')
    //     AND DATE(fecha) = CURDATE()
    //   GROUP BY sucursal;
    //
    // Para integración global, este query consultaría una vista
    // federada o una tabla replicada desde las BDs de cada sucursal.
    // ═══════════════════════════════════════════════════════════
    final ingresosTotales = _db.obtenerIngresosTotalesHoy();
    final desglose = _db.obtenerDesglosePorSucursal();
    final sucursales = _db.obtenerSucursales();
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 900;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: FitNetTheme.darkGradient),
        child: Column(
          children: [
            // ── Header ──
            _buildHeader(),

            // ── Contenido ──
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isWide ? 48 : 20,
                  vertical: 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Indicador Principal: Ingresos Totales ──
                    _buildMainIndicator(ingresosTotales),
                    const SizedBox(height: 32),

                    // ── Título de Sección ──
                    const Row(
                      children: [
                        Icon(Icons.account_tree_outlined,
                            color: FitNetTheme.gold, size: 20),
                        SizedBox(width: 10),
                        Text(
                          'Desglose por Sucursal',
                          style: TextStyle(
                            color: FitNetTheme.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Datos integrados desde las bases de datos distribuidas de cada sucursal',
                      style: TextStyle(
                        color: FitNetTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Tarjetas por Sucursal ──
                    if (isWide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: sucursales
                            .map((s) => Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8),
                                    child: _buildSucursalCard(
                                      s,
                                      desglose[s] ?? 0,
                                      ingresosTotales,
                                    ),
                                  ),
                                ))
                            .toList(),
                      )
                    else
                      ...sucursales.map((s) => Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _buildSucursalCard(
                              s,
                              desglose[s] ?? 0,
                              ingresosTotales,
                            ),
                          )),

                    const SizedBox(height: 32),

                    // ── Diagrama de Arquitectura ──
                    _buildArchitectureDiagram(),

                    const SizedBox(height: 32),

                    // ── Créditos del proyecto ──
                    _buildCreditos(),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      decoration: BoxDecoration(
        color: FitNetTheme.surfaceDark,
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.05),
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: FitNetTheme.goldGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.admin_panel_settings_rounded,
                color: FitNetTheme.backgroundDark,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Panel de Administración Global',
                    style: TextStyle(
                      color: FitNetTheme.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    'Integración de Bases de Datos · Vista Consolidada',
                    style: TextStyle(
                      color: FitNetTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: FitNetTheme.gold.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: FitNetTheme.gold.withValues(alpha: 0.3),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, color: FitNetTheme.success, size: 8),
                  SizedBox(width: 6),
                  Text(
                    'BD Global',
                    style: TextStyle(
                      color: FitNetTheme.gold,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.refresh_rounded,
                  color: FitNetTheme.textSecondary),
              tooltip: 'Actualizar Datos',
              onPressed: _refreshData,
            ),
            IconButton(
              icon: const Icon(Icons.logout_rounded,
                  color: FitNetTheme.textSecondary),
              tooltip: 'Cerrar Sesión',
              onPressed: _logout,
            ),
          ],
        ),
      ),
    );
  }

  /// Indicador principal de ingresos totales con animación.
  Widget _buildMainIndicator(double ingresosTotales) {
    return AnimatedBuilder(
      animation: _scaleAnim,
      builder: (context, child) {
        return Transform.scale(
          scale: 0.8 + (_scaleAnim.value * 0.2),
          child: Opacity(
            opacity: _scaleAnim.value.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(36),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              FitNetTheme.cardDark,
              FitNetTheme.gold.withValues(alpha: 0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: FitNetTheme.gold.withValues(alpha: 0.2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: FitNetTheme.gold.withValues(alpha: 0.08),
              blurRadius: 40,
              spreadRadius: 4,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: FitNetTheme.gold.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: ShaderMask(
                shaderCallback: (bounds) =>
                    FitNetTheme.goldGradient.createShader(bounds),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Colors.white,
                  size: 36,
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'INGRESOS TOTALES DE HOY',
              style: TextStyle(
                color: FitNetTheme.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 12),
            ShaderMask(
              shaderCallback: (bounds) =>
                  FitNetTheme.goldGradient.createShader(bounds),
              child: Text(
                '\$${ingresosTotales.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 56,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -2,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Suma consolidada de todas las sucursales · ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
              style: const TextStyle(
                color: FitNetTheme.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Tarjeta de ingresos por sucursal individual.
  Widget _buildSucursalCard(
      String sucursal, double ingresos, double totalGlobal) {
    final porcentaje =
        totalGlobal > 0 ? (ingresos / totalGlobal * 100) : 0.0;
    final clientes = _db.contarClientes(sucursal);
    final movimientos = _db.contarMovimientosHoy(sucursal);
    final iconData = sucursal.contains('Centro')
        ? Icons.location_city_rounded
        : Icons.apartment_rounded;

    return Container(
      decoration: FitNetTheme.premiumCard,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header de la sucursal ──
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: FitNetTheme.gold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(iconData, color: FitNetTheme.gold, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sucursal,
                      style: const TextStyle(
                        color: FitNetTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.circle,
                            color: FitNetTheme.success, size: 6),
                        const SizedBox(width: 4),
                        Text(
                          'Base de datos conectada',
                          style: TextStyle(
                            color: FitNetTheme.success.withValues(alpha: 0.8),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Monto de ingresos ──
          Text(
            '\$${ingresos.toStringAsFixed(2)}',
            style: const TextStyle(
              color: FitNetTheme.gold,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Ingresos del día',
            style: TextStyle(
              color: FitNetTheme.textSecondary.withValues(alpha: 0.7),
              fontSize: 12,
            ),
          ),

          const SizedBox(height: 16),

          // ── Barra de progreso ──
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: porcentaje / 100,
              backgroundColor: Colors.white.withValues(alpha: 0.06),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(FitNetTheme.gold),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${porcentaje.toStringAsFixed(1)}% del total global',
            style: const TextStyle(
              color: FitNetTheme.textSecondary,
              fontSize: 12,
            ),
          ),

          const SizedBox(height: 16),
          Divider(color: Colors.white.withValues(alpha: 0.06)),
          const SizedBox(height: 12),

          // ── Métricas de la sucursal ──
          Row(
            children: [
              _buildMiniMetric(Icons.people_outline, '$clientes', 'Clientes'),
              const SizedBox(width: 20),
              _buildMiniMetric(
                  Icons.receipt_long, '$movimientos', 'Movimientos'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMetric(IconData icon, String value, String label) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, color: FitNetTheme.textSecondary, size: 16),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: FitNetTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  color: FitNetTheme.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Diagrama visual de la arquitectura de BD.
  Widget _buildArchitectureDiagram() {
    return PremiumCard(
      title: 'Arquitectura de Distribución e Integración',
      icon: Icons.schema_outlined,
      child: Column(
        children: [
          // BD Global
          _buildDbNode(
            'Servidor Central (BD Global)',
            'MySQL / PostgreSQL',
            Icons.dns_rounded,
            isMain: true,
          ),
          // Conector
          Container(
            width: 2,
            height: 30,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  FitNetTheme.gold,
                  FitNetTheme.gold.withValues(alpha: 0.3),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          // Nodo divisor
          Container(
            width: 80,
            height: 2,
            color: FitNetTheme.gold.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          // BDs Locales
          Row(
            children: [
              Expanded(
                child: _buildDbNode(
                  'BD Sucursal Centro',
                  'Distribución Local',
                  Icons.storage_rounded,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDbNode(
                  'BD Sucursal Norte',
                  'Distribución Local',
                  Icons.storage_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: FitNetTheme.gold.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: FitNetTheme.gold.withValues(alpha: 0.12)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline,
                    color: FitNetTheme.gold, size: 16),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Cada sucursal opera con su propia base de datos (distribución). '
                    'El servidor central integra los datos para generar reportes globales (integración).',
                    style: TextStyle(
                      color: FitNetTheme.textSecondary,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDbNode(String name, String subtitle, IconData icon,
      {bool isMain = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isMain
            ? FitNetTheme.gold.withValues(alpha: 0.08)
            : FitNetTheme.cardLighter,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMain
              ? FitNetTheme.gold.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isMain ? FitNetTheme.gold : FitNetTheme.textSecondary,
            size: 20,
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: TextStyle(
                  color: isMain
                      ? FitNetTheme.gold
                      : FitNetTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  color: FitNetTheme.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Créditos del proyecto.
  Widget _buildCreditos() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: FitNetTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          ShaderMask(
            shaderCallback: (bounds) =>
                FitNetTheme.goldGradient.createShader(bounds),
            child: const Text(
              'FIT.NET',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Distribución e Integración de Bases de Datos',
            style: TextStyle(
              color: FitNetTheme.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.white.withValues(alpha: 0.06)),
          const SizedBox(height: 16),
          const Text(
            'Desarrollado por',
            style: TextStyle(
              color: FitNetTheme.textSecondary,
              fontSize: 11,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _buildAuthorChip('Leonardo Yael'),
              _buildAuthorChip('Jesús Alejandro'),
              _buildAuthorChip('Raúl Adrián'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAuthorChip(String name) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: FitNetTheme.gold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: FitNetTheme.gold.withValues(alpha: 0.2),
        ),
      ),
      child: Text(
        name,
        style: const TextStyle(
          color: FitNetTheme.gold,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
