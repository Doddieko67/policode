import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:policode/services/auth_service.dart';
import 'package:policode/services/media_service.dart';
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
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  
  // Estado
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  String? _successMessage;
  File? _selectedImage;
  String? _currentPhotoUrl;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
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
        _nameController.text = user.nombre ?? '';
        _usernameController.text = user.username ?? '';
        _emailController.text = user.email;
        _currentPhotoUrl = user.configuraciones?['photoURL'];
      }
    } catch (e) {
      _setError('Error cargando datos del usuario: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      String? photoURL = _currentPhotoUrl;
      
      // Subir nueva imagen si se seleccionó
      if (_selectedImage != null) {
        final user = _authService.currentUser;
        if (user != null) {
          photoURL = await _mediaService.uploadProfilePhoto(
            _selectedImage!,
            user.uid,
          );
        }
      }
      
      final result = await _authService.updateProfile(
        nombre: _nameController.text.trim(),
        username: _usernameController.text.trim(),
        configuraciones: {
          'photoURL': photoURL,
        },
      );
      
      if (!result.success) {
        throw Exception(result.error);
      }
      
      setState(() {
        _currentPhotoUrl = photoURL;
        _selectedImage = null;
      });
      
      _setSuccess('Perfil actualizado correctamente');
    } catch (e) {
      _setError('Error actualizando perfil: $e');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      _setError('Error seleccionando imagen: $e');
    }
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
          Stack(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: theme.primaryColor,
                  shape: BoxShape.circle,
                  image: _selectedImage != null
                      ? DecorationImage(
                          image: FileImage(_selectedImage!),
                          fit: BoxFit.cover,
                        )
                      : _currentPhotoUrl != null
                          ? DecorationImage(
                              image: NetworkImage(_currentPhotoUrl!),
                              fit: BoxFit.cover,
                            )
                          : null,
                ),
                child: (_selectedImage == null && _currentPhotoUrl == null)
                    ? Center(
                        child: Text(
                          user?.iniciales ?? 'U',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: theme.primaryColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.edit,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            user?.nombre ?? 'Usuario',
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
        CustomInput(
          controller: _nameController,
          label: 'Nombre completo',
          prefixIcon: Icons.person_outline,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'El nombre es requerido';
            }
            if (value.trim().length < 2) {
              return 'El nombre debe tener al menos 2 caracteres';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        CustomInput(
          controller: _usernameController,
          label: 'Nombre de usuario',
          prefixIcon: Icons.alternate_email,
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
            return null;
          },
          hint: 'usuario123',
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
}