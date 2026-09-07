import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';
import '../services/database_service.dart';
import '../widgets/theme_widgets.dart';
import 'cajero_dashboard.dart';
import 'admin_dashboard.dart';

/// Pantalla de inicio de sesión de Fit.Net.
///
/// Diseño minimalista con tema oscuro premium y acentos dorados.
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
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.15),
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
          pageBuilder: (context, animation, secondaryAnimation) => AdminDashboard(usuario: usuario),
          transitionsBuilder: (_, anim, secondAnimation, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    } else {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => CajeroDashboard(usuario: usuario),
          transitionsBuilder: (_, anim, secondAnimation, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: FitNetTheme.darkGradient),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: screenSize.width > 500 ? 440 : double.infinity,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // ── Logo / Branding ──
                      _buildLogo(),
                      const SizedBox(height: 48),

                      // ── Formulario de login ──
                      Container(
                        decoration: FitNetTheme.goldAccentCard,
                        padding: const EdgeInsets.all(32),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Iniciar Sesión',
                                style: TextStyle(
                                  color: FitNetTheme.textPrimary,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Ingresa tus credenciales para continuar',
                                style: TextStyle(
                                  color: FitNetTheme.textSecondary,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 32),

                              // Campo: Usuario
                              TextFormField(
                                controller: _usernameController,
                                style: const TextStyle(
                                  color: FitNetTheme.textPrimary,
                                ),
                                decoration: const InputDecoration(
                                  labelText: 'Usuario',
                                  prefixIcon: Icon(Icons.person_outline),
                                ),
                                validator: (v) => v == null || v.trim().isEmpty
                                    ? 'Ingresa tu usuario'
                                    : null,
                                textInputAction: TextInputAction.next,
                              ),
                              const SizedBox(height: 20),

                              // Campo: Contraseña
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                style: const TextStyle(
                                  color: FitNetTheme.textPrimary,
                                ),
                                decoration: InputDecoration(
                                  labelText: 'Contraseña',
                                  prefixIcon:
                                      const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: FitNetTheme.textSecondary,
                                    ),
                                    onPressed: () => setState(
                                      () =>
                                          _obscurePassword = !_obscurePassword,
                                    ),
                                  ),
                                ),
                                validator: (v) => v == null || v.isEmpty
                                    ? 'Ingresa tu contraseña'
                                    : null,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _handleLogin(),
                              ),
                              const SizedBox(height: 12),

                              // Mensaje de error
                              if (_errorMessage != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: FitNetTheme.error
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: FitNetTheme.error
                                            .withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.error_outline,
                                          color: FitNetTheme.error,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          _errorMessage!,
                                          style: const TextStyle(
                                            color: FitNetTheme.error,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                              const SizedBox(height: 8),

                              // Botón: Entrar
                              GoldButton(
                                label: 'Entrar',
                                icon: Icons.arrow_forward_rounded,
                                isLoading: _isLoading,
                                onPressed: _handleLogin,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // ── Credenciales de demo ──
                      Container(
                        decoration: FitNetTheme.premiumCard,
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: FitNetTheme.gold.withValues(alpha: 0.7),
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Credenciales de Demostración',
                                  style: TextStyle(
                                    color: FitNetTheme.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildCredentialRow(
                              'Admin Global',
                              'admin / admin123',
                            ),
                            _buildCredentialRow(
                              'Cajero Centro',
                              'cajero_centro / centro123',
                            ),
                            _buildCredentialRow(
                              'Cajero Norte',
                              'cajero_norte / norte123',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
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
        // Icono con glow dorado
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: FitNetTheme.goldGradient,
            boxShadow: FitNetTheme.goldGlow,
          ),
          child: const Icon(
            Icons.fitness_center_rounded,
            color: FitNetTheme.backgroundDark,
            size: 40,
          ),
        ),
        const SizedBox(height: 20),
        ShaderMask(
          shaderCallback: (bounds) =>
              FitNetTheme.goldGradient.createShader(bounds),
          child: const Text(
            'FIT.NET',
            style: TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w900,
              letterSpacing: 6,
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Sistema de Gestión de Gimnasios',
          style: TextStyle(
            color: FitNetTheme.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w400,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildCredentialRow(String role, String credentials) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
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
          Text(
            credentials,
            style: TextStyle(
              color: FitNetTheme.gold.withValues(alpha: 0.8),
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
