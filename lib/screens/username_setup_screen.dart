import 'package:flutter/material.dart';
import 'package:policode/services/auth_service.dart';
import 'package:policode/widgets/custom_button.dart';
import 'package:policode/widgets/custom_input.dart';
import 'package:policode/widgets/loading_widgets.dart';

/// Pantalla para configurar el nombre de usuario inicial
class UsernameSetupScreen extends StatefulWidget {
  const UsernameSetupScreen({super.key});

  @override
  State<UsernameSetupScreen> createState() => _UsernameSetupScreenState();
}

class _UsernameSetupScreenState extends State<UsernameSetupScreen> {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  
  bool _isLoading = false;
  bool _isCheckingName = false;
  String? _nameError;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _suggestUsername();
  }

  void _suggestUsername() {
    final user = _authService.currentUser;
    if (user != null) {
      final emailUsername = user.email.split('@').first;
      _usernameController.text = emailUsername;
      _checkNameAvailability(emailUsername);
    }
  }

  Future<void> _checkNameAvailability(String username) async {
    if (username.trim().isEmpty) {
      setState(() {
        _nameError = null;
        _isCheckingName = false;
      });
      return;
    }

    setState(() {
      _isCheckingName = true;
      _nameError = null;
    });

    try {
      final isAvailable = await _authService.isUsernameAvailable(username.trim());
      if (mounted) {
        setState(() {
          _nameError = isAvailable ? null : 'Este nombre de usuario ya está en uso';
          _isCheckingName = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _nameError = 'Error verificando disponibilidad';
          _isCheckingName = false;
        });
      }
    }
  }

  Future<void> _saveUsername() async {
    if (!_formKey.currentState!.validate()) return;

    if (_nameError != null || _isCheckingName) {
      setState(() {
        _errorMessage = _nameError ?? 'Verificando disponibilidad del nombre...';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _authService.updateProfile(
        username: _usernameController.text.trim(),
      );

      if (!result.success) {
        throw Exception(result.error);
      }

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error configurando nombre de usuario: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = _authService.currentUser;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 24.0,
            right: 24.0,
            top: 24.0,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24.0,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 40),
                
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.person_add_outlined,
                        size: 48,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '¡Bienvenido a PoliCode!',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Para completar tu perfil, necesitas elegir un nombre de usuario único.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // User info
                if (user != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.outline.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: theme.colorScheme.primary,
                          child: Text(
                            user.iniciales,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.userName,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                user.email,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Username input
                Text(
                  'Nombre de Usuario',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Este será tu identificador único en PoliCode. Otros usuarios te conocerán por este nombre.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),

                CustomInput(
                  controller: _usernameController,
                  label: 'Nombre de usuario',
                  prefixIcon: Icons.alternate_email,
                  hint: 'usuario123',
                  onChanged: (value) {
                    // Debounce para evitar muchas consultas
                    Future.delayed(const Duration(milliseconds: 500), () {
                      if (_usernameController.text == value) {
                        _checkNameAvailability(value);
                      }
                    });
                  },
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'El nombre de usuario es requerido';
                    }
                    if (value.trim().length < 3) {
                      return 'El nombre de usuario debe tener al menos 3 caracteres';
                    }
                    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value.trim())) {
                      return 'Solo se permiten letras, números y guiones bajos';
                    }
                    if (_nameError != null) {
                      return _nameError;
                    }
                    return null;
                  },
                  suffixWidget: _isCheckingName
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : _nameError != null
                          ? const Icon(Icons.error_outline, color: Colors.red)
                          : _usernameController.text.trim().isNotEmpty && _nameError == null
                              ? const Icon(Icons.check_circle_outline, color: Colors.green)
                              : null,
                ),

                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: theme.colorScheme.onErrorContainer),
                    ),
                  ),
                ],

                const SizedBox(height: 32),

                // Continue button
                SizedBox(
                  width: double.infinity,
                  child: CustomButton(
                    text: 'Continuar',
                    onPressed: _isLoading ? null : _saveUsername,
                    isLoading: _isLoading,
                    icon: _isLoading ? null : Icons.arrow_forward,
                  ),
                ),

                const SizedBox(height: 16),

                Text(
                  'Podrás cambiar tu nombre de usuario más tarde en la configuración de tu perfil.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}