import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/usuario_model.dart';
import '../services/auth_service.dart';

/// Widget para mostrar avatar de usuario con foto de perfil o iniciales como fallback
class UserAvatar extends StatelessWidget {
  final String? selectedAvatar; // Asset local seleccionado por el usuario
  final String? photoURL; // URL remota (ej: Google Sign-In)
  final String? displayName;
  final String? email;
  final double radius;
  final Color? backgroundColor;
  final TextStyle? textStyle;

  const UserAvatar({
    super.key,
    this.selectedAvatar,
    this.photoURL,
    this.displayName,
    this.email,
    this.radius = 20,
    this.backgroundColor,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Calcular iniciales
    String initials = _getInitials();
    
    // Prioridad: 1) selectedAvatar (asset), 2) iniciales
    
    // Si hay avatar seleccionado (asset local), usarlo
    if (selectedAvatar != null && selectedAvatar!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: backgroundColor ?? theme.colorScheme.surface,
        backgroundImage: AssetImage(selectedAvatar!),
      );
    }
    
    // Fallback a iniciales
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? theme.colorScheme.secondaryContainer,
      child: Text(
        initials,
        style: textStyle ?? TextStyle(
          color: theme.colorScheme.onSecondaryContainer,
          fontSize: radius * 0.6,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _getInitials() {
    if (displayName != null && displayName!.trim().isNotEmpty) {
      final words = displayName!.trim().split(' ');
      if (words.length >= 2) {
        return '${words[0][0]}${words[1][0]}'.toUpperCase();
      } else if (words.isNotEmpty) {
        return words[0].length >= 2 
            ? words[0].substring(0, 2).toUpperCase()
            : words[0][0].toUpperCase();
      }
    }
    
    if (email != null && email!.isNotEmpty) {
      final emailPart = email!.split('@')[0];
      return emailPart.length >= 2 
          ? emailPart.substring(0, 2).toUpperCase()
          : emailPart[0].toUpperCase();
    }
    
    return 'U'; // Usuario por defecto
  }
}

/// Widget simplificado que usa un modelo Usuario completo
class UserAvatarFromModel extends StatelessWidget {
  final String userId;
  final String? selectedAvatar;
  final String? photoURL;
  final String? displayName;
  final String? email;
  final double radius;
  final Color? backgroundColor;

  const UserAvatarFromModel({
    super.key,
    required this.userId,
    this.selectedAvatar,
    this.photoURL,
    this.displayName,
    this.email,
    this.radius = 20,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return UserAvatar(
      selectedAvatar: selectedAvatar,
      photoURL: photoURL,
      displayName: displayName,
      email: email,
      radius: radius,
      backgroundColor: backgroundColor,
    );
  }
}

/// Widget que obtiene la información del usuario desde Firestore
class UserAvatarFromId extends StatefulWidget {
  final String userId;
  final double radius;
  final Color? backgroundColor;

  const UserAvatarFromId({
    super.key,
    required this.userId,
    this.radius = 20,
    this.backgroundColor,
  });

  @override
  State<UserAvatarFromId> createState() => _UserAvatarFromIdState();
}

class _UserAvatarFromIdState extends State<UserAvatarFromId> {
  final AuthService _authService = AuthService();
  Usuario? _usuario;
  bool _isLoading = true;

  // Cache estático para evitar consultas repetidas
  static final Map<String, Usuario?> _userCache = {};

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    // Si es el usuario actual, usar AuthService
    if (_authService.isSignedIn && _authService.currentUser?.uid == widget.userId) {
      setState(() {
        _usuario = _authService.currentUser;
        _isLoading = false;
      });
      return;
    }

    // Verificar cache
    if (_userCache.containsKey(widget.userId)) {
      setState(() {
        _usuario = _userCache[widget.userId];
        _isLoading = false;
      });
      return;
    }

    // Consultar Firestore para otros usuarios
    try {
      final doc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(widget.userId)
          .get();

      if (doc.exists && mounted) {
        final userData = doc.data() as Map<String, dynamic>;
        _usuario = Usuario.fromJson(userData);
        _userCache[widget.userId] = _usuario;
      }
    } catch (e) {
      // Error consultando, usar fallback
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return CircleAvatar(
        radius: widget.radius,
        backgroundColor: widget.backgroundColor ?? 
            Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.3),
        child: SizedBox(
          width: widget.radius * 0.6,
          height: widget.radius * 0.6,
          child: CircularProgressIndicator(
            strokeWidth: 1,
            color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
          ),
        ),
      );
    }

    return UserAvatar(
      selectedAvatar: _usuario?.configuraciones?['selectedAvatar'],
      photoURL: null,
      displayName: _usuario?.displayName ?? _usuario?.userName ?? widget.userId,
      email: _usuario?.email ?? widget.userId,
      radius: widget.radius,
      backgroundColor: widget.backgroundColor,
    );
  }

  // Método estático para limpiar cache
  static void clearCache() {
    _userCache.clear();
  }
}