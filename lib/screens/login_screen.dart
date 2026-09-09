import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import '../models/models.dart';
import '../services/database_service.dart';
import '../widgets/theme_widgets.dart';
import 'cajero_dashboard.dart';
import 'admin_dashboard.dart';

/// Pantalla de inicio de sesión de Fit.Net.
///
/// Diseño split-screen:
/// - Panel izquierdo: Imagen de gimnasio a pantalla completa
/// - Panel derecho: Formulario de login con logo, campos y credenciales demo
///
/// La autenticación determina el enrutamiento basado en rol:
/// - ADMIN_GLOBAL → AdminDashboard
/// - CAJERO → CajeroDashboard
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _db = DatabaseService();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Simular latencia de red/BD
    await Future.delayed(const Duration(milliseconds: 800));

    // ═══════════════════════════════════════════════════════════
    // TODO: Reemplazar con consulta real a la BD global.
    // Ejemplo con MySQL:
    //   final conn = await MySQLConnection.createConnection(...);
    //   final result = await conn.execute(
    //     'SELECT * FROM usuarios WHERE username = :u AND password = :p',
    //     {'u': username, 'p': hashedPassword},
    //   );
    // ═══════════════════════════════════════════════════════════
    final usuario = _db.autenticar(
      _usernameController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (usuario == null) {
      setState(() => _errorMessage = 'Credenciales inválidas');
      HapticFeedback.heavyImpact();
      return;
    }

    HapticFeedback.mediumImpact();

    // Enrutar según el rol del usuario
    if (usuario.rol == RolUsuario.adminGlobal) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              AdminDashboard(usuario: usuario),
          transitionsBuilder: (_, anim, secondAnimation, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    } else {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              CajeroDashboard(usuario: usuario),
          transitionsBuilder: (_, anim, secondAnimation, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 800;

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            // PANEL IZQUIERDO – Imagen del gimnasio
            Expanded(
              flex: 5,
              child: _buildImagePanel(isMobile: false),
            ),
            // PANEL DERECHO – Formulario de login
            Expanded(
              flex: 4,
              child: Container(
                color: FitNetTheme.backgroundDark,
                child: _buildLoginPanel(isMobile: false),
              ),
            ),
          ],
        ),
      );
    } else {
      return Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            _buildImagePanel(isMobile: true),
            Center(
              child: _buildLoginPanel(isMobile: true),
            ),
          ],
        ),
      );
    }
  }

  /// Panel izquierdo (o fondo en móvil): imagen de gimnasio con overlay oscuro.
  Widget _buildImagePanel({required bool isMobile}) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Imagen de fondo
        Image.asset(
          'assets/images/gym_bg.jpg',
          fit: BoxFit.cover,
        ),
        if (isMobile)
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 3.0, sigmaY: 3.0),
            child: Container(color: Colors.transparent),
          ),
        // Overlay con gradiente para dar profundidad
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isMobile 
                  ? [
                      Colors.black.withValues(alpha: 0.6),
                      Colors.black.withValues(alpha: 0.4),
                      Colors.black.withValues(alpha: 0.7),
                    ]
                  : [
                      Colors.black.withValues(alpha: 0.3),
                      Colors.black.withValues(alpha: 0.1),
                      Colors.black.withValues(alpha: 0.4),
                    ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        // Borde dorado sutil en el borde derecho
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          child: Container(
            width: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  FitNetTheme.gold.withValues(alpha: 0.0),
                  FitNetTheme.gold.withValues(alpha: 0.3),
                  FitNetTheme.gold.withValues(alpha: 0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Panel derecho: formulario de login completo.
  Widget _buildLoginPanel({required bool isMobile}) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: MediaQuery.of(context).size.width < 450 ? 20 : 40,
              vertical: 24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ── Logo / Branding ──
                  _buildLogo(),
                  const SizedBox(height: 48),

                  // ── Formulario de login ──
                  _buildLoginForm(isMobile: isMobile),

                  const SizedBox(height: 28),

                  // ── Credenciales de demo ──
                  _buildCredentialsPanel(isMobile: isMobile),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        // Icono circular con glow dorado
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: FitNetTheme.goldGradient,
            boxShadow: [
              BoxShadow(
                color: FitNetTheme.gold.withValues(alpha: 0.25),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(
            Icons.fitness_center_rounded,
            color: FitNetTheme.backgroundDark,
            size: 32,
          ),
        ),
        const SizedBox(height: 18),
        // Texto FIT.NET con gradiente dorado
        ShaderMask(
          shaderCallback: (bounds) =>
              FitNetTheme.goldGradient.createShader(bounds),
          child: const Text(
            'FIT.NET',
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w900,
              letterSpacing: 6,
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Sistema de Gestión de Gimnasios',
          style: TextStyle(
            color: FitNetTheme.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w400,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginForm({required bool isMobile}) {
    Widget formContent = Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título
            const Text(
              'Iniciar Sesión',
              style: TextStyle(
                color: FitNetTheme.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Ingresa tus credenciales para continuar',
              style: TextStyle(
                color: FitNetTheme.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 28),

            // Campo: Usuario
            TextFormField(
              controller: _usernameController,
              style: const TextStyle(color: FitNetTheme.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Usuario',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Ingresa tu usuario' : null,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 18),

            // Campo: Contraseña
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              style: const TextStyle(color: FitNetTheme.textPrimary),
              decoration: InputDecoration(
                labelText: 'Contraseña',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: FitNetTheme.textSecondary,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Ingresa tu contraseña' : null,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _handleLogin(),
            ),
            const SizedBox(height: 10),

            // Mensaje de error
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: _errorMessage != null
                  ? Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: FitNetTheme.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: FitNetTheme.error.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline,
                                color: FitNetTheme.error, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              _errorMessage!,
                              style: const TextStyle(
                                  color: FitNetTheme.error, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),

            const SizedBox(height: 6),

            // Botón: Entrar
            GoldButton(
              label: 'Entrar',
              icon: Icons.arrow_forward_rounded,
              isLoading: _isLoading,
              onPressed: _handleLogin,
            ),
          ],
        ),
      );

    if (isMobile) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
                width: 1,
              ),
            ),
            padding: const EdgeInsets.all(28),
            child: formContent,
          ),
        ),
      );
    } else {
      return Container(
        decoration: FitNetTheme.goldAccentCard,
        padding: const EdgeInsets.all(28),
        child: formContent,
      );
    }
  }

  Widget _buildCredentialsPanel({required bool isMobile}) {
    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: FitNetTheme.gold.withValues(alpha: 0.7),
                size: 15,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: const Text(
                  'Credenciales de Demostración',
                  style: TextStyle(
                    color: FitNetTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildCredentialRow('Admin Global', 'admin / admin123'),
          _buildCredentialRow('Cajero Centro', 'cajero_centro / centro123'),
          _buildCredentialRow('Cajero Norte', 'cajero_norte / norte123'),
        ],
      );

    if (isMobile) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
            padding: const EdgeInsets.all(18),
            child: content,
          ),
        ),
      );
    } else {
      return Container(
        decoration: FitNetTheme.premiumCard,
        padding: const EdgeInsets.all(18),
        child: content,
      );
    }
  }

  Widget _buildCredentialRow(String role, String credentials) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: FitNetTheme.gold.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '$role: ',
            style: const TextStyle(
              color: FitNetTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          Expanded(
            child: Text(
              credentials,
              style: TextStyle(
                color: FitNetTheme.gold.withValues(alpha: 0.8),
                fontSize: 12,
                fontFamily: 'monospace',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
