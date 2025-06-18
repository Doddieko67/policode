import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:policode/services/auth_service.dart';
import 'package:policode/services/media_service.dart';
import 'package:policode/services/push_notification_service.dart';
import 'package:policode/widgets/custom_button.dart';
import 'package:policode/widgets/custom_input.dart';
import 'package:policode/widgets/loading_widgets.dart';

/// Pantalla de configuración de perfil del usuario
class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final AuthService _authService = AuthService();
  final MediaService _mediaService = MediaService();
  final PushNotificationService _pushService = PushNotificationService();
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  
  // Estado
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isCheckingName = false;
  String? _errorMessage;
  String? _successMessage;
  String? _nameError;
  String? _selectedAvatar;
  String? _originalName;

  // Lista de avatares disponibles
  final List<String> _availableAvatars = [
    'assets/images/perfil/bird.jpg',
    'assets/images/perfil/burro.jpg',
    'assets/images/perfil/cabra.jpg',
    'assets/images/perfil/dog.jpg',
    'assets/images/perfil/foca.jpg',
    'assets/images/perfil/morsa.jpg',
    'assets/images/perfil/pezHembra.jpg',
    'assets/images/perfil/pezMacho.jpg',
  ];

  /// Generar un avatar aleatorio
  String _getRandomAvatar() {
    final random = Random();
    return _availableAvatars[random.nextInt(_availableAvatars.length)];
  }

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = _authService.currentUser;
      if (user != null) {
        _originalName = user.username ?? '';
        _usernameController.text = _originalName ?? '';
        _emailController.text = user.email;
        _selectedAvatar = user.configuraciones?['selectedAvatar'];
        
        // Si el usuario no tiene avatar, asignar uno aleatorio
        if (_selectedAvatar == null) {
          _selectedAvatar = _getRandomAvatar();
          // Guardar el avatar automáticamente
          _autoSaveAvatar();
        }
      }
    } catch (e) {
      _setError('Error cargando datos del usuario: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _autoSaveAvatar() async {
    try {
      await _authService.updateProfile(
        configuraciones: {
          'selectedAvatar': _selectedAvatar,
        },
      );
    } catch (e) {
      print('Error guardando avatar automático: $e');
      // No mostrar error al usuario, es un proceso automático
    }
  }

  Future<void> _checkNameAvailability(String name) async {
    if (name.trim().isEmpty || name.trim() == _originalName) {
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
      final isAvailable = await _authService.isUsernameAvailable(name.trim());
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

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    // Verificar si hay error de nombre o si se está verificando
    if (_nameError != null || _isCheckingName) {
      _setError(_nameError ?? 'Verificando disponibilidad del nombre...');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final result = await _authService.updateProfile(
        username: _usernameController.text.trim(),
        configuraciones: {
          'selectedAvatar': _selectedAvatar,
        },
      );
      
      if (!result.success) {
        throw Exception(result.error);
      }
      
      _setSuccess('Perfil actualizado correctamente');
    } catch (e) {
      _setError('Error actualizando perfil: $e');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }


  void _showAvatarSelector() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Seleccionar Avatar'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GridView.builder(
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 1,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _availableAvatars.length,
                itemBuilder: (context, index) {
                  final avatar = _availableAvatars[index];
                  final isSelected = _selectedAvatar == avatar;
                  
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedAvatar = avatar;
                      });
                      Navigator.pop(context);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade300,
                          width: isSelected ? 3 : 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.asset(
                          avatar,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  );
                },
              ),
              if (_selectedAvatar != null) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _selectedAvatar = null;
                      });
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.person_outline, color: Colors.red),
                    label: const Text('Usar iniciales', style: TextStyle(color: Colors.red)),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }


  Future<void> _resetPassword() async {
    final user = _authService.currentUser;
    if (user == null) return;

    final confirmed = await _showConfirmationDialog(
      title: 'Cambiar Contraseña',
      content: 'Se enviará un email a ${user.email} con instrucciones para cambiar tu contraseña.',
      confirmText: 'Enviar Email',
    );

    if (confirmed) {
      setState(() {
        _isSaving = true;
        _errorMessage = null;
        _successMessage = null;
      });

      try {
        final result = await _authService.resetPassword(user.email);
        if (result.success) {
          _setSuccess('Email enviado. Revisa tu bandeja de entrada.');
        } else {
          throw Exception(result.error);
        }
      } catch (e) {
        _setError('Error enviando email: $e');
      } finally {
        if (mounted) {
          setState(() => _isSaving = false);
        }
      }
    }
  }

  Future<void> _signOut() async {
    final confirmed = await _showConfirmationDialog(
      title: 'Cerrar Sesión',
      content: '¿Estás seguro de que quieres cerrar sesión?',
      confirmText: 'Cerrar Sesión',
      isDestructive: true,
    );

    if (confirmed) {
      try {
        await _authService.signOut();
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(context, '/auth', (route) => false);
        }
      } catch (e) {
        _setError('Error cerrando sesión: $e');
      }
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await _showConfirmationDialog(
      title: 'Eliminar Cuenta',
      content: '¿Estás seguro de que quieres eliminar tu cuenta? Esta acción no se puede deshacer.',
      confirmText: 'Eliminar Cuenta',
      isDestructive: true,
    );

    if (confirmed) {
      setState(() {
        _isSaving = true;
        _errorMessage = null;
      });

      try {
        final result = await _authService.deleteAccount();
        if (!result.success) {
          throw Exception(result.error);
        }
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(context, '/auth', (route) => false);
        }
      } catch (e) {
        _setError('Error eliminando cuenta: $e');
        setState(() => _isSaving = false);
      }
    }
  }

  Future<bool> _showConfirmationDialog({
    required String title,
    required String content,
    required String confirmText,
    bool isDestructive = false,
  }) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: isDestructive
                ? TextButton.styleFrom(foregroundColor: Colors.red)
                : null,
            child: Text(confirmText),
          ),
        ],
      ),
    ) ?? false;
  }

  void _setError(String message) {
    if (mounted) {
      setState(() {
        _errorMessage = message;
        _successMessage = null;
      });
    }
  }

  void _setSuccess(String message) {
    if (mounted) {
      setState(() {
        _successMessage = message;
        _errorMessage = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = _authService.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración de Perfil'),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: LoadingWidget())
          : _buildContent(theme, user),
    );
  }

  Widget _buildContent(ThemeData theme, user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileHeader(theme, user),
            const SizedBox(height: 32),
            _buildProfileForm(theme),
            const SizedBox(height: 24),
            _buildActions(theme),
            const SizedBox(height: 16),
            _buildDangerZone(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(ThemeData theme, user) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: _showAvatarSelector,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: theme.primaryColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
                image: _selectedAvatar != null
                    ? DecorationImage(
                        image: AssetImage(_selectedAvatar!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: _selectedAvatar == null
                  ? Stack(
                      children: [
                        Center(
                          child: Text(
                            user?.iniciales ?? 'U',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        // Overlay sutil para indicar que es tocable
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withOpacity(0.1),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.add_a_photo,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    )
                  : Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withOpacity(0.2),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.edit,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            user?.userName ?? 'Usuario',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            user?.email ?? '',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileForm(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Información Personal',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        // Campo de username editable con validación
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
                  : _usernameController.text.trim() != _originalName && _usernameController.text.trim().isNotEmpty
                      ? const Icon(Icons.check_circle_outline, color: Colors.green)
                      : null,
        ),
        const SizedBox(height: 16),
        CustomInput(
          controller: _emailController,
          label: 'Correo electrónico',
          prefixIcon: Icons.email_outlined,
          isEnabled: false,
          hint: 'No se puede modificar el email',
        ),
      ],
    );
  }

  Widget _buildActions(ThemeData theme) {
    return Column(
      children: [
        if (_errorMessage != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _errorMessage!,
              style: TextStyle(color: theme.colorScheme.onErrorContainer),
            ),
          ),
        if (_successMessage != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _successMessage!,
              style: const TextStyle(color: Colors.green),
            ),
          ),
        SizedBox(
          width: double.infinity,
          child: CustomButton(
            text: 'Guardar Cambios',
            onPressed: _isSaving ? null : _saveProfile,
            icon: _isSaving ? null : Icons.save_outlined,
            isLoading: _isSaving,
          ),
        ),
        const SizedBox(height: 12),
        if (!_authService.isGoogleUser) ...[
          SizedBox(
            width: double.infinity,
            child: CustomButton(
              text: 'Cambiar Contraseña',
              onPressed: _isSaving ? null : _resetPassword,
              type: ButtonType.secondary,
              icon: Icons.lock_outline,
            ),
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: CustomButton(
            text: 'Cerrar Sesión',
            onPressed: _isSaving ? null : _signOut,
            type: ButtonType.secondary,
            icon: Icons.logout,
          ),
        ),
      ],
    );
  }

  Widget _buildDangerZone(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.red.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_outlined,
                color: Colors.red,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Zona de Peligro',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Una vez que elimines tu cuenta, no hay vuelta atrás. Por favor, ten cuidado.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: CustomButton.danger(
              text: 'Eliminar Cuenta',
              onPressed: _isSaving ? null : _deleteAccount,
              icon: Icons.delete_forever_outlined,
            ),
          ),
        ],
      ),
    );
  }

  void _showFCMToken() {
    final token = _pushService.fcmToken;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Token FCM'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Token para notificaciones push:'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: SelectableText(
                token ?? 'Token no disponible',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Este token se usa para enviar notificaciones push a este dispositivo.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
          if (token != null)
            ElevatedButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: token));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Token copiado al portapapeles')),
                );
                Navigator.pop(context);
              },
              child: const Text('Copiar'),
            ),
        ],
      ),
    );
  }

}