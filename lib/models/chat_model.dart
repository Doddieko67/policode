import 'package:equatable/equatable.dart';

enum TipoMensaje {
  usuario, // Mensaje del usuario
  asistente, // Respuesta del asistente (Gemini)
  sistema, // Mensajes del sistema (bienvenida, errores)
}

enum EstadoMensaje {
  enviando, // Se está enviando
  enviado, // Enviado exitosamente
  error, // Error al enviar
  procesando, // Asistente está procesando (typing...)
}

class ChatMessage extends Equatable {
  final String id;
  final String texto;
  final TipoMensaje tipo;
  final EstadoMensaje estado;
  final DateTime timestamp;
  final Map<String, dynamic>?
  metadatos; // Para datos adicionales si es necesario
  final String? mensajeError;

  const ChatMessage({
    required this.id,
    required this.texto,
    required this.tipo,
    this.estado = EstadoMensaje.enviado,
    required this.timestamp,
    this.metadatos,
    this.mensajeError,
  });

  // Factory constructor para mensaje del usuario
  factory ChatMessage.usuario({
    required String texto,
    EstadoMensaje estado = EstadoMensaje.enviando,
  }) {
    return ChatMessage(
      id: _generarId(),
      texto: texto,
      tipo: TipoMensaje.usuario,
      estado: estado,
      timestamp: DateTime.now(),
    );
  }

  // Factory constructor para respuesta del asistente
  factory ChatMessage.asistente({
    required String texto,
    EstadoMensaje estado = EstadoMensaje.enviado,
    Map<String, dynamic>? metadatos,
  }) {
    return ChatMessage(
      id: _generarId(),
      texto: texto,
      tipo: TipoMensaje.asistente,
      estado: estado,
      timestamp: DateTime.now(),
      metadatos: metadatos,
    );
  }

  // Factory constructor para mensaje de bienvenida
  factory ChatMessage.bienvenida({String? nombreUsuario}) {
    final saludo = nombreUsuario != null ? 'Hola $nombreUsuario' : 'Hola';

    return ChatMessage(
      id: _generarId(),
      texto:
          '$saludo! Soy tu asistente para consultar el reglamento de PoliCode. ¿En qué puedo ayudarte?',
      tipo: TipoMensaje.sistema,
      estado: EstadoMensaje.enviado,
      timestamp: DateTime.now(),
    );
  }

  // Factory constructor para mensaje de error
  factory ChatMessage.error({
    required String mensajeError,
    String? textoOriginal,
  }) {
    return ChatMessage(
      id: _generarId(),
      texto: 'Lo siento, ocurrió un problema. ¿Podrías intentar de nuevo?',
      tipo: TipoMensaje.sistema,
      estado: EstadoMensaje.error,
      timestamp: DateTime.now(),
      mensajeError: mensajeError,
      metadatos: textoOriginal != null
          ? {'texto_original': textoOriginal}
          : null,
    );
  }

  // Factory constructor para mensaje "typing"
  factory ChatMessage.procesando() {
    return ChatMessage(
      id: _generarId(),
      texto: 'Escribiendo...',
      tipo: TipoMensaje.asistente,
      estado: EstadoMensaje.procesando,
      timestamp: DateTime.now(),
    );
  }

  // Factory constructor desde JSON (si se quiere persistir el historial)
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      texto: json['texto'] as String,
      tipo: TipoMensaje.values.firstWhere(
        (t) => t.name == json['tipo'],
        orElse: () => TipoMensaje.usuario,
      ),
      estado: EstadoMensaje.values.firstWhere(
        (e) => e.name == json['estado'],
        orElse: () => EstadoMensaje.enviado,
      ),
      timestamp: DateTime.parse(json['timestamp']),
      metadatos: json['metadatos'] as Map<String, dynamic>?,
      mensajeError: json['mensaje_error'] as String?,
    );
  }

  // Método para convertir a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'texto': texto,
      'tipo': tipo.name,
      'estado': estado.name,
      'timestamp': timestamp.toIso8601String(),
      'metadatos': metadatos,
      'mensaje_error': mensajeError,
    };
  }

  // CopyWith para crear copias modificadas
  ChatMessage copyWith({
    String? id,
    String? texto,
    TipoMensaje? tipo,
    EstadoMensaje? estado,
    DateTime? timestamp,
    Map<String, dynamic>? metadatos,
    String? mensajeError,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      texto: texto ?? this.texto,
      tipo: tipo ?? this.tipo,
      estado: estado ?? this.estado,
      timestamp: timestamp ?? this.timestamp,
      metadatos: metadatos ?? this.metadatos,
      mensajeError: mensajeError ?? this.mensajeError,
    );
  }

  // Getters útiles

  /// Verificar si es un mensaje del usuario
  bool get esDelUsuario => tipo == TipoMensaje.usuario;

  /// Verificar si es un mensaje del asistente
  bool get esDelAsistente => tipo == TipoMensaje.asistente;

  /// Verificar si es un mensaje del sistema
  bool get esDelSistema => tipo == TipoMensaje.sistema;

  /// Verificar si está en estado de error
  bool get tieneError => estado == EstadoMensaje.error || mensajeError != null;

  /// Verificar si está procesando
  bool get estaProcesando => estado == EstadoMensaje.procesando;

  /// Verificar si fue enviado exitosamente
  bool get fueEnviado => estado == EstadoMensaje.enviado;

  /// Obtener tiempo desde el envío
  Duration get tiempoDesdeEnvio => DateTime.now().difference(timestamp);

  /// Verificar si es un mensaje reciente (último minuto)
  bool get esReciente => tiempoDesdeEnvio.inMinutes < 1;

  // Métodos de actualización

  /// Actualizar estado del mensaje
  ChatMessage actualizarEstado(EstadoMensaje nuevoEstado) {
    return copyWith(estado: nuevoEstado);
  }

  /// Marcar como error
  ChatMessage marcarComoError(String error) {
    return copyWith(estado: EstadoMensaje.error, mensajeError: error);
  }

  // Método estático para generar ID único
  static String _generarId() {
    return DateTime.now().millisecondsSinceEpoch.toString() +
        (DateTime.now().microsecond % 1000).toString().padLeft(3, '0');
  }

  @override
  List<Object?> get props => [
    id,
    texto,
    tipo,
    estado,
    timestamp,
    metadatos,
    mensajeError,
  ];

  @override
  String toString() {
    return 'ChatMessage(id: $id, tipo: $tipo, estado: $estado)';
  }
}

// Extensión para trabajar con listas de mensajes
extension ChatMessageListExtension on List<ChatMessage> {
  /// Obtener solo mensajes del usuario
  List<ChatMessage> get mensajesUsuario =>
      where((m) => m.esDelUsuario).toList();

  /// Obtener solo mensajes del asistente
  List<ChatMessage> get mensajesAsistente =>
      where((m) => m.esDelAsistente).toList();

  /// Obtener solo mensajes del sistema
  List<ChatMessage> get mensajesSistema =>
      where((m) => m.esDelSistema).toList();

  /// Obtener último mensaje
  ChatMessage? get ultimo => isNotEmpty ? last : null;

  /// Obtener último mensaje del usuario
  ChatMessage? get ultimoDelUsuario =>
      mensajesUsuario.isNotEmpty ? mensajesUsuario.last : null;

  /// Obtener último mensaje del asistente
  ChatMessage? get ultimoDelAsistente =>
      mensajesAsistente.isNotEmpty ? mensajesAsistente.last : null;

  /// Filtrar mensajes por tipo
  List<ChatMessage> porTipo(TipoMensaje tipo) {
    return where((m) => m.tipo == tipo).toList();
  }

  /// Filtrar mensajes por estado
  List<ChatMessage> porEstado(EstadoMensaje estado) {
    return where((m) => m.estado == estado).toList();
  }

  /// Obtener mensajes de hoy
  List<ChatMessage> get deHoy {
    final hoy = DateTime.now();
    return where(
      (m) =>
          m.timestamp.year == hoy.year &&
          m.timestamp.month == hoy.month &&
          m.timestamp.day == hoy.day,
    ).toList();
  }

  /// Limpiar mensajes de procesando/typing
  List<ChatMessage> get sinMensajesProcesando {
    return where((m) => m.estado != EstadoMensaje.procesando).toList();
  }

  /// Estadísticas de la conversación
  Map<String, int> get estadisticas {
    return {
      'total_mensajes': length,
      'mensajes_usuario': mensajesUsuario.length,
      'mensajes_asistente': mensajesAsistente.length,
      'mensajes_sistema': mensajesSistema.length,
      'con_errores': where((m) => m.tieneError).length,
    };
  }
}
