import 'package:equatable/equatable.dart';

class Usuario extends Equatable {
  final String uid;
  final String email;
  final String? nombre;
  final DateTime fechaRegistro;
  final DateTime? ultimaConexion;
  final bool esActivo;
  final Map<String, dynamic>? configuraciones; // Para preferencias del usuario

  const Usuario({
    required this.uid,
    required this.email,
    this.nombre,
    required this.fechaRegistro,
    this.ultimaConexion,
    this.esActivo = true,
    this.configuraciones,
  });

  // Factory constructor para crear desde Firebase Auth User
  factory Usuario.fromFirebaseUser(
    String uid,
    String email, {
    String? displayName,
    DateTime? fechaRegistro,
  }) {
    return Usuario(
      uid: uid,
      email: email,
      nombre: displayName,
      fechaRegistro: fechaRegistro ?? DateTime.now(),
      ultimaConexion: DateTime.now(),
      configuraciones: _configuracionesPorDefecto,
    );
  }

  // Factory constructor para crear desde JSON (Firestore)
  factory Usuario.fromJson(Map<String, dynamic> json) {
    return Usuario(
      uid: json['uid'] as String,
      email: json['email'] as String,
      nombre: json['nombre'] as String?,
      fechaRegistro: DateTime.parse(json['fecha_registro']),
      ultimaConexion: json['ultima_conexion'] != null
          ? DateTime.parse(json['ultima_conexion'])
          : null,
      esActivo: json['es_activo'] ?? true,
      configuraciones: json['configuraciones'] as Map<String, dynamic>?,
    );
  }

  // Método para convertir a JSON (Firestore)
  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'nombre': nombre,
      'fecha_registro': fechaRegistro.toIso8601String(),
      'ultima_conexion': ultimaConexion?.toIso8601String(),
      'es_activo': esActivo,
      'configuraciones': configuraciones,
    };
  }

  // CopyWith para crear copias modificadas
  Usuario copyWith({
    String? uid,
    String? email,
    String? nombre,
    DateTime? fechaRegistro,
    DateTime? ultimaConexion,
    bool? esActivo,
    Map<String, dynamic>? configuraciones,
  }) {
    return Usuario(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      nombre: nombre ?? this.nombre,
      fechaRegistro: fechaRegistro ?? this.fechaRegistro,
      ultimaConexion: ultimaConexion ?? this.ultimaConexion,
      esActivo: esActivo ?? this.esActivo,
      configuraciones: configuraciones ?? this.configuraciones,
    );
  }

  // Getters útiles

  /// Nombre completo del usuario (o email como fallback)
  String get nombreCompleto {
    return nombre ?? email.split('@').first;
  }

  /// Iniciales del usuario para avatares
  String get iniciales {
    if (nombre != null && nombre!.length > 1) {
      return nombre!.substring(0, 2).toUpperCase();
    } else if (nombre != null) {
      return nombre![0].toUpperCase();
    } else {
      return email[0].toUpperCase();
    }
  }

  /// Verificar si el perfil está completo
  bool get perfilCompleto {
    return nombre != null && nombre!.trim().isNotEmpty;
  }

  /// Tiempo desde la última conexión
  Duration? get tiempoDesdeUltimaConexion {
    return ultimaConexion != null
        ? DateTime.now().difference(ultimaConexion!)
        : null;
  }

  /// Verificar si está activo recientemente (último mes)
  bool get activoRecientemente {
    final ultimaActividad = tiempoDesdeUltimaConexion;
    return ultimaActividad != null && ultimaActividad.inDays <= 30;
  }

  // Métodos para configuraciones

  /// Obtener una configuración específica
  T? getConfiguracion<T>(String key, [T? defaultValue]) {
    return configuraciones?[key] as T? ?? defaultValue;
  }

  /// Actualizar una configuración
  Usuario actualizarConfiguracion(String key, dynamic value) {
    final nuevasConfiguraciones = Map<String, dynamic>.from(
      configuraciones ?? {},
    );
    nuevasConfiguraciones[key] = value;
    return copyWith(configuraciones: nuevasConfiguraciones);
  }

  /// Actualizar última conexión
  Usuario actualizarUltimaConexion() {
    return copyWith(ultimaConexion: DateTime.now());
  }

  /// Configuraciones por defecto
  static const Map<String, dynamic> _configuracionesPorDefecto = {
    'notificaciones_activas': true,
    'tema_oscuro': false,
    'idioma': 'es',
    'sonidos_chat': true,
    'auto_scroll_chat': true,
    'mostrar_ayuda_inicial': true,
  };

  @override
  List<Object?> get props => [
    uid,
    email,
    nombre,
    fechaRegistro,
    ultimaConexion,
    esActivo,
    configuraciones,
  ];

  @override
  String toString() {
    return 'Usuario(uid: $uid, email: $email, nombre: $nombreCompleto)';
  }
}
