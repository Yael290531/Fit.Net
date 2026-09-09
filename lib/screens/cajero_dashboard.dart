import 'package:flutter/material.dart';
import '../app_providers.dart';
import '../core/database/app_database.dart';
import '../data/repositories/clientes_repository.dart';
import '../data/repositories/movimientos_repository.dart';
import '../data/repositories/suscripciones_repository.dart';
import '../data/repositories/tarjetas_repository.dart';
import '../models/models.dart';
import '../widgets/theme_widgets.dart';
import 'login_screen.dart';

/// Dashboard del Cajero – Vista de Distribución Local.
///
/// Permite operar una sola sucursal con las funciones:
/// 1. Registrar nuevo cliente (nombre + saldo inicial)
/// 2. Recargar tarjeta (ID tarjeta + monto)
/// 3. Cobrar suscripción (mensual $500, semanal $150, diaria $80)
/// 4. Ver clientes registrados con estado de suscripción
/// 5. Editar y eliminar clientes
class CajeroDashboard extends StatefulWidget {
  final Usuario usuario;

  const CajeroDashboard({super.key, required this.usuario});

  @override
  State<CajeroDashboard> createState() => _CajeroDashboardState();
}

class _CajeroDashboardState extends State<CajeroDashboard> {
  // Controladores para Registrar Cliente
  final _nombreClienteCtrl = TextEditingController();
  final _telefonoClienteCtrl = TextEditingController();
  final _saldoInicialCtrl = TextEditingController();
  bool _vincularTarjeta = false;
  final _numTarjetaCreditoCtrl = TextEditingController();
  final _expiracionCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();

  // Controladores para Recarga
  final _idRecargaCtrl = TextEditingController();
  final _montoRecargaCtrl = TextEditingController();

  // Controlador para Cobro de Suscripción
  final _idSuscripcionCtrl = TextEditingController();
  TipoSuscripcion _tipoSeleccionado = TipoSuscripcion.mensual;

  String get _sucursal => widget.usuario.sucursalAsignada ?? 'Sucursal Centro';

  int _selectedTab = 0;
  int _selectedSubTab = 0; // Sub-tab dentro de Clientes: 0=Registrar, 1=Recargar, 2=Suscripción

  // ── Repositorios (se inicializan en didChangeDependencies) ──
  late ClientesRepository _clientesRepo;
  late TarjetasRepository _tarjetasRepo;
  late MovimientosRepository _movimientosRepo;
  late SuscripcionesRepository _suscripcionesRepo;
  late AppProviders _providers;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _providers = AppProviders.of(context);
    _clientesRepo = _providers.clientesRepo(_sucursal);
    _tarjetasRepo = _providers.tarjetasRepo(_sucursal);
    _movimientosRepo = _providers.movimientosRepo(_sucursal);
    _suscripcionesRepo = _providers.suscripcionesRepo(_sucursal);

    // Ejecutar limpieza de clientes inactivos al iniciar.
    _clientesRepo.limpiarClientesInactivos();
  }

  @override
  void dispose() {
    _nombreClienteCtrl.dispose();
    _telefonoClienteCtrl.dispose();
    _saldoInicialCtrl.dispose();
    _idRecargaCtrl.dispose();
    _montoRecargaCtrl.dispose();
    _idSuscripcionCtrl.dispose();
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
    final telefono = _telefonoClienteCtrl.text.trim();

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
        telefono: telefono.isNotEmpty ? telefono : null,
        saldoInicial: saldo,
      );
      _nombreClienteCtrl.clear();
      _saldoInicialCtrl.clear();
      _telefonoClienteCtrl.clear();

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
  // COBRAR SUSCRIPCIÓN
  // Usa SuscripcionesRepository → transacción Drift atómica local
  // Descuenta del saldo y crea suscripción con fecha de expiración
  // ═══════════════════════════════════════════════════════════
  Future<void> _cobrarSuscripcion() async {
    final idText = _idSuscripcionCtrl.text.trim();
    if (idText.isEmpty) {
      _showSnackBar('Ingresa el ID de la tarjeta', isError: true);
      return;
    }

    try {
      // Buscar la tarjeta para obtener el clienteId.
      final tarjeta = await _tarjetasRepo.buscarTarjetaPorId(idText);
      if (tarjeta == null) {
        if (!mounted) return;
        _showSnackBar('Tarjeta "$idText" no encontrada', isError: true);
        return;
      }

      await _suscripcionesRepo.registrarSuscripcion(
        clienteId: tarjeta.clienteId,
        tipo: _tipoSeleccionado,
        idTarjeta: tarjeta.idTarjeta,
      );

      _idSuscripcionCtrl.clear();
      final shortId = idText.length >= 8 ? idText.substring(0, 8) : idText;
      if (!mounted) return;
      _showSnackBar(
        '✓ ${_tipoSeleccionado.etiqueta} cobrada (\$${_tipoSeleccionado.precio.toStringAsFixed(2)}) '
        '· ${_tipoSeleccionado.dias} días · Tarjeta #$shortId',
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
    _idSuscripcionCtrl.text = idTarjeta;
    _showSnackBar('Tarjeta de $nombre cargada para operar');
  }

  void _cargarParaRecarga(String idTarjeta) {
    _idRecargaCtrl.text = idTarjeta;
    setState(() {
      _selectedTab = 1;
      _selectedSubTab = 1;
    });
  }

  void _cargarParaSuscripcion(String idTarjeta) {
    _idSuscripcionCtrl.text = idTarjeta;
    setState(() {
      _selectedTab = 1;
      _selectedSubTab = 2;
    });
  }

  // ── Editar cliente (diálogo modal) ──
  Future<void> _mostrarDialogoEditarCliente(Cliente cliente) async {
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
      final nuevoNombre = nombreCtrl.text.trim();
      final nuevoTelefono = telefonoCtrl.text.trim();

      if (nuevoNombre.isEmpty) {
        _showSnackBar('El nombre no puede estar vacío', isError: true);
        return;
      }

      try {
        await _clientesRepo.editarCliente(
          cliente.id,
          nombre: nuevoNombre != cliente.nombre ? nuevoNombre : null,
          telefono: nuevoTelefono.isNotEmpty ? nuevoTelefono : null,
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

  // ── Eliminar cliente (soft-delete con confirmación) ──
  Future<void> _mostrarDialogoEliminarCliente(
    Cliente cliente,
    bool tieneSuscripcionActiva,
  ) async {
    if (tieneSuscripcionActiva) {
      _showSnackBar(
        'No se puede eliminar: el cliente tiene suscripción activa',
        isError: true,
      );
      return;
    }

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
                color: FitNetTheme.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.delete_outline, color: FitNetTheme.error, size: 18),
            ),
            const SizedBox(width: 12),
            const Text(
              'Eliminar Cliente',
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿Estás seguro de eliminar a "${cliente.nombre}"?',
              style: const TextStyle(color: FitNetTheme.textPrimary, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: FitNetTheme.gold.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: FitNetTheme.gold.withValues(alpha: 0.15)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: FitNetTheme.gold, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'El cliente quedará en espera 20 días por si vuelve a suscribirse. '
                      'Después se eliminará permanentemente.',
                      style: TextStyle(color: FitNetTheme.textSecondary, fontSize: 12),
                    ),
                  ),
                ],
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
        _showSnackBar(
          '✓ Cliente "${cliente.nombre}" eliminado',
          isSuccess: true,
        );
      } catch (e) {
        if (!mounted) return;
        _showSnackBar('Error: $e', isError: true);
      }
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

            // ── Tab bar fijo debajo del header ──
            _buildTabBar(),

            // ── Contenido ──
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isWide ? 40 : 12,
                  vertical: isWide ? 20 : 14,
                ),
                child: _selectedTab == 0
                    // ── Dashboard: métricas + lista de clientes ──
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildQuickMetricsStream(isWide),
                          const SizedBox(height: 24),
                          _buildClientesListStream(),
                          const SizedBox(height: 16),
                        ],
                      )
                    : _selectedTab == 2
                    // ── Historial: lista de movimientos ──
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHistorialMovimientos(),
                          const SizedBox(height: 16),
                        ],
                      )
                    // ── Clientes: sub-tabs + formulario + lista ──
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildClientesSubTabBar(),
                          const SizedBox(height: 20),
                          if (isWide)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: _selectedSubTab == 0 ? 8 : 5, 
                                  child: Center(
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxWidth: _selectedSubTab == 0 ? 600 : double.infinity
                                      ),
                                      child: _buildTabContent(),
                                    ),
                                  ),
                                ),
                                if (_selectedSubTab != 0) ...[
                                  const SizedBox(width: 24),
                                  Expanded(flex: 4, child: _buildClientesListStream()),
                                ]
                              ],
                            )
                          else ...[
                            _buildTabContent(),
                            if (_selectedSubTab != 0) ...[
                              const SizedBox(height: 24),
                              _buildClientesListStream(),
                            ]
                          ],
                          const SizedBox(height: 16),
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
            const SizedBox(width: 8),
            _buildSyncHeaderButton(),
            const SizedBox(width: 4),
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
        subtitle: isWide ? 'Cobros de suscripción' : null,
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
        Icons.dashboard_rounded,
        'Dashboard',
      ),
      (
        Icons.people_rounded,
        'Clientes',
      ),
      (
        Icons.history_rounded,
        'Historial',
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: FitNetTheme.surfaceDark,
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected
                          ? FitNetTheme.gold
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
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
    switch (_selectedSubTab) {
      case 0:
        return _buildRegistrarClienteForm();
      case 1:
        return _buildRecargarTarjetaForm();
      case 2:
        return _buildCobrarSuscripcionForm();
      default:
        return const SizedBox.shrink();
    }
  }

  // ── Sub-tabs dentro de Clientes ──
  Widget _buildClientesSubTabBar() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 550;

    final subTabs = [
      (
        Icons.person_add_outlined,
        isMobile ? 'Registrar' : 'Registrar Cliente',
      ),
      (
        Icons.credit_card_outlined,
        isMobile ? 'Recargar' : 'Recargar Tarjeta',
      ),
      (
        Icons.card_membership_rounded,
        isMobile ? 'Suscripción' : 'Cobrar Suscripción',
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
        children: subTabs.asMap().entries.map((entry) {
          final idx = entry.key;
          final (icon, label) = entry.value;
          final isSelected = _selectedSubTab == idx;

          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedSubTab = idx),
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
            controller: _telefonoClienteCtrl,
            keyboardType: TextInputType.phone,
            style: const TextStyle(color: FitNetTheme.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Teléfono (opcional)',
              prefixIcon: Icon(Icons.phone_outlined),
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
          const SizedBox(height: 16),
          // Botón para vincular tarjeta
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _vincularTarjeta = !_vincularTarjeta),
              icon: Icon(
                _vincularTarjeta ? Icons.credit_card_off_outlined : Icons.add_card_outlined,
                color: FitNetTheme.gold,
              ),
              label: Text(
                _vincularTarjeta ? 'Quitar Tarjeta Bancaria' : 'Vincular Tarjeta Bancaria',
                style: const TextStyle(color: FitNetTheme.gold),
              ),
            ),
          ),
          
          // Formulario de tarjeta bancaria desplegable
          if (_vincularTarjeta) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: FitNetTheme.backgroundDark.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: FitNetTheme.gold.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Datos de la Tarjeta para Cobro Rápido',
                    style: TextStyle(
                      color: FitNetTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _numTarjetaCreditoCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 16,
                    style: const TextStyle(color: FitNetTheme.textPrimary, letterSpacing: 2),
                    decoration: const InputDecoration(
                      labelText: 'Número de Tarjeta',
                      prefixIcon: Icon(Icons.credit_card_rounded),
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _expiracionCtrl,
                          keyboardType: TextInputType.datetime,
                          maxLength: 5,
                          style: const TextStyle(color: FitNetTheme.textPrimary),
                          decoration: const InputDecoration(
                            labelText: 'Vencimiento (MM/AA)',
                            prefixIcon: Icon(Icons.date_range_rounded),
                            counterText: '',
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _pinCtrl,
                          keyboardType: TextInputType.number,
                          maxLength: 4,
                          obscureText: true,
                          style: const TextStyle(color: FitNetTheme.textPrimary),
                          decoration: const InputDecoration(
                            labelText: 'PIN',
                            prefixIcon: Icon(Icons.password_rounded),
                            counterText: '',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          
          const SizedBox(height: 24),
          GoldButton(
            label: 'Registrar Cliente',
            icon: Icons.person_add_rounded,
            textColor: const Color(0xFF5B4002),
            iconColor: const Color(0xFF5B4002),
            onPressed: () {
              // Limpiar datos de tarjeta al registrar para simular que se guardó
              if (_vincularTarjeta) {
                _numTarjetaCreditoCtrl.clear();
                _expiracionCtrl.clear();
                _pinCtrl.clear();
                setState(() => _vincularTarjeta = false);
              }
              _registrarCliente();
            },
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

  // ── Formulario: Cobrar Suscripción ──
  Widget _buildCobrarSuscripcionForm() {
    return PremiumCard(
      title: 'Cobro de Suscripción',
      icon: Icons.card_membership_rounded,
      useGoldAccent: true,
      child: Column(
        children: [
          // ── Selector de plan ──
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: FitNetTheme.gold.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: FitNetTheme.gold.withValues(alpha: 0.1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 10),
                  child: Text(
                    'Selecciona el plan:',
                    style: TextStyle(
                      color: FitNetTheme.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Row(
                  children: TipoSuscripcion.values.map((tipo) {
                    final isSelected = _tipoSeleccionado == tipo;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _tipoSeleccionado = tipo),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? FitNetTheme.gold.withValues(alpha: 0.15)
                                : FitNetTheme.cardLighter,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? FitNetTheme.gold
                                  : Colors.white.withValues(alpha: 0.06),
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                tipo == TipoSuscripcion.mensual
                                    ? Icons.calendar_month_rounded
                                    : tipo == TipoSuscripcion.semanal
                                        ? Icons.date_range_rounded
                                        : Icons.today_rounded,
                                color: isSelected
                                    ? FitNetTheme.gold
                                    : FitNetTheme.textSecondary,
                                size: 22,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                tipo.etiqueta,
                                style: TextStyle(
                                  color: isSelected
                                      ? FitNetTheme.gold
                                      : FitNetTheme.textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '\$${tipo.precio.toStringAsFixed(0)}',
                                style: TextStyle(
                                  color: isSelected
                                      ? FitNetTheme.gold
                                      : FitNetTheme.textSecondary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                '${tipo.dias} día${tipo.dias > 1 ? 's' : ''}',
                                style: const TextStyle(
                                  color: FitNetTheme.textSecondary,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _idSuscripcionCtrl,
            style: const TextStyle(color: FitNetTheme.textPrimary),
            decoration: const InputDecoration(
              labelText: 'ID de Tarjeta del Cliente',
              prefixIcon: Icon(Icons.credit_card_outlined),
              hintText: 'Ingresa el ID o tócalo en la lista',
            ),
          ),
          const SizedBox(height: 24),
          GoldButton(
            label: 'Cobrar ${_tipoSeleccionado.etiqueta} · \$${_tipoSeleccionado.precio.toStringAsFixed(0)}',
            icon: Icons.check_circle_outline,
            textColor: const Color(0xFF5B4002),
            iconColor: const Color(0xFF5B4002),
            onPressed: _cobrarSuscripcion,
          ),
        ],
      ),
    );
  }

  // ── Lista de Clientes (reactiva con StreamBuilder + suscripciones) ──
  Widget _buildClientesListStream() {
    return StreamBuilder<List<ClienteConTarjetaYSuscripcion>>(
      stream: _suscripcionesRepo.watchClientesConTarjetaYSuscripcion(),
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

  Widget _buildClientesList(List<ClienteConTarjetaYSuscripcion> items) {
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
                final diasRestantes = item.diasRestantes;
                final tieneSuscripcion = item.tieneSuscripcionActiva;

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
                  child: Column(
                    children: [
                      Row(
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
                          // Acciones de gestión: editar y eliminar
                          IconButton(
                            constraints: const BoxConstraints(
                              minWidth: 30,
                              minHeight: 30,
                            ),
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.edit_outlined, size: 15),
                            color: FitNetTheme.textSecondary,
                            tooltip: 'Editar ${c.nombre}',
                            onPressed: () => _mostrarDialogoEditarCliente(c),
                          ),
                          IconButton(
                            constraints: const BoxConstraints(
                              minWidth: 30,
                              minHeight: 30,
                            ),
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.delete_outline, size: 15),
                            color: tieneSuscripcion
                                ? FitNetTheme.textSecondary.withValues(alpha: 0.3)
                                : FitNetTheme.error.withValues(alpha: 0.7),
                            tooltip: tieneSuscripcion
                                ? 'No se puede eliminar (suscripción activa)'
                                : 'Eliminar ${c.nombre}',
                            onPressed: () => _mostrarDialogoEliminarCliente(
                              c,
                              tieneSuscripcion,
                            ),
                          ),
                          // Acciones financieras
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
                                Icons.card_membership_rounded,
                                size: 17,
                              ),
                              color: FitNetTheme.gold.withValues(alpha: 0.8),
                              tooltip: 'Cobrar suscripción',
                              onPressed: () =>
                                  _cargarParaSuscripcion(tarjeta.idTarjeta),
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
                      // ── Badge de suscripción ──
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: tieneSuscripcion
                              ? FitNetTheme.success.withValues(alpha: 0.08)
                              : FitNetTheme.textSecondary.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: tieneSuscripcion
                                ? FitNetTheme.success.withValues(alpha: 0.2)
                                : Colors.white.withValues(alpha: 0.04),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              tieneSuscripcion
                                  ? Icons.check_circle_outline
                                  : Icons.cancel_outlined,
                              size: 14,
                              color: tieneSuscripcion
                                  ? FitNetTheme.success
                                  : FitNetTheme.textSecondary.withValues(alpha: 0.5),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                tieneSuscripcion
                                    ? '$diasRestantes día${diasRestantes != 1 ? 's' : ''} restante${diasRestantes != 1 ? 's' : ''} '
                                      '(${parseTipoSuscripcion(item.suscripcionActiva!.tipoSuscripcion).etiqueta})'
                                    : 'Sin suscripción activa',
                                style: TextStyle(
                                  color: tieneSuscripcion
                                      ? FitNetTheme.success
                                      : FitNetTheme.textSecondary.withValues(alpha: 0.5),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
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
  bool _isSyncing = false;

  Widget _buildSyncHeaderButton() {
    return StreamBuilder<int>(
      stream: _providers.syncQueueRepo.watchContadorPendientes(),
      builder: (context, snapshot) {
        final pendientes = snapshot.data ?? 0;
        final hasPending = pendientes > 0;

        return IconButton(
          tooltip: _isSyncing
              ? 'Sincronizando...'
              : hasPending
                  ? '$pendientes pendientes de sincronizar'
                  : 'Sincronizado',
          icon: _isSyncing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: FitNetTheme.gold,
                  ),
                )
              : Icon(
                  hasPending
                      ? Icons.cloud_upload_rounded
                      : Icons.cloud_done_rounded,
                  color: _isSyncing
                      ? FitNetTheme.gold
                      : hasPending
                          ? FitNetTheme.gold
                          : FitNetTheme.success,
                ),
          onPressed: _isSyncing ? null : _syncToSupabase,
        );
      },
    );
  }

  // ── Historial de movimientos ──
  Widget _buildHistorialMovimientos() {
    return StreamBuilder<List<Movimiento>>(
      stream: _movimientosRepo.watchTodosLosMovimientos(),
      builder: (context, snapshot) {
        final movimientos = snapshot.data ?? [];

        return Container(
          decoration: FitNetTheme.premiumCard,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Título ──
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: FitNetTheme.gold.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.history_rounded,
                      color: FitNetTheme.gold,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Historial de Movimientos',
                          style: TextStyle(
                            color: FitNetTheme.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${movimientos.length} movimientos registrados',
                          style: const TextStyle(
                            color: FitNetTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(color: Colors.white.withValues(alpha: 0.06)),
              const SizedBox(height: 8),

              if (movimientos.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  alignment: Alignment.center,
                  child: Column(
                    children: [
                      Icon(
                        Icons.receipt_long_outlined,
                        color: FitNetTheme.textSecondary.withValues(alpha: 0.3),
                        size: 48,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Sin movimientos registrados',
                        style: TextStyle(
                          color: FitNetTheme.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...movimientos.map((mov) {
                  final isRecarga = mov.tipo == 'recarga';
                  final isPago = mov.tipo == 'pago';
                  final iconData = isRecarga
                      ? Icons.add_circle_outline
                      : isPago
                          ? Icons.remove_circle_outline
                          : Icons.swap_horiz_rounded;
                  final iconColor = isRecarga
                      ? FitNetTheme.success
                      : isPago
                          ? FitNetTheme.gold
                          : FitNetTheme.textSecondary;
                  final tipoLabel = isRecarga
                      ? 'Recarga'
                      : isPago
                          ? 'Pago de suscripción'
                          : mov.tipo[0].toUpperCase() + mov.tipo.substring(1);
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

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: iconColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(iconData, color: iconColor, size: 16),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tipoLabel,
                                style: const TextStyle(
                                  color: FitNetTheme.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'Tarjeta #$shortId · $fechaStr',
                                style: const TextStyle(
                                  color: FitNetTheme.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${isRecarga ? '+' : '-'}\$${mov.monto.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: isRecarga ? FitNetTheme.success : FitNetTheme.gold,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  /// Ejecuta la sincronización: push de cambios locales a Supabase.
  Future<void> _syncToSupabase() async {
    setState(() => _isSyncing = true);

    try {
      final syncService = _providers.syncService;

      // 1. Subir cambios locales pendientes.
      await syncService.pushPendingChanges();

      // 2. Descargar cambios remotos (opcional).
      await syncService.pullRemoteChanges();

      if (mounted) {
        _showSnackBar('Sincronización completada ✓', isSuccess: true);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error al sincronizar: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }
}
