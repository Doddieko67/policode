import 'package:flutter/material.dart';
import 'package:policode/widgets/custom_button.dart';
import 'package:policode/widgets/custom_input.dart';
import '../services/auth_service.dart';

/// Pantalla de autenticación (Login y Registro)
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  late PageController _pageController;

  // Controllers para formularios
  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  final _registerEmailController = TextEditingController();
  final _registerPasswordController = TextEditingController();
  final _registerConfirmPasswordController = TextEditingController();
  final _registerNameController = TextEditingController();

  // Form keys
  final _loginFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();

  // Focus nodes
  final _loginEmailFocus = FocusNode();
  final _loginPasswordFocus = FocusNode();
  final _registerNameFocus = FocusNode();
  final _registerEmailFocus = FocusNode();
  final _registerPasswordFocus = FocusNode();
  final _registerConfirmPasswordFocus = FocusNode();

  // Estado
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _pageController = PageController();

    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {}); // Actualizar para AnimatedSwitcher
        _clearError();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pageController.dispose();
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _registerEmailController.dispose();
    _registerPasswordController.dispose();
    _registerConfirmPasswordController.dispose();
    _registerNameController.dispose();
    _loginEmailFocus.dispose();
    _loginPasswordFocus.dispose();
    _registerNameFocus.dispose();
    _registerEmailFocus.dispose();
    _registerPasswordFocus.dispose();
    _registerConfirmPasswordFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 24),

              // Header compacto
              _buildCompactHeader(theme),

              const SizedBox(height: 24),

              // Tab bar
              _buildTabBar(theme),

              const SizedBox(height: 24),

              // Google Sign-In
              _buildGoogleSignInSection(theme),

              // Divider
              _buildDivider(theme),

              const SizedBox(height: 16),

              // Formulario según tab activa
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _tabController.index == 0
                    ? _buildLoginForm(theme)
                    : _buildRegisterForm(theme),
              ),

              const SizedBox(height: 32), // Espacio adicional
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        children: [
          // Logo original tamaño completo
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.primaryColor,
                  theme.primaryColor.withOpacity(0.7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: theme.primaryColor.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Container(
              width: 75,
              height: 75,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const CircleAvatar(
                backgroundColor: Colors.white,
                radius: 18,
                backgroundImage: AssetImage('assets/images/logo.png'),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Título
          Text(
            'PoliCode',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),

          const SizedBox(height: 8),

          // Subtítulo
          Text(
            'Tu asistente del reglamento estudiantil',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: theme.primaryColor,
          borderRadius: BorderRadius.circular(12),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 16,
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(text: 'Iniciar Sesión'),
          Tab(text: 'Registrarse'),
        ],
      ),
    );
  }

  Widget _buildGoogleSignInSection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          // Google Sign-In Button
          Container(
            width: double.infinity,
            height: 56,
            child: OutlinedButton.icon(
              onPressed: (_isLoading || _isGoogleLoading)
                  ? null
                  : _handleGoogleSignIn,
              icon: _isGoogleLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          theme.primaryColor,
                        ),
                      ),
                    )
                  : Image.asset(
                      'assets/icons/google_logo.png', // Necesitarás agregar este asset
                      width: 20,
                      height: 20,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.login,
                        color: theme.primaryColor,
                        size: 20,
                      ),
                    ),
              label: Text(
                _isGoogleLoading
                    ? 'Iniciando sesión...'
                    : 'Continuar con Google',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: theme.colorScheme.outline.withOpacity(0.5),
                  width: 1.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                backgroundColor: theme.colorScheme.surface,
                foregroundColor: theme.colorScheme.onSurface,
                elevation: 0,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Demo button
          SizedBox(
            width: double.infinity,
            child: CustomButton.secondary(
              text: 'Probar sin registrarse',
              onPressed: _handleGuestLogin,
              isExpanded: true,
              icon: Icons.visibility,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Divider(color: theme.colorScheme.outline.withOpacity(0.3)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'o continúa con email',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Divider(color: theme.colorScheme.outline.withOpacity(0.3)),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm(ThemeData theme) {
    return Form(
      key: _loginFormKey,
      child: Column(
        key: const ValueKey('login'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '¡Bienvenido de vuelta!',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Ingresa tus credenciales para continuar',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),

          const SizedBox(height: 32),

          // Email
          CustomInput.email(
            controller: _loginEmailController,
            focusNode: _loginEmailFocus,
            onSubmitted: (_) => _loginPasswordFocus.requestFocus(),
            validator: _validateEmail,
          ),

          const SizedBox(height: 20),

          // Password
          CustomInput.password(
            controller: _loginPasswordController,
            focusNode: _loginPasswordFocus,
            onSubmitted: (_) => _handleLogin(),
            validator: _validatePassword,
          ),

          const SizedBox(height: 16),

          // Forgot password
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _showForgotPasswordDialog,
              child: Text(
                '¿Olvidaste tu contraseña?',
                style: TextStyle(
                  color: theme.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Error message
          if (_errorMessage != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: theme.colorScheme.error,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: theme.colorScheme.error,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Login button
          CustomButton.primary(
            text: 'Iniciar Sesión',
            onPressed: (_isLoading || _isGoogleLoading) ? null : _handleLogin,
            isLoading: _isLoading,
            isExpanded: true,
            size: ButtonSize.large,
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterForm(ThemeData theme) {
    return Form(
      key: _registerFormKey,
      child: Column(
        key: const ValueKey('register'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '¡Únete a PoliCode!',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Crea tu cuenta para guardar tus consultas',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),

          const SizedBox(height: 32),

          // Name
          CustomInput(
            label: 'Nombre completo',
            hint: 'Ingresa tu nombre',
            controller: _registerNameController,
            focusNode: _registerNameFocus,
            prefixIcon: Icons.person_outline,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => _registerEmailFocus.requestFocus(),
            validator: _validateName,
            isRequired: true,
          ),

          const SizedBox(height: 20),

          // Email
          CustomInput.email(
            controller: _registerEmailController,
            focusNode: _registerEmailFocus,
            onSubmitted: (_) => _registerPasswordFocus.requestFocus(),
            validator: _validateEmail,
          ),

          const SizedBox(height: 20),

          // Password
          CustomInput.password(
            controller: _registerPasswordController,
            focusNode: _registerPasswordFocus,
            onSubmitted: (_) => _registerConfirmPasswordFocus.requestFocus(),
            validator: _validateNewPassword,
          ),

          const SizedBox(height: 20),

          // Confirm Password
          CustomInput(
            label: 'Confirmar contraseña',
            hint: 'Confirma tu contraseña',
            type: InputType.password,
            controller: _registerConfirmPasswordController,
            focusNode: _registerConfirmPasswordFocus,
            prefixIcon: Icons.lock_outline,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _handleRegister(),
            validator: _validateConfirmPassword,
            isRequired: true,
          ),

          const SizedBox(height: 24),

          // Terms checkbox
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 16, color: theme.primaryColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Al registrarte, aceptas nuestros términos de servicio y política de privacidad.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Error message
          if (_errorMessage != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: theme.colorScheme.error,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: theme.colorScheme.error,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Register button
          CustomButton.primary(
            text: 'Crear Cuenta',
            onPressed: (_isLoading || _isGoogleLoading)
                ? null
                : _handleRegister,
            isLoading: _isLoading,
            isExpanded: true,
            size: ButtonSize.large,
          ),
        ],
      ),
    );
  }

  // Validation methods
  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'El email es requerido';
    }
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
      return 'Ingresa un email válido';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'La contraseña es requerida';
    }
    return null;
  }

  String? _validateNewPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'La contraseña es requerida';
    }
    if (value.length < 6) {
      return 'La contraseña debe tener al menos 6 caracteres';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Confirma tu contraseña';
    }
    if (value != _registerPasswordController.text) {
      return 'Las contraseñas no coinciden';
    }
    return null;
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'El nombre es requerido';
    }
    if (value.trim().length < 2) {
      return 'El nombre debe tener al menos 2 caracteres';
    }
    return null;
  }

  // Action methods
  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isGoogleLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _authService.signInWithGoogle();

      if (result.success) {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      } else {
        setState(() {
          _errorMessage = result.error;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error inesperado con Google Sign-In: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isGoogleLoading = false;
        });
      }
    }
  }

  Future<void> _handleLogin() async {
    if (!_loginFormKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _authService.signIn(
        email: _loginEmailController.text.trim(),
        password: _loginPasswordController.text,
      );

      if (result.success) {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      } else {
        setState(() {
          _errorMessage = result.error;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error inesperado: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleRegister() async {
    if (!_registerFormKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _authService.register(
        email: _registerEmailController.text.trim(),
        password: _registerPasswordController.text,
        nombre: _registerNameController.text.trim(),
      );

      if (result.success) {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      } else {
        setState(() {
          _errorMessage = result.error;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error inesperado: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _handleGuestLogin() {
    // Navegar directamente sin autenticación
    Navigator.pushReplacementNamed(context, '/home');
  }

  void _showForgotPasswordDialog() {
    final emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recuperar Contraseña'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Ingresa tu email y te enviaremos un enlace para restablecer tu contraseña.',
            ),
            const SizedBox(height: 16),
            CustomInput.email(
              controller: emailController,
              hint: 'tu@email.com',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          CustomButton.primary(
            text: 'Enviar',
            onPressed: () async {
              if (emailController.text.trim().isNotEmpty) {
                final result = await _authService.resetPassword(
                  emailController.text.trim(),
                );

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        result.success
                            ? 'Email enviado correctamente'
                            : result.error ?? 'Error enviando email',
                      ),
                      backgroundColor: result.success
                          ? Colors.green
                          : Colors.red,
                    ),
                  );
                }
              }
            },
            size: ButtonSize.small,
          ),
        ],
      ),
    );
  }

  void _clearError() {
    if (_errorMessage != null) {
      setState(() {
        _errorMessage = null;
      });
    }
  }
}
