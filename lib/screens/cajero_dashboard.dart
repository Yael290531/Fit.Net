import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/database_service.dart';
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
  final _db = DatabaseService();

  // Controladores para Registrar Cliente
  final _nombreClienteCtrl = TextEditingController();
  final _saldoInicialCtrl = TextEditingController();

  // Controladores para Recarga
  final _idRecargaCtrl = TextEditingController();
  final _montoRecargaCtrl = TextEditingController();

  // Controlador para Cobro de Acceso
  final _idAccesoCtrl = TextEditingController();

  String get _sucursal =>
      widget.usuario.sucursalAsignada ?? 'Sucursal Centro';

  int _selectedTab = 0;

  @override
  void dispose() {
    _nombreClienteCtrl.dispose();
    _saldoInicialCtrl.dispose();
    _idRecargaCtrl.dispose();
    _montoRecargaCtrl.dispose();
    _idAccesoCtrl.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = false, bool isSuccess = false}) {
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
  // TODO: INSERT INTO clientes_tarjeta (nombre, saldo) VALUES (?, ?)
  // en la BD LOCAL de la sucursal.
  // ═══════════════════════════════════════════════════════════
  void _registrarCliente() {
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

    final cliente = _db.registrarCliente(_sucursal, nombre, saldo);
    _nombreClienteCtrl.clear();
    _saldoInicialCtrl.clear();

    setState(() {});
    _showSnackBar(
      '✓ Cliente "${cliente.nombre}" registrado · Tarjeta #${cliente.idTarjeta}',
      isSuccess: true,
    );
  }

  // ═══════════════════════════════════════════════════════════
  // RECARGAR TARJETA
  // TODO: UPDATE clientes_tarjeta SET saldo = saldo + ? WHERE id_tarjeta = ?
  // + INSERT INTO movimientos_financieros (...)
  // en la BD LOCAL de la sucursal.
  // ═══════════════════════════════════════════════════════════
  void _recargarTarjeta() {
    final idText = _idRecargaCtrl.text.trim();
    final montoText = _montoRecargaCtrl.text.trim();

    if (idText.isEmpty || montoText.isEmpty) {
      _showSnackBar('Completa todos los campos', isError: true);
      return;
    }

    final id = int.tryParse(idText);
    final monto = double.tryParse(montoText);
    if (id == null || monto == null || monto <= 0) {
      _showSnackBar('Datos inválidos', isError: true);
      return;
    }

    final exito = _db.recargarTarjeta(_sucursal, id, monto);
    if (exito) {
      _idRecargaCtrl.clear();
      _montoRecargaCtrl.clear();
      setState(() {});
      _showSnackBar(
        '✓ Recarga de \$${monto.toStringAsFixed(2)} a tarjeta #$id exitosa',
        isSuccess: true,
      );
    } else {
      _showSnackBar('Tarjeta #$id no encontrada en $_sucursal', isError: true);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // COBRAR ACCESO
  // TODO: UPDATE clientes_tarjeta SET saldo = saldo - 80 WHERE id_tarjeta = ?
  // + INSERT INTO movimientos_financieros (tipo='cobroAcceso', ...)
  // en la BD LOCAL de la sucursal.
  // ═══════════════════════════════════════════════════════════
  void _cobrarAcceso() {
    final idText = _idAccesoCtrl.text.trim();
    if (idText.isEmpty) {
      _showSnackBar('Ingresa el ID de la tarjeta', isError: true);
      return;
    }

    final id = int.tryParse(idText);
    if (id == null) {
      _showSnackBar('ID inválido', isError: true);
      return;
    }

    final exito = _db.cobrarAcceso(_sucursal, id);
    if (exito) {
      _idAccesoCtrl.clear();
      setState(() {});
      _showSnackBar('✓ Acceso autorizado para tarjeta #$id', isSuccess: true);
    } else {
      final cliente = _db.buscarClientePorId(_sucursal, id);
      if (cliente == null) {
        _showSnackBar('Tarjeta #$id no encontrada', isError: true);
      } else {
        _showSnackBar(
          'Saldo insuficiente (\$${cliente.saldo.toStringAsFixed(2)})',
          isError: true,
        );
      }
    }
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

  @override
  Widget build(BuildContext context) {
    final clientes = _db.obtenerClientes(_sucursal);
    final movimientosHoy = _db.contarMovimientosHoy(_sucursal);
    final ingresosHoy = _db.obtenerIngresosHoy(_sucursal);
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
                  horizontal: isWide ? 40 : 20,
                  vertical: 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Métricas rápidas ──
                    _buildQuickMetrics(
                      clientes.length,
                      movimientosHoy,
                      ingresosHoy,
                      isWide,
                    ),
                    const SizedBox(height: 28),

                    // ── Tabs de operaciones ──
                    _buildTabBar(),
                    const SizedBox(height: 20),

                    // ── Contenido del tab seleccionado ──
                    if (isWide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 5,
                            child: _buildTabContent(),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            flex: 4,
                            child: _buildClientesList(clientes),
                          ),
                        ],
                      )
                    else ...[
                      _buildTabContent(),
                      const SizedBox(height: 24),
                      _buildClientesList(clientes),
                    ],
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
                  ),
                  Text(
                    'Cajero: ${widget.usuario.username} · Distribución Local',
                    style: const TextStyle(
                      color: FitNetTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
            const SizedBox(width: 12),
            IconButton(
              icon: const Icon(Icons.logout_rounded, color: FitNetTheme.textSecondary),
              tooltip: 'Cerrar Sesión',
              onPressed: _logout,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickMetrics(
      int totalClientes, int movimientos, double ingresos, bool isWide) {
    final metrics = [
      MetricIndicator(
        label: 'Clientes Registrados',
        value: '$totalClientes',
        icon: Icons.people_outline,
        subtitle: 'En esta sucursal',
      ),
      MetricIndicator(
        label: 'Movimientos Hoy',
        value: '$movimientos',
        icon: Icons.receipt_long_outlined,
        subtitle: 'Transacciones del día',
      ),
      MetricIndicator(
        label: 'Ingresos Hoy',
        value: '\$${ingresos.toStringAsFixed(2)}',
        icon: Icons.trending_up_rounded,
        valueColor: FitNetTheme.gold,
        subtitle: 'Cobros de acceso',
      ),
    ];

    if (isWide) {
      return Row(
        children: metrics
            .map((m) => Expanded(child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: m,
                )))
            .toList(),
      );
    }
    return Column(
      children: metrics.map((m) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: m,
          )).toList(),
    );
  }

  Widget _buildTabBar() {
    final tabs = [
      (Icons.person_add_outlined, 'Registrar Cliente'),
      (Icons.credit_card_outlined, 'Recargar Tarjeta'),
      (Icons.login_rounded, 'Cobrar Acceso'),
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
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? FitNetTheme.gold.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: isSelected
                      ? Border.all(
                          color: FitNetTheme.gold.withValues(alpha: 0.3))
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      size: 18,
                      color: isSelected
                          ? FitNetTheme.gold
                          : FitNetTheme.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: TextStyle(
                        color: isSelected
                            ? FitNetTheme.gold
                            : FitNetTheme.textSecondary,
                        fontSize: 13,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
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
            keyboardType: TextInputType.number,
            style: const TextStyle(color: FitNetTheme.textPrimary),
            decoration: const InputDecoration(
              labelText: 'ID de Tarjeta',
              prefixIcon: Icon(Icons.credit_card_outlined),
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
            keyboardType: TextInputType.number,
            style: const TextStyle(color: FitNetTheme.textPrimary),
            decoration: const InputDecoration(
              labelText: 'ID de Tarjeta del Cliente',
              prefixIcon: Icon(Icons.credit_card_outlined),
            ),
          ),
          const SizedBox(height: 24),
          GoldButton(
            label: 'Cobrar Acceso · \$80.00',
            icon: Icons.check_circle_outline,
            onPressed: _cobrarAcceso,
          ),
        ],
      ),
    );
  }

  // ── Lista de Clientes ──
  Widget _buildClientesList(List<ClienteTarjeta> clientes) {
    return PremiumCard(
      title: 'Clientes de $_sucursal',
      icon: Icons.people_outline,
      child: clientes.isEmpty
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
              children: clientes.map((c) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
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
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: FitNetTheme.gold.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.person_outline,
                          color: FitNetTheme.gold,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.nombre,
                              style: const TextStyle(
                                color: FitNetTheme.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Tarjeta #${c.idTarjeta}',
                              style: const TextStyle(
                                color: FitNetTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: c.saldo >= 80
                              ? FitNetTheme.success.withValues(alpha: 0.12)
                              : FitNetTheme.error.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '\$${c.saldo.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: c.saldo >= 80
                                ? FitNetTheme.success
                                : FitNetTheme.error,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
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
}
