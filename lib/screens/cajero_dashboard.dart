import 'package:flutter/material.dart';
import '../app_providers.dart';
import '../core/database/app_database.dart';
import '../data/repositories/clientes_repository.dart';
import '../data/repositories/movimientos_repository.dart';
import '../data/repositories/tarjetas_repository.dart';
import '../models/models.dart';
import '../widgets/theme_widgets.dart';
import 'login_screen.dart';

/// Dashboard del Cajero – Vista de Distribución Local.
///
/// Permite operar una sola sucursal con las funciones:
/// 1. Registrar nuevo cliente (nombre + saldo inicial)
/// 2. Recargar tarjeta (ID tarjeta + monto)
/// 3. Cobrar acceso al gimnasio (simular cobro)
/// 4. Ver clientes registrados en la sucursal
class CajeroDashboard extends StatefulWidget {
  final Usuario usuario;

  const CajeroDashboard({super.key, required this.usuario});

  @override
  State<CajeroDashboard> createState() => _CajeroDashboardState();
}

class _CajeroDashboardState extends State<CajeroDashboard> {
  // Controladores para Registrar Cliente
  final _nombreClienteCtrl = TextEditingController();
  final _saldoInicialCtrl = TextEditingController();

  // Controladores para Recarga
  final _idRecargaCtrl = TextEditingController();
  final _montoRecargaCtrl = TextEditingController();

  // Controlador para Cobro de Acceso
  final _idAccesoCtrl = TextEditingController();

  String get _sucursal => widget.usuario.sucursalAsignada ?? 'Sucursal Centro';

  int _selectedTab = 0;

  // ── Repositorios (se inicializan en didChangeDependencies) ──
  late ClientesRepository _clientesRepo;
  late TarjetasRepository _tarjetasRepo;
  late MovimientosRepository _movimientosRepo;
  late AppProviders _providers;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _providers = AppProviders.of(context);
    _clientesRepo = _providers.clientesRepo(_sucursal);
    _tarjetasRepo = _providers.tarjetasRepo(_sucursal);
    _movimientosRepo = _providers.movimientosRepo(_sucursal);
  }

  @override
  void dispose() {
    _nombreClienteCtrl.dispose();
    _saldoInicialCtrl.dispose();
    _idRecargaCtrl.dispose();
    _montoRecargaCtrl.dispose();
    _idAccesoCtrl.dispose();
    super.dispose();
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

  // ═══════════════════════════════════════════════════════════
  // REGISTRAR NUEVO CLIENTE
  // Usa ClientesRepository → transacción Drift que crea cliente + tarjeta
  // + entrada en sync_queue.
  // ═══════════════════════════════════════════════════════════
  Future<void> _registrarCliente() async {
    final nombre = _nombreClienteCtrl.text.trim();
    final saldoText = _saldoInicialCtrl.text.trim();

    if (nombre.isEmpty || saldoText.isEmpty) {
      _showSnackBar('Completa todos los campos', isError: true);
      return;
    }

    final saldo = double.tryParse(saldoText);
    if (saldo == null || saldo < 0) {
      _showSnackBar('Saldo inválido', isError: true);
      return;
    }

    try {
      final tarjetaId = await _clientesRepo.registrarCliente(
        nombre: nombre,
        saldoInicial: saldo,
      );
      _nombreClienteCtrl.clear();
      _saldoInicialCtrl.clear();

      if (!mounted) return;
      _showSnackBar(
        '✓ Cliente "$nombre" registrado · Tarjeta #${tarjetaId.substring(0, 8)}',
        isSuccess: true,
      );
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Error: $e', isError: true);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // RECARGAR TARJETA
  // Usa TarjetasRepository → transacción Drift atómica
  // ═══════════════════════════════════════════════════════════
  Future<void> _recargarTarjeta() async {
    final idText = _idRecargaCtrl.text.trim();
    final montoText = _montoRecargaCtrl.text.trim();

    if (idText.isEmpty || montoText.isEmpty) {
      _showSnackBar('Completa todos los campos', isError: true);
      return;
    }

    final monto = double.tryParse(montoText);
    if (monto == null || monto <= 0) {
      _showSnackBar('Monto inválido', isError: true);
      return;
    }

    try {
      await _tarjetasRepo.recargarTarjeta(idText, monto);
      _idRecargaCtrl.clear();
      _montoRecargaCtrl.clear();

      final shortId = idText.length >= 8 ? idText.substring(0, 8) : idText;
      if (!mounted) return;
      _showSnackBar(
        '✓ Recarga local de \$${monto.toStringAsFixed(2)} aplicada de inmediato a tarjeta #$shortId',
        isSuccess: true,
      );
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('$e', isError: true);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // COBRAR ACCESO
  // Usa TarjetasRepository → transacción Drift atómica local
  // ═══════════════════════════════════════════════════════════
  Future<void> _cobrarAcceso() async {
    final idText = _idAccesoCtrl.text.trim();
    if (idText.isEmpty) {
      _showSnackBar('Ingresa el ID de la tarjeta', isError: true);
      return;
    }

    try {
      await _tarjetasRepo.cobrarAcceso(idText, 80.0);
      _idAccesoCtrl.clear();

      final shortId = idText.length >= 8 ? idText.substring(0, 8) : idText;
      if (!mounted) return;
      _showSnackBar(
        '✓ Acceso autorizado y descontado de inmediato (Tarjeta #$shortId)',
        isSuccess: true,
      );
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('$e', isError: true);
    }
  }

  // ── Acciones directas e inmediatas desde la lista de clientes ──
  void _seleccionarParaOperar(String idTarjeta, String nombre) {
    _idRecargaCtrl.text = idTarjeta;
    _idAccesoCtrl.text = idTarjeta;
    _showSnackBar('Tarjeta de $nombre cargada para operar');
  }

  void _cargarParaRecarga(String idTarjeta) {
    _idRecargaCtrl.text = idTarjeta;
    setState(() => _selectedTab = 1);
  }

  Future<void> _cobrarAccesoRapido(String idTarjeta, String nombre) async {
    try {
      await _tarjetasRepo.cobrarAcceso(idTarjeta, 80.0);
      if (!mounted) return;
      _showSnackBar(
        '✓ Acceso autorizado (\$80.00) cobrado localmente a $nombre',
        isSuccess: true,
      );
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('$e', isError: true);
    }
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

  @override
  Widget build(BuildContext context) {
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
                  horizontal: isWide ? 40 : 12,
                  vertical: isWide ? 20 : 14,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Métricas rápidas (reactivas con StreamBuilder) ──
                    _buildQuickMetricsStream(isWide),
                    const SizedBox(height: 28),

                    // ── Tabs de operaciones ──
                    _buildTabBar(),
                    const SizedBox(height: 20),

                    // ── Contenido del tab seleccionado + lista clientes ──
                    if (isWide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 5, child: _buildTabContent()),
                          const SizedBox(width: 24),
                          Expanded(flex: 4, child: _buildClientesListStream()),
                        ],
                      )
                    else ...[
                      _buildTabContent(),
                      const SizedBox(height: 24),
                      _buildClientesListStream(),
                    ],

                    const SizedBox(height: 16),
                    // ── Indicador de operaciones pendientes ──
                    _buildSyncStatusIndicator(),
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmall = screenWidth < 500;

    return Container(
      padding: EdgeInsets.fromLTRB(
        isSmall ? 14 : 24,
        12,
        isSmall ? 14 : 24,
        12,
      ),
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
                Icons.storefront_rounded,
                color: FitNetTheme.backgroundDark,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _sucursal,
                    style: const TextStyle(
                      color: FitNetTheme.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Cajero: ${widget.usuario.username} · Distribución Local',
                    style: const TextStyle(
                      color: FitNetTheme.textSecondary,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (MediaQuery.of(context).size.width > 500) ...[
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
            const SizedBox(width: 12),
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

  // ── Métricas rápidas con StreamBuilder ──
  Widget _buildQuickMetricsStream(bool isWide) {
    return StreamBuilder<List<Cliente>>(
      stream: _clientesRepo.watchClientes(),
      builder: (context, clientesSnap) {
        final totalClientes = clientesSnap.data?.length ?? 0;

        return StreamBuilder<List<Movimiento>>(
          stream: _movimientosRepo.watchMovimientosHoy(),
          builder: (context, movsSnap) {
            final movimientos = movsSnap.data ?? [];
            final totalMovimientos = movimientos.length;
            final ingresos = movimientos
                .where((m) => m.tipo == 'pago')
                .fold(0.0, (sum, m) => sum + m.monto);

            return _buildQuickMetrics(
              totalClientes,
              totalMovimientos,
              ingresos,
              isWide,
            );
          },
        );
      },
    );
  }

  Widget _buildQuickMetrics(
    int totalClientes,
    int movimientos,
    double ingresos,
    bool isWide,
  ) {
    final metrics = [
      MetricIndicator(
        label: isWide ? 'Clientes Registrados' : 'Clientes',
        value: '$totalClientes',
        icon: Icons.people_outline,
        subtitle: isWide ? 'En esta sucursal' : null,
      ),
      MetricIndicator(
        label: isWide ? 'Movimientos Hoy' : 'Movimientos',
        value: '$movimientos',
        icon: Icons.receipt_long_outlined,
        subtitle: isWide ? 'Transacciones del día' : null,
      ),
      MetricIndicator(
        label: isWide ? 'Ingresos Hoy' : 'Ingresos',
        value: '\$${ingresos.toStringAsFixed(2)}',
        icon: Icons.trending_up_rounded,
        valueColor: FitNetTheme.gold,
        subtitle: isWide ? 'Cobros de acceso' : null,
      ),
    ];

    // Siempre los 3 cards horizontales y a la par (móvil y desktop)
    return Row(
      children: metrics
          .map(
            (m) => Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: isWide ? 6 : 4),
                child: m,
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildTabBar() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 550;

    final tabs = [
      (
        Icons.person_add_outlined,
        isMobile ? 'Registrar' : 'Registrar Cliente',
      ),
      (
        Icons.credit_card_outlined,
        isMobile ? 'Recargar' : 'Recargar Tarjeta',
      ),
      (
        Icons.login_rounded,
        isMobile ? 'Cobrar' : 'Cobrar Acceso',
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: FitNetTheme.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: tabs.asMap().entries.map((entry) {
          final idx = entry.key;
          final (icon, label) = entry.value;
          final isSelected = _selectedTab == idx;

          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = idx),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: EdgeInsets.symmetric(
                  vertical: isMobile ? 10 : 12,
                  horizontal: 4,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? FitNetTheme.gold.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: isSelected
                      ? Border.all(
                          color: FitNetTheme.gold.withValues(alpha: 0.3),
                        )
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      size: isMobile ? 16 : 18,
                      color: isSelected
                          ? FitNetTheme.gold
                          : FitNetTheme.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isSelected
                              ? FitNetTheme.gold
                              : FitNetTheme.textSecondary,
                          fontSize: isMobile ? 12 : 13,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case 0:
        return _buildRegistrarClienteForm();
      case 1:
        return _buildRecargarTarjetaForm();
      case 2:
        return _buildCobrarAccesoForm();
      default:
        return const SizedBox.shrink();
    }
  }

  // ── Formulario: Registrar Cliente ──
  Widget _buildRegistrarClienteForm() {
    return PremiumCard(
      title: 'Registrar Nuevo Cliente',
      icon: Icons.person_add_outlined,
      useGoldAccent: true,
      child: Column(
        children: [
          TextFormField(
            controller: _nombreClienteCtrl,
            style: const TextStyle(color: FitNetTheme.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Nombre Completo',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _saldoInicialCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: FitNetTheme.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Saldo Inicial (\$)',
              prefixIcon: Icon(Icons.attach_money_rounded),
            ),
          ),
          const SizedBox(height: 24),
          GoldButton(
            label: 'Registrar Cliente',
            icon: Icons.person_add_rounded,
            textColor: const Color(0xFF5B4002),
            iconColor: const Color(0xFF5B4002),
            onPressed: _registrarCliente,
          ),
        ],
      ),
    );
  }

  // ── Formulario: Recargar Tarjeta ──
  Widget _buildRecargarTarjetaForm() {
    return PremiumCard(
      title: 'Recargar Tarjeta',
      icon: Icons.credit_card_outlined,
      useGoldAccent: true,
      child: Column(
        children: [
          TextFormField(
            controller: _idRecargaCtrl,
            style: const TextStyle(color: FitNetTheme.textPrimary),
            decoration: const InputDecoration(
              labelText: 'ID de Tarjeta (ej. primeros 8 dígitos o UUID)',
              prefixIcon: Icon(Icons.credit_card_outlined),
              hintText: 'Ingresa el ID o tócalo en la lista',
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _montoRecargaCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: FitNetTheme.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Monto a Recargar (\$)',
              prefixIcon: Icon(Icons.attach_money_rounded),
            ),
          ),
          const SizedBox(height: 24),
          GoldButton(
            label: 'Recargar Tarjeta',
            icon: Icons.add_card_rounded,
            textColor: const Color(0xFF5B4002),
            iconColor: const Color(0xFF5B4002),
            onPressed: _recargarTarjeta,
          ),
        ],
      ),
    );
  }

  // ── Formulario: Cobrar Acceso ──
  Widget _buildCobrarAccesoForm() {
    return PremiumCard(
      title: 'Cobro de Acceso al Gimnasio',
      icon: Icons.login_rounded,
      useGoldAccent: true,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: FitNetTheme.gold.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: FitNetTheme.gold.withValues(alpha: 0.15),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: FitNetTheme.gold, size: 18),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'El costo de acceso es de \$80.00 MXN por visita.',
                    style: TextStyle(
                      color: FitNetTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _idAccesoCtrl,
            style: const TextStyle(color: FitNetTheme.textPrimary),
            decoration: const InputDecoration(
              labelText: 'ID de Tarjeta del Cliente (ej. primeros 8 dígitos o UUID)',
              prefixIcon: Icon(Icons.credit_card_outlined),
              hintText: 'Ingresa el ID o tócalo en la lista',
            ),
          ),
          const SizedBox(height: 24),
          GoldButton(
            label: 'Cobrar Acceso · \$80.00',
            icon: Icons.check_circle_outline,
            textColor: const Color(0xFF5B4002),
            iconColor: const Color(0xFF5B4002),
            onPressed: _cobrarAcceso,
          ),
        ],
      ),
    );
  }

  // ── Lista de Clientes (reactiva con StreamBuilder) ──
  // ── Lista de Clientes (reactiva instantánea con watchClientesConTarjeta) ──
  Widget _buildClientesListStream() {
    return StreamBuilder<List<ClienteConTarjeta>>(
      stream: _clientesRepo.watchClientesConTarjeta(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const PremiumCard(
            title: 'Clientes',
            icon: Icons.people_outline,
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(color: FitNetTheme.gold),
              ),
            ),
          );
        }

        final items = snapshot.data ?? [];
        return _buildClientesList(items);
      },
    );
  }

  Widget _buildClientesList(List<ClienteConTarjeta> items) {
    final screenWidth = MediaQuery.of(context).size.width;

    return PremiumCard(
      title: 'Clientes de $_sucursal',
      icon: Icons.people_outline,
      child: items.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No hay clientes registrados',
                  style: TextStyle(color: FitNetTheme.textSecondary),
                ),
              ),
            )
          : Column(
              children: items.map((item) {
                final c = item.cliente;
                final tarjeta = item.tarjeta;
                final saldo = tarjeta?.saldo ?? 0.0;
                final tarjetaIdShort = tarjeta != null
                    ? (tarjeta.idTarjeta.length >= 8
                        ? tarjeta.idTarjeta.substring(0, 8)
                        : tarjeta.idTarjeta)
                    : '---';

                return Container(
                  key: ValueKey('cliente_${c.id}_${tarjeta?.idTarjeta}'),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: FitNetTheme.cardLighter,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.04),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: FitNetTheme.gold.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.person_outline,
                          color: FitNetTheme.gold,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InkWell(
                          onTap: tarjeta == null
                              ? null
                              : () => _seleccionarParaOperar(
                                  tarjeta.idTarjeta,
                                  c.nombre,
                                ),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 2,
                              horizontal: 2,
                            ),
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
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Text(
                                      'Tarjeta #$tarjetaIdShort',
                                      style: const TextStyle(
                                        color: FitNetTheme.textSecondary,
                                        fontSize: 11,
                                      ),
                                    ),
                                    if (screenWidth > 450) ...[
                                      const SizedBox(width: 4),
                                      const Text(
                                        '· Toca',
                                        style: TextStyle(
                                          color: FitNetTheme.gold,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Acciones directas e inmediatas compactas
                      if (tarjeta != null) ...[
                        IconButton(
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          padding: EdgeInsets.zero,
                          icon: const Icon(
                            Icons.add_card_rounded,
                            size: 17,
                          ),
                          color: FitNetTheme.gold,
                          tooltip: 'Recargar tarjeta de ${c.nombre}',
                          onPressed: () =>
                              _cargarParaRecarga(tarjeta.idTarjeta),
                        ),
                        IconButton(
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          padding: EdgeInsets.zero,
                          icon: const Icon(
                            Icons.login_rounded,
                            size: 17,
                          ),
                          color: saldo >= 80
                              ? FitNetTheme.success
                              : FitNetTheme.textSecondary.withValues(alpha: 0.3),
                          tooltip: saldo >= 80
                              ? 'Cobro inmediato (\$80.00)'
                              : 'Saldo insuficiente (\$${saldo.toStringAsFixed(2)})',
                          onPressed: saldo >= 80
                              ? () => _cobrarAccesoRapido(
                                  tarjeta.idTarjeta,
                                  c.nombre,
                                )
                              : null,
                        ),
                        const SizedBox(width: 4),
                      ],
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: saldo >= 80
                              ? FitNetTheme.success.withValues(alpha: 0.12)
                              : FitNetTheme.error.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '\$${saldo.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: saldo >= 80
                                  ? FitNetTheme.success
                                  : FitNetTheme.error,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  // ── Indicador de sincronización pendiente ──
  Widget _buildSyncStatusIndicator() {
    return StreamBuilder<int>(
      stream: _providers.syncQueueRepo.watchContadorPendientes(),
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
              Tooltip(
                message:
                    'La conexión con el servidor central se implementará próximamente.',
                child: OutlinedButton.icon(
                  onPressed: null, // Deshabilitado hasta Supabase
                  icon: const Icon(Icons.sync_disabled, size: 14),
                  label: const Text(
                    'Sincronizar',
                    style: TextStyle(fontSize: 11),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: FitNetTheme.textSecondary,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
