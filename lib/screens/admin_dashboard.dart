import 'package:flutter/material.dart';
import '../app_providers.dart';
import '../core/database/app_database.dart';
import '../data/repositories/clientes_repository.dart';
import '../data/repositories/movimientos_repository.dart';
import '../data/repositories/suscripciones_repository.dart';
import '../models/models.dart';
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
  late AnimationController _animController;
  late Animation<double> _scaleAnim;

  /// Sucursales conocidas en el sistema.
  static const _sucursales = ['Sucursal Centro', 'Sucursal Norte'];

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
        pageBuilder: (context, animation, secondaryAnimation) =>
            const LoginScreen(),
        transitionsBuilder: (_, anim, secondAnimation, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  bool _isRefreshing = false;

  Future<void> _refreshData() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);

    try {
      final providers = AppProviders.of(context);
      // Extrae los datos desde Supabase a la BD Local
      await providers.syncService.pullRemoteChanges();

      if (mounted) {
        setState(() {}); // Fuerza reconstrucción para leer de Drift
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.sync, color: FitNetTheme.gold, size: 18),
                SizedBox(width: 12),
                Text('Datos actualizados desde el Servidor Central'),
              ],
            ),
            backgroundColor: FitNetTheme.cardDark,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al sincronizar: $e'),
            backgroundColor: FitNetTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final providers = AppProviders.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 900;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(gradient: FitNetTheme.darkGradient),
          child: Column(
            children: [
              // ── Header ──
              _buildHeader(),

              // ── TabBar ──
              Container(
                color: FitNetTheme.surfaceDark,
                child: const TabBar(
                  indicatorColor: FitNetTheme.gold,
                  labelColor: FitNetTheme.gold,
                  unselectedLabelColor: FitNetTheme.textSecondary,
                  tabs: [
                    Tab(icon: Icon(Icons.dashboard_rounded), text: 'Dashboard'),
                    Tab(icon: Icon(Icons.account_tree_outlined), text: 'Desglose y Clientes'),
                    Tab(icon: Icon(Icons.history_rounded), text: 'Movimientos'),
                  ],
                ),
              ),

              // ── Contenido ──
              Expanded(
                child: FutureBuilder<_DashboardData>(
                  future: _loadDashboardData(providers),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(color: FitNetTheme.gold),
                      );
                    }

                    final data = snapshot.data!;

                    return TabBarView(
                      children: [
                        // TAB 1: Dashboard Principal
                        SingleChildScrollView(
                          padding: EdgeInsets.symmetric(
                            horizontal: isWide ? 48 : 12,
                            vertical: isWide ? 24 : 16,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSyncIndicator(providers),
                              const SizedBox(height: 24),
                              _buildMainIndicator(data.ingresosTotales),
                              const SizedBox(height: 24),
                              _buildGlobalMetrics(data),
                              const SizedBox(height: 32),
                              _buildArchitectureDiagram(),
                              const SizedBox(height: 32),
                              _buildCreditos(),
                              const SizedBox(height: 32),
                            ],
                          ),
                        ),

                        // TAB 2: Desglose y Gestión de Clientes
                        SingleChildScrollView(
                          padding: EdgeInsets.symmetric(
                            horizontal: isWide ? 48 : 12,
                            vertical: isWide ? 24 : 16,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(
                                    Icons.account_tree_outlined,
                                    color: FitNetTheme.gold,
                                    size: 20,
                                  ),
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

                              if (isWide)
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: _sucursales
                                      .map(
                                        (s) => Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                            ),
                                            child: _buildSucursalCard(
                                              s,
                                              data.ingresosPorSucursal[s] ?? 0,
                                              data.ingresosTotales,
                                              data.clientesPorSucursal[s] ?? 0,
                                              data.movimientosPorSucursal[s] ?? 0,
                                              data,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                )
                              else
                                ..._sucursales.map(
                                  (s) => Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: _buildSucursalCard(
                                      s,
                                      data.ingresosPorSucursal[s] ?? 0,
                                      data.ingresosTotales,
                                      data.clientesPorSucursal[s] ?? 0,
                                      data.movimientosPorSucursal[s] ?? 0,
                                      data,
                                    ),
                                  ),
                                ),

                              const SizedBox(height: 24),

                              const Row(
                                children: [
                                  Icon(
                                    Icons.manage_accounts_outlined,
                                    color: FitNetTheme.gold,
                                    size: 20,
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    'Gestión de Clientes',
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
                                'Administrar suscripciones y datos de clientes por sucursal',
                                style: TextStyle(
                                  color: FitNetTheme.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 16),

                              ..._sucursales.map(
                                (s) => Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: _ClientesGestionSection(
                                    sucursal: s,
                                    providers: providers,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 32),
                            ],
                          ),
                        ),

                        // TAB 3: Historial de Movimientos
                        SingleChildScrollView(
                          padding: EdgeInsets.symmetric(
                            horizontal: isWide ? 48 : 12,
                            vertical: isWide ? 24 : 16,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(
                                    Icons.history_rounded,
                                    color: FitNetTheme.gold,
                                    size: 20,
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    'Historial de Movimientos',
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
                                'Auditoría y registro en tiempo real de transacciones por sucursal',
                                style: TextStyle(
                                  color: FitNetTheme.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 16),

                              ..._sucursales.map(
                                (s) => Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: _MovimientosSucursalSection(
                                    sucursal: s,
                                    providers: providers,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 32),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  /// Carga los datos consolidados de todas las sucursales.
  Future<_DashboardData> _loadDashboardData(AppProviders providers) async {
    double totalIngresos = 0;
    final ingresosPorSuc = <String, double>{};
    final clientesPorSuc = <String, int>{};
    final movimientosPorSuc = <String, int>{};
    final suscripcionesActivasPorSuc = <String, int>{};
    final porExpirarPorSuc = <String, int>{};

    for (final sucursal in _sucursales) {
      final movRepo = providers.movimientosRepo(sucursal);
      final cliRepo = providers.clientesRepo(sucursal);
      final susRepo = providers.suscripcionesRepo(sucursal);

      final ingresos = await movRepo.obtenerIngresosHoy();
      final numClientes = await cliRepo.contarClientes();
      final numMovimientos = await movRepo.contarMovimientosHoy();
      final numSuscripciones = await susRepo.contarSuscripcionesActivas();
      final numPorExpirar = await susRepo.contarPorExpirar(dias: 3);

      ingresosPorSuc[sucursal] = ingresos;
      clientesPorSuc[sucursal] = numClientes;
      movimientosPorSuc[sucursal] = numMovimientos;
      suscripcionesActivasPorSuc[sucursal] = numSuscripciones;
      porExpirarPorSuc[sucursal] = numPorExpirar;
      totalIngresos += ingresos;
    }

    final clientesTotales = clientesPorSuc.values.fold<int>(0, (a, b) => a + b);
    final suscripcionesTotales = suscripcionesActivasPorSuc.values.fold<int>(0, (a, b) => a + b);
    final gastosMes = totalIngresos * 0.45; // Simulación de gastos 45% de ingresos

    return _DashboardData(
      ingresosTotales: totalIngresos,
      ingresosPorSucursal: ingresosPorSuc,
      clientesPorSucursal: clientesPorSuc,
      movimientosPorSucursal: movimientosPorSuc,
      suscripcionesActivasPorSuc: suscripcionesActivasPorSuc,
      porExpirarPorSuc: porExpirarPorSuc,
      clientesTotales: clientesTotales,
      suscripcionesTotales: suscripcionesTotales,
      gastosPorMes: gastosMes,
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      decoration: BoxDecoration(
        color: FitNetTheme.surfaceDark,
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Integración de Bases de Datos · Vista Consolidada',
                    style: TextStyle(
                      color: FitNetTheme.textSecondary,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (MediaQuery.of(context).size.width > 550) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
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
                      'BD Local',
                      style: TextStyle(
                        color: FitNetTheme.gold,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(
                Icons.refresh_rounded,
                color: FitNetTheme.textSecondary,
              ),
              tooltip: 'Actualizar Datos',
              onPressed: _refreshData,
            ),
            IconButton(
              icon: const Icon(
                Icons.logout_rounded,
                color: FitNetTheme.textSecondary,
              ),
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 800;

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
        padding: EdgeInsets.symmetric(
          horizontal: isWide ? 36 : 16,
          vertical: isWide ? 36 : 22,
        ),
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
              padding: EdgeInsets.all(isWide ? 16 : 12),
              decoration: BoxDecoration(
                color: FitNetTheme.gold.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: ShaderMask(
                shaderCallback: (bounds) =>
                    FitNetTheme.goldGradient.createShader(bounds),
                child: Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Colors.white,
                  size: isWide ? 36 : 28,
                ),
              ),
            ),
            SizedBox(height: isWide ? 20 : 12),
            const Text(
              'INGRESOS TOTALES DE HOY',
              style: TextStyle(
                color: FitNetTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: ShaderMask(
                shaderCallback: (bounds) =>
                    FitNetTheme.goldGradient.createShader(bounds),
                child: Text(
                  '\$${ingresosTotales.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isWide ? 56 : 38,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Suma consolidada de todas las sucursales · ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: FitNetTheme.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlobalMetrics(_DashboardData data) {
    return Row(
      children: [
        Expanded(
          child: _buildGlobalMetricCard(
            Icons.people_alt_rounded,
            '${data.clientesTotales}',
            'Usuarios',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildGlobalMetricCard(
            Icons.card_membership_rounded,
            '${data.suscripcionesTotales}',
            'Suscripciones',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildGlobalMetricCard(
            Icons.money_off_rounded,
            '\$${data.gastosPorMes.toStringAsFixed(0)}',
            'Gastos (Est.)',
          ),
        ),
      ],
    );
  }

  Widget _buildGlobalMetricCard(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: FitNetTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Icon(icon, color: FitNetTheme.gold, size: 24),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: FitNetTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: FitNetTheme.textSecondary,
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// Tarjeta de ingresos por sucursal individual.
  Widget _buildSucursalCard(
    String sucursal,
    double ingresos,
    double totalGlobal,
    int clientes,
    int movimientos,
    _DashboardData data,
  ) {
    final porcentaje = totalGlobal > 0 ? (ingresos / totalGlobal * 100) : 0.0;
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
                        const Icon(
                          Icons.circle,
                          color: FitNetTheme.success,
                          size: 6,
                        ),
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
              valueColor: const AlwaysStoppedAnimation<Color>(FitNetTheme.gold),
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
                Icons.receipt_long,
                '$movimientos',
                'Movimientos',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildMiniMetric(
                Icons.card_membership_rounded,
                '${data.suscripcionesActivasPorSuc[sucursal] ?? 0}',
                'Suscripciones',
              ),
              const SizedBox(width: 20),
              _buildMiniMetric(
                Icons.warning_amber_rounded,
                '${data.porExpirarPorSuc[sucursal] ?? 0}',
                'Por expirar (3d)',
              ),
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

  /// Indicador de estado de sincronización.
  Widget _buildSyncIndicator(AppProviders providers) {
    return StreamBuilder<int>(
      stream: providers.syncQueueRepo.watchContadorPendientes(),
      builder: (context, snapshot) {
        final pendientes = snapshot.data ?? 0;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: FitNetTheme.cardDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.cloud_off_rounded,
                color: FitNetTheme.gold.withValues(alpha: 0.6),
                size: 18,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Modo local · Sincronización remota pendiente',
                      style: TextStyle(
                        color: FitNetTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      'Operaciones pendientes: $pendientes',
                      style: TextStyle(
                        color: FitNetTheme.gold.withValues(alpha: 0.8),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
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
            'Supabase / PostgreSQL',
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
          // BDs Locales (adaptable a móvil)
          LayoutBuilder(
            builder: (context, constraints) {
              final isSmall = constraints.maxWidth < 450;
              if (isSmall) {
                return Column(
                  children: [
                    _buildDbNode(
                      'BD Sucursal Centro',
                      'Drift / SQLite (local)',
                      Icons.storage_rounded,
                    ),
                    const SizedBox(height: 10),
                    _buildDbNode(
                      'BD Sucursal Norte',
                      'Drift / SQLite (local)',
                      Icons.storage_rounded,
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(
                    child: _buildDbNode(
                      'BD Sucursal Centro',
                      'Drift / SQLite (local)',
                      Icons.storage_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildDbNode(
                      'BD Sucursal Norte',
                      'Drift / SQLite (local)',
                      Icons.storage_rounded,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: FitNetTheme.gold.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: FitNetTheme.gold.withValues(alpha: 0.12),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: FitNetTheme.gold, size: 16),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Cada sucursal opera con su propia base de datos local. '
                    'El servidor central integra los datos para generar reportes globales '
                    'en cuanto se conecta a Supabase.',
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

  Widget _buildDbNode(
    String name,
    String subtitle,
    IconData icon, {
    bool isMain = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
        children: [
          Icon(
            icon,
            color: isMain ? FitNetTheme.gold : FitNetTheme.textSecondary,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: isMain ? FitNetTheme.gold : FitNetTheme.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: FitNetTheme.textSecondary,
                    fontSize: 10,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
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
            style: TextStyle(color: FitNetTheme.textSecondary, fontSize: 13),
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
              _buildAuthorChip('Yael Lopez'),
              _buildAuthorChip('Raúl Espinoza'),
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
        border: Border.all(color: FitNetTheme.gold.withValues(alpha: 0.2)),
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

/// Datos pre-cargados para el dashboard admin.
class _DashboardData {
  final double ingresosTotales;
  final Map<String, double> ingresosPorSucursal;
  final Map<String, int> clientesPorSucursal;
  final Map<String, int> movimientosPorSucursal;
  final Map<String, int> suscripcionesActivasPorSuc;
  final Map<String, int> porExpirarPorSuc;
  final int clientesTotales;
  final int suscripcionesTotales;
  final double gastosPorMes;

  _DashboardData({
    required this.ingresosTotales,
    required this.ingresosPorSucursal,
    required this.clientesPorSucursal,
    required this.movimientosPorSucursal,
    required this.suscripcionesActivasPorSuc,
    required this.porExpirarPorSuc,
    required this.clientesTotales,
    required this.suscripcionesTotales,
    required this.gastosPorMes,
  });
}

// ═══════════════════════════════════════════════════════════════════════
// Widget de Gestión de Clientes por Sucursal
// ═══════════════════════════════════════════════════════════════════════
class _ClientesGestionSection extends StatefulWidget {
  final String sucursal;
  final AppProviders providers;

  const _ClientesGestionSection({
    required this.sucursal,
    required this.providers,
  });

  @override
  State<_ClientesGestionSection> createState() =>
      _ClientesGestionSectionState();
}

class _ClientesGestionSectionState extends State<_ClientesGestionSection> {
  bool _isExpanded = false;
  late SuscripcionesRepository _suscripcionesRepo;
  late ClientesRepository _clientesRepo;

  @override
  void initState() {
    super.initState();
    _suscripcionesRepo = widget.providers.suscripcionesRepo(widget.sucursal);
    _clientesRepo = widget.providers.clientesRepo(widget.sucursal);
  }

  void _showSnackBar(
    String message, {
    bool isError = false,
    bool isSuccess = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline
                  : isSuccess
                  ? Icons.check_circle_outline
                  : Icons.info_outline,
              color: isError
                  ? FitNetTheme.error
                  : isSuccess
                  ? FitNetTheme.success
                  : FitNetTheme.gold,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: FitNetTheme.cardDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _editarCliente(Cliente cliente) async {
    final nombreCtrl = TextEditingController(text: cliente.nombre);
    final telefonoCtrl = TextEditingController(text: cliente.telefono ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FitNetTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: FitNetTheme.gold.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.edit, color: FitNetTheme.gold, size: 18),
            ),
            const SizedBox(width: 12),
            const Text(
              'Editar Cliente',
              style: TextStyle(
                color: FitNetTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: nombreCtrl,
              style: const TextStyle(color: FitNetTheme.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Nombre Completo',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: telefonoCtrl,
              style: const TextStyle(color: FitNetTheme.textPrimary),
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Teléfono (opcional)',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: FitNetTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: FitNetTheme.gold,
              foregroundColor: const Color(0xFF5B4002),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        await _clientesRepo.editarCliente(
          cliente.id,
          nombre: nombreCtrl.text.trim().isNotEmpty
              ? nombreCtrl.text.trim()
              : null,
          telefono: telefonoCtrl.text.trim().isNotEmpty
              ? telefonoCtrl.text.trim()
              : null,
        );
        if (!mounted) return;
        _showSnackBar('✓ Cliente actualizado', isSuccess: true);
      } catch (e) {
        if (!mounted) return;
        _showSnackBar('Error: $e', isError: true);
      }
    }
    nombreCtrl.dispose();
    telefonoCtrl.dispose();
  }

  Future<void> _eliminarCliente(Cliente cliente, bool tieneSuscripcion) async {
    if (tieneSuscripcion) {
      _showSnackBar('No se puede eliminar: suscripción activa', isError: true);
      return;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FitNetTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Eliminar Cliente',
          style: TextStyle(color: FitNetTheme.textPrimary),
        ),
        content: Text(
          '¿Eliminar a "${cliente.nombre}"? Quedará en espera 20 días.',
          style: const TextStyle(color: FitNetTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: FitNetTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: FitNetTheme.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        await _clientesRepo.eliminarCliente(cliente.id);
        if (!mounted) return;
        _showSnackBar('✓ Cliente eliminado', isSuccess: true);
      } catch (e) {
        if (!mounted) return;
        _showSnackBar('Error: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final iconData = widget.sucursal.contains('Centro')
        ? Icons.location_city_rounded
        : Icons.apartment_rounded;

    return Container(
      decoration: FitNetTheme.premiumCard,
      child: Column(
        children: [
          // Header expandible
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: FitNetTheme.gold.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(iconData, color: FitNetTheme.gold, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.sucursal,
                      style: const TextStyle(
                        color: FitNetTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: FitNetTheme.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          // Lista de clientes expandible
          if (_isExpanded)
            StreamBuilder<List<ClienteConTarjetaYSuscripcion>>(
              stream: _suscripcionesRepo.watchClientesConTarjetaYSuscripcion(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: CircularProgressIndicator(color: FitNetTheme.gold),
                    ),
                  );
                }

                final items = snapshot.data!;
                if (items.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No hay clientes',
                      style: TextStyle(color: FitNetTheme.textSecondary),
                    ),
                  );
                }

                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    children: items.map((item) {
                      final c = item.cliente;
                      final saldo = item.tarjeta?.saldo ?? 0.0;
                      final diasRestantes = item.diasRestantes;
                      final tieneSuscripcion = item.tieneSuscripcionActiva;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: FitNetTheme.cardLighter,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.04),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    c.nombre,
                                    style: const TextStyle(
                                      color: FitNetTheme.textPrimary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: tieneSuscripcion
                                              ? FitNetTheme.success.withValues(
                                                  alpha: 0.1,
                                                )
                                              : FitNetTheme.textSecondary
                                                    .withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          tieneSuscripcion
                                              ? '$diasRestantes día${diasRestantes != 1 ? 's' : ''}'
                                              : 'Sin suscripción',
                                          style: TextStyle(
                                            color: tieneSuscripcion
                                                ? FitNetTheme.success
                                                : FitNetTheme.textSecondary,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Saldo: \$${saldo.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          color: FitNetTheme.textSecondary,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              constraints: const BoxConstraints(
                                minWidth: 30,
                                minHeight: 30,
                              ),
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.edit_outlined, size: 15),
                              color: FitNetTheme.textSecondary,
                              tooltip: 'Editar',
                              onPressed: () => _editarCliente(c),
                            ),
                            IconButton(
                              constraints: const BoxConstraints(
                                minWidth: 30,
                                minHeight: 30,
                              ),
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.delete_outline, size: 15),
                              color: tieneSuscripcion
                                  ? FitNetTheme.textSecondary.withValues(
                                      alpha: 0.3,
                                    )
                                  : FitNetTheme.error.withValues(alpha: 0.7),
                              tooltip: tieneSuscripcion
                                  ? 'Suscripción activa'
                                  : 'Eliminar',
                              onPressed: () =>
                                  _eliminarCliente(c, tieneSuscripcion),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Widget de Historial de Movimientos por Sucursal
// ═══════════════════════════════════════════════════════════════════════
class _MovimientosSucursalSection extends StatefulWidget {
  final String sucursal;
  final AppProviders providers;

  const _MovimientosSucursalSection({
    required this.sucursal,
    required this.providers,
  });

  @override
  State<_MovimientosSucursalSection> createState() =>
      _MovimientosSucursalSectionState();
}

class _MovimientosSucursalSectionState
    extends State<_MovimientosSucursalSection> {
  bool _isExpanded = false;
  late MovimientosRepository _movimientosRepo;

  String _tipoFiltro = 'todos'; // 'todos', 'pago', 'recarga'
  String _periodoFiltro = 'todos'; // 'todos', 'hoy'
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();
  int _limiteVisibles = 10;

  @override
  void initState() {
    super.initState();
    _movimientosRepo = widget.providers.movimientosRepo(widget.sucursal);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final iconData = widget.sucursal.contains('Centro')
        ? Icons.location_city_rounded
        : Icons.apartment_rounded;

    return Container(
      decoration: FitNetTheme.premiumCard,
      child: Column(
        children: [
          // Header expandible
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: FitNetTheme.gold.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(iconData, color: FitNetTheme.gold, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.sucursal,
                          style: const TextStyle(
                            color: FitNetTheme.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Transacciones y auditoría de caja',
                          style: TextStyle(
                            color: FitNetTheme.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  StreamBuilder<List<MovimientoConDetalle>>(
                    stream: _movimientosRepo.watchMovimientosConDetalle(),
                    builder: (context, snapshot) {
                      final count = snapshot.data?.length ?? 0;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: FitNetTheme.gold.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: FitNetTheme.gold.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Text(
                          '$count movs',
                          style: const TextStyle(
                            color: FitNetTheme.gold,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: FitNetTheme.textSecondary,
                  ),
                ],
              ),
            ),
          ),

          // Contenido expandible
          if (_isExpanded)
            StreamBuilder<List<MovimientoConDetalle>>(
              stream: _movimientosRepo.watchMovimientosConDetalle(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(28),
                    child: Center(
                      child: CircularProgressIndicator(color: FitNetTheme.gold),
                    ),
                  );
                }

                final todos = snapshot.data!;
                final hoy = DateTime.now();

                // Calcular totales de la sucursal
                double totalPagos = 0.0;
                double totalRecargas = 0.0;
                for (final item in todos) {
                  if (item.movimiento.tipo == 'pago') {
                    totalPagos += item.movimiento.monto;
                  } else if (item.movimiento.tipo == 'recarga') {
                    totalRecargas += item.movimiento.monto;
                  }
                }

                // Filtrar lista
                final filtrados = todos.where((item) {
                  final mov = item.movimiento;

                  // Filtro por tipo
                  if (_tipoFiltro != 'todos' && mov.tipo != _tipoFiltro) {
                    return false;
                  }

                  // Filtro por periodo (hoy)
                  if (_periodoFiltro == 'hoy') {
                    final f = mov.fecha;
                    if (f.year != hoy.year ||
                        f.month != hoy.month ||
                        f.day != hoy.day) {
                      return false;
                    }
                  }

                  // Filtro por búsqueda de texto
                  if (_searchQuery.isNotEmpty) {
                    final q = _searchQuery.toLowerCase();
                    final nombreCliente =
                        item.cliente?.nombre.toLowerCase() ?? '';
                    final tarjetaId = mov.idTarjeta.toLowerCase();
                    final tipo = mov.tipo.toLowerCase();
                    if (!nombreCliente.contains(q) &&
                        !tarjetaId.contains(q) &&
                        !tipo.contains(q)) {
                      return false;
                    }
                  }

                  return true;
                }).toList();

                final itemsAMostrar = filtrados.take(_limiteVisibles).toList();
                final hayMas = filtrados.length > _limiteVisibles;

                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Divider(color: Colors.white.withValues(alpha: 0.06)),
                      const SizedBox(height: 12),

                      // ── Resumen de métricas de la sucursal ──
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildMetricaChip(
                            icon: Icons.receipt_long_rounded,
                            color: FitNetTheme.gold,
                            label: 'Total Pagos',
                            valor: '\$${totalPagos.toStringAsFixed(2)}',
                          ),
                          _buildMetricaChip(
                            icon: Icons.add_circle_outline,
                            color: FitNetTheme.success,
                            label: 'Total Recargas',
                            valor: '\$${totalRecargas.toStringAsFixed(2)}',
                          ),
                          _buildMetricaChip(
                            icon: Icons.swap_vert_rounded,
                            color: FitNetTheme.textSecondary,
                            label: 'Operaciones',
                            valor: '${todos.length}',
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ── Barra de búsqueda y filtros ──
                      TextField(
                        controller: _searchCtrl,
                        onChanged: (val) =>
                            setState(() => _searchQuery = val.trim()),
                        style: const TextStyle(
                          color: FitNetTheme.textPrimary,
                          fontSize: 13,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Buscar por cliente, tarjeta o tipo...',
                          hintStyle: TextStyle(
                            color: FitNetTheme.textSecondary.withValues(alpha: 0.6),
                            fontSize: 12,
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: FitNetTheme.gold,
                            size: 18,
                          ),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.clear,
                                    color: FitNetTheme.textSecondary,
                                    size: 16,
                                  ),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: FitNetTheme.cardLighter,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.06),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.06),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: FitNetTheme.gold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ── Filtros en chips (Tipo y Periodo) ──
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            // Periodo
                            _buildFilterChip(
                              label: 'Todos los días',
                              selected: _periodoFiltro == 'todos',
                              onSelected: () =>
                                  setState(() => _periodoFiltro = 'todos'),
                            ),
                            const SizedBox(width: 6),
                            _buildFilterChip(
                              label: 'Solo hoy',
                              selected: _periodoFiltro == 'hoy',
                              onSelected: () =>
                                  setState(() => _periodoFiltro = 'hoy'),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              height: 16,
                              width: 1,
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                            const SizedBox(width: 12),
                            // Tipo
                            _buildFilterChip(
                              label: 'Todos',
                              selected: _tipoFiltro == 'todos',
                              onSelected: () =>
                                  setState(() => _tipoFiltro = 'todos'),
                            ),
                            const SizedBox(width: 6),
                            _buildFilterChip(
                              label: 'Pagos',
                              selected: _tipoFiltro == 'pago',
                              color: FitNetTheme.gold,
                              onSelected: () =>
                                  setState(() => _tipoFiltro = 'pago'),
                            ),
                            const SizedBox(width: 6),
                            _buildFilterChip(
                              label: 'Recargas',
                              selected: _tipoFiltro == 'recarga',
                              color: FitNetTheme.success,
                              onSelected: () =>
                                  setState(() => _tipoFiltro = 'recarga'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── Lista de movimientos ──
                      if (filtrados.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          alignment: Alignment.center,
                          child: Column(
                            children: [
                              Icon(
                                Icons.receipt_long_outlined,
                                color: FitNetTheme.textSecondary
                                    .withValues(alpha: 0.3),
                                size: 40,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                todos.isEmpty
                                    ? 'Sin movimientos registrados en esta sucursal'
                                    : 'No hay movimientos que coincidan con el filtro',
                                style: const TextStyle(
                                  color: FitNetTheme.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        )
                      else ...[
                        ...itemsAMostrar.map((item) {
                          final mov = item.movimiento;
                          final isRecarga = mov.tipo == 'recarga';
                          final isPago = mov.tipo == 'pago';

                          final icon = isRecarga
                              ? Icons.add_circle_outline
                              : isPago
                                  ? Icons.receipt_long_rounded
                                  : Icons.swap_horiz_rounded;

                          final iconColor = isRecarga
                              ? FitNetTheme.success
                              : isPago
                                  ? FitNetTheme.gold
                                  : FitNetTheme.textSecondary;

                          final tipoLabel = isRecarga
                              ? 'Recarga'
                              : isPago
                                  ? 'Pago'
                                  : mov.tipo[0].toUpperCase() +
                                      mov.tipo.substring(1);

                          final clienteNombre =
                              item.cliente?.nombre ?? 'Cliente no vinculado';
                          final shortId = mov.idTarjeta.length >= 8
                              ? mov.idTarjeta.substring(0, 8)
                              : mov.idTarjeta;

                          final fecha = mov.fecha;
                          final fechaStr =
                              '${fecha.day.toString().padLeft(2, '0')}/'
                              '${fecha.month.toString().padLeft(2, '0')}/'
                              '${fecha.year} '
                              '${fecha.hour.toString().padLeft(2, '0')}:'
                              '${fecha.minute.toString().padLeft(2, '0')}';

                          final isSynced = mov.syncStatus == 'synced';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: FitNetTheme.cardLighter,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.04),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: iconColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(icon, color: iconColor, size: 16),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              clienteNombre,
                                              style: const TextStyle(
                                                color: FitNetTheme.textPrimary,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: iconColor.withValues(
                                                alpha: 0.1,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              tipoLabel,
                                              style: TextStyle(
                                                color: iconColor,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Text(
                                            'Tarjeta #$shortId',
                                            style: const TextStyle(
                                              color: FitNetTheme.textSecondary,
                                              fontSize: 11,
                                            ),
                                          ),
                                          const Text(
                                            ' · ',
                                            style: TextStyle(
                                              color: FitNetTheme.textSecondary,
                                            ),
                                          ),
                                          Text(
                                            fechaStr,
                                            style: const TextStyle(
                                              color: FitNetTheme.textSecondary,
                                              fontSize: 11,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Icon(
                                            isSynced
                                                ? Icons.cloud_done_rounded
                                                : Icons.cloud_queue_rounded,
                                            size: 12,
                                            color: isSynced
                                                ? FitNetTheme.success
                                                : FitNetTheme.gold
                                                    .withValues(alpha: 0.7),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${isRecarga ? '+' : '-'}\$${mov.monto.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    color: isRecarga
                                        ? FitNetTheme.success
                                        : FitNetTheme.gold,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),

                        // Botón mostrar más / mostrar menos
                        if (hayMas || _limiteVisibles > 10)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (hayMas)
                                  TextButton.icon(
                                    icon: const Icon(
                                      Icons.expand_more_rounded,
                                      size: 16,
                                      color: FitNetTheme.gold,
                                    ),
                                    label: Text(
                                      'Ver más (${filtrados.length - _limiteVisibles} restantes)',
                                      style: const TextStyle(
                                        color: FitNetTheme.gold,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _limiteVisibles += 15;
                                      });
                                    },
                                  ),
                                if (_limiteVisibles > 10)
                                  TextButton.icon(
                                    icon: const Icon(
                                      Icons.expand_less_rounded,
                                      size: 16,
                                      color: FitNetTheme.textSecondary,
                                    ),
                                    label: const Text(
                                      'Ver menos',
                                      style: TextStyle(
                                        color: FitNetTheme.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _limiteVisibles = 10;
                                      });
                                    },
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildMetricaChip({
    required IconData icon,
    required Color color,
    required String label,
    required String valor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: const TextStyle(
              color: FitNetTheme.textSecondary,
              fontSize: 11,
            ),
          ),
          Text(
            valor,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onSelected,
    Color color = FitNetTheme.gold,
  }) {
    return InkWell(
      onTap: onSelected,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.15) : FitNetTheme.cardLighter,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? color.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? color : FitNetTheme.textSecondary,
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

