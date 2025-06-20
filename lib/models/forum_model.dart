import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Tipos de archivos multimedia soportados
enum MediaType {
  image('image'),
  video('video'),
  document('document');

  const MediaType(this.value);
  final String value;

  static MediaType? fromString(String? value) {
    if (value == null) return null;
    return MediaType.values
        .where((type) => type.value == value)
        .firstOrNull;
  }
}

/// Modelo para archivos multimedia adjuntos
class MediaAttachment extends Equatable {
  final String id;
  final String url;
  final String fileName;
  final MediaType type;
  final int fileSize; // en bytes
  final String? thumbnailUrl; // para videos
  final double? aspectRatio; // para imágenes y videos

  const MediaAttachment({
    required this.id,
    required this.url,
    required this.fileName,
    required this.type,
    required this.fileSize,
    this.thumbnailUrl,
    this.aspectRatio,
  });

  /// Crear desde Firestore
  factory MediaAttachment.fromFirestore(Map<String, dynamic> data) {
    return MediaAttachment(
      id: data['id'] ?? '',
      url: data['url'] ?? '',
      fileName: data['fileName'] ?? '',
      type: MediaType.fromString(data['type']) ?? MediaType.document,
      fileSize: data['fileSize'] ?? 0,
      thumbnailUrl: data['thumbnailUrl'],
      aspectRatio: data['aspectRatio']?.toDouble(),
    );
  }

  /// Convertir a Map para Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'url': url,
      'fileName': fileName,
      'type': type.value,
      'fileSize': fileSize,
      'thumbnailUrl': thumbnailUrl,
      'aspectRatio': aspectRatio,
    };
  }

  @override
  List<Object?> get props => [
        id,
        url,
        fileName,
        type,
        fileSize,
        thumbnailUrl,
        aspectRatio,
      ];
}

/// Modelo para un post del foro
class ForumPost extends Equatable {
  final String id;
  final String titulo;
  final String contenido;
  final String autorId;
  final String autorNombre;
  final String? autorPhotoURL;
  final DateTime fechaCreacion;
  final DateTime fechaActualizacion;
  final List<String> tags;
  final int likes;
  final int respuestas;
  final bool isPinned;
  final bool isClosed;
  final bool isLocked;
  final String? categoria;
  final List<MediaAttachment> mediaAttachments;

  const ForumPost({
    required this.id,
    required this.titulo,
    required this.contenido,
    required this.autorId,
    required this.autorNombre,
    this.autorPhotoURL,
    required this.fechaCreacion,
    required this.fechaActualizacion,
    this.tags = const [],
    this.likes = 0,
    this.respuestas = 0,
    this.isPinned = false,
    this.isClosed = false,
    this.isLocked = false,
    this.categoria,
    this.mediaAttachments = const [],
  });

  /// Crear desde Firestore
  factory ForumPost.fromFirestore(Map<String, dynamic> data) {
    return ForumPost(
      id: data['id'] ?? '',
      titulo: data['titulo'] ?? '',
      contenido: data['contenido'] ?? '',
      autorId: data['autorId'] ?? '',
      autorNombre: data['autorNombre'] ?? '',
      autorPhotoURL: data['autorPhotoURL'],
      fechaCreacion: (data['fechaCreacion'] as Timestamp).toDate(),
      fechaActualizacion: (data['fechaActualizacion'] as Timestamp).toDate(),
      tags: List<String>.from(data['tags'] ?? []),
      likes: data['likes'] ?? 0,
      respuestas: data['respuestas'] ?? 0,
      isPinned: data['isPinned'] ?? false,
      isClosed: data['isClosed'] ?? false,
      isLocked: data['isLocked'] ?? false,
      categoria: data['categoria'],
      mediaAttachments: (data['mediaAttachments'] as List<dynamic>?)
              ?.map((item) => MediaAttachment.fromFirestore(item as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  /// Convertir a Map para Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'titulo': titulo,
      'contenido': contenido,
      'autorId': autorId,
      'autorNombre': autorNombre,
      'autorPhotoURL': autorPhotoURL,
      'fechaCreacion': Timestamp.fromDate(fechaCreacion),
      'fechaActualizacion': Timestamp.fromDate(fechaActualizacion),
      'tags': tags,
      'likes': likes,
      'respuestas': respuestas,
      'isPinned': isPinned,
      'isClosed': isClosed,
      'isLocked': isLocked,
      'categoria': categoria,
      'mediaAttachments': mediaAttachments.map((item) => item.toFirestore()).toList(),
    };
  }

  /// Crear copia con cambios
  ForumPost copyWith({
    String? id,
    String? titulo,
    String? contenido,
    String? autorId,
    String? autorNombre,
    String? autorPhotoURL,
    DateTime? fechaCreacion,
    DateTime? fechaActualizacion,
    List<String>? tags,
    int? likes,
    int? respuestas,
    bool? isPinned,
    bool? isClosed,
    bool? isLocked,
    String? categoria,
    List<MediaAttachment>? mediaAttachments,
  }) {
    return ForumPost(
      id: id ?? this.id,
      titulo: titulo ?? this.titulo,
      contenido: contenido ?? this.contenido,
      autorId: autorId ?? this.autorId,
      autorNombre: autorNombre ?? this.autorNombre,
      autorPhotoURL: autorPhotoURL ?? this.autorPhotoURL,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      fechaActualizacion: fechaActualizacion ?? this.fechaActualizacion,
      tags: tags ?? this.tags,
      likes: likes ?? this.likes,
      respuestas: respuestas ?? this.respuestas,
      isPinned: isPinned ?? this.isPinned,
      isClosed: isClosed ?? this.isClosed,
      isLocked: isLocked ?? this.isLocked,
      categoria: categoria ?? this.categoria,
      mediaAttachments: mediaAttachments ?? this.mediaAttachments,
    );
  }

  @override
  List<Object?> get props => [
        id,
        titulo,
        contenido,
        autorId,
        autorNombre,
        autorPhotoURL,
        fechaCreacion,
        fechaActualizacion,
        tags,
        likes,
        respuestas,
        isPinned,
        isClosed,
        isLocked,
        categoria,
        mediaAttachments,
      ];
}

/// Modelo para respuestas del foro
class ForumReply extends Equatable {
  final String id;
  final String postId;
  final String contenido;
  final String autorId;
  final String autorNombre;
  final String? autorPhotoURL;
  final DateTime fechaCreacion;
  final DateTime fechaActualizacion;
  final int likes;
  final String? replyToId; // Para respuestas anidadas
  final bool isDeleted;
  final List<MediaAttachment> mediaAttachments;
  final String? postTitulo; // Para mostrar contexto en "Mis posts"

  const ForumReply({
    required this.id,
    required this.postId,
    required this.contenido,
    required this.autorId,
    required this.autorNombre,
    this.autorPhotoURL,
    required this.fechaCreacion,
    required this.fechaActualizacion,
    this.likes = 0,
    this.replyToId,
    this.isDeleted = false,
    this.mediaAttachments = const [],
    this.postTitulo,
  });

  /// Crear desde Firestore
  factory ForumReply.fromFirestore(Map<String, dynamic> data, String docId) {
    return ForumReply(
      id: docId,
      postId: data['postId'] ?? '',
      contenido: data['contenido'] ?? '',
      autorId: data['autorId'] ?? '',
      autorNombre: data['autorNombre'] ?? '',
      autorPhotoURL: data['autorPhotoURL'],
      fechaCreacion: (data['fechaCreacion'] as Timestamp).toDate(),
      fechaActualizacion: (data['fechaActualizacion'] as Timestamp).toDate(),
      likes: data['likes'] ?? 0,
      replyToId: data['replyToId'],
      isDeleted: data['isDeleted'] ?? false,
      mediaAttachments: (data['mediaAttachments'] as List<dynamic>?)
              ?.map((item) => MediaAttachment.fromFirestore(item as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  /// Convertir a Map para Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'postId': postId,
      'contenido': contenido,
      'autorId': autorId,
      'autorNombre': autorNombre,
      'autorPhotoURL': autorPhotoURL,
      'fechaCreacion': Timestamp.fromDate(fechaCreacion),
      'fechaActualizacion': Timestamp.fromDate(fechaActualizacion),
      'likes': likes,
      'replyToId': replyToId,
      'isDeleted': isDeleted,
      'mediaAttachments': mediaAttachments.map((item) => item.toFirestore()).toList(),
    };
  }

  /// Crear copia con cambios
  ForumReply copyWith({
    String? id,
    String? postId,
    String? contenido,
    String? autorId,
    String? autorNombre,
    String? autorPhotoURL,
    DateTime? fechaCreacion,
    DateTime? fechaActualizacion,
    int? likes,
    String? replyToId,
    bool? isDeleted,
    List<MediaAttachment>? mediaAttachments,
    String? postTitulo,
  }) {
    return ForumReply(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      contenido: contenido ?? this.contenido,
      autorId: autorId ?? this.autorId,
      autorNombre: autorNombre ?? this.autorNombre,
      autorPhotoURL: autorPhotoURL ?? this.autorPhotoURL,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      fechaActualizacion: fechaActualizacion ?? this.fechaActualizacion,
      likes: likes ?? this.likes,
      replyToId: replyToId ?? this.replyToId,
      isDeleted: isDeleted ?? this.isDeleted,
      mediaAttachments: mediaAttachments ?? this.mediaAttachments,
      postTitulo: postTitulo ?? this.postTitulo,
    );
  }

  @override
  List<Object?> get props => [
        id,
        postId,
        contenido,
        autorId,
        autorNombre,
        autorPhotoURL,
        fechaCreacion,
        fechaActualizacion,
        likes,
        replyToId,
        isDeleted,
        mediaAttachments,
        postTitulo,
      ];
}

/// Categorías predefinidas del foro
enum ForumCategory {
  general('General', 'Discusiones generales'),
  reglamento('Reglamento', 'Preguntas sobre el reglamento'),
  academico('Académico', 'Temas académicos'),
  dudas('Dudas', 'Preguntas y respuestas'),
  anuncios('Anuncios', 'Anuncios oficiales');

  const ForumCategory(this.nombre, this.descripcion);

  final String nombre;
  final String descripcion;

  static ForumCategory? fromString(String? value) {
    if (value == null) return null;
    return ForumCategory.values
        .where((category) => category.nombre == value)
        .firstOrNull;
  }
}