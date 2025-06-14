import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Modelo para un artículo
class Article extends Equatable {
  final String id;
  final String titulo;
  final String contenido;
  final String resumen; 
  final String autorId;
  final String autorNombre;
  final DateTime fechaCreacion;
  final DateTime fechaActualizacion;
  final List<String> tags;
  final String categoria;
  final String? imagenUrl;
  final int views;
  final int likes;
  final bool isPublished;
  final bool isFeatured;

  const Article({
    required this.id,
    required this.titulo,
    required this.contenido,
    required this.resumen,
    required this.autorId,
    required this.autorNombre,
    required this.fechaCreacion,
    required this.fechaActualizacion,
    this.tags = const [],
    required this.categoria,
    this.imagenUrl,
    this.views = 0,
    this.likes = 0,
    this.isPublished = true,
    this.isFeatured = false,
  });

  factory Article.fromFirestore(Map<String, dynamic> data) {
    return Article(
      id: data['id'] ?? '',
      titulo: data['titulo'] ?? '',
      contenido: data['contenido'] ?? '',
      resumen: data['resumen'] ?? '',
      autorId: data['autorId'] ?? '',
      autorNombre: data['autorNombre'] ?? '',
      fechaCreacion: (data['fechaCreacion'] as Timestamp).toDate(),
      fechaActualizacion: (data['fechaActualizacion'] as Timestamp).toDate(),
      tags: List<String>.from(data['tags'] ?? []),
      categoria: data['categoria'] ?? '',
      imagenUrl: data['imagenUrl'],
      views: data['views'] ?? 0,
      likes: data['likes'] ?? 0,
      isPublished: data['isPublished'] ?? true,
      isFeatured: data['isFeatured'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'titulo': titulo,
      'contenido': contenido,
      'resumen': resumen,
      'autorId': autorId,
      'autorNombre': autorNombre,
      'fechaCreacion': Timestamp.fromDate(fechaCreacion),
      'fechaActualizacion': Timestamp.fromDate(fechaActualizacion),
      'tags': tags,
      'categoria': categoria,
      'imagenUrl': imagenUrl,
      'views': views,
      'likes': likes,
      'isPublished': isPublished,
      'isFeatured': isFeatured,
    };
  }

  Article copyWith({
    String? id,
    String? titulo,
    String? contenido,
    String? resumen,
    String? autorId,
    String? autorNombre,
    DateTime? fechaCreacion,
    DateTime? fechaActualizacion,
    List<String>? tags,
    String? categoria,
    String? imagenUrl,
    int? views,
    int? likes,
    bool? isPublished,
    bool? isFeatured,
  }) {
    return Article(
      id: id ?? this.id,
      titulo: titulo ?? this.titulo,
      contenido: contenido ?? this.contenido,
      resumen: resumen ?? this.resumen,
      autorId: autorId ?? this.autorId,
      autorNombre: autorNombre ?? this.autorNombre,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      fechaActualizacion: fechaActualizacion ?? this.fechaActualizacion,
      tags: tags ?? this.tags,
      categoria: categoria ?? this.categoria,
      imagenUrl: imagenUrl ?? this.imagenUrl,
      views: views ?? this.views,
      likes: likes ?? this.likes,
      isPublished: isPublished ?? this.isPublished,
      isFeatured: isFeatured ?? this.isFeatured,
    );
  }

  @override
  List<Object?> get props => [
        id,
        titulo,
        contenido,
        resumen,
        autorId,
        autorNombre,
        fechaCreacion,
        fechaActualizacion,
        tags,
        categoria,
        imagenUrl,
        views,
        likes,
        isPublished,
        isFeatured,
      ];
}

/// Modelo para suscripciones de usuario
class UserSubscription extends Equatable {
  final String id;
  final String userId;
  final String subscribedToUserId;
  final DateTime fechaSuscripcion;

  const UserSubscription({
    required this.id,
    required this.userId,
    required this.subscribedToUserId,
    required this.fechaSuscripcion,
  });

  factory UserSubscription.fromFirestore(Map<String, dynamic> data) {
    return UserSubscription(
      id: data['id'] ?? '',
      userId: data['userId'] ?? '',
      subscribedToUserId: data['subscribedToUserId'] ?? '',
      fechaSuscripcion: (data['fechaSuscripcion'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'userId': userId,
      'subscribedToUserId': subscribedToUserId,
      'fechaSuscripcion': Timestamp.fromDate(fechaSuscripcion),
    };
  }

  @override
  List<Object?> get props => [id, userId, subscribedToUserId, fechaSuscripcion];
}

/// Categorías de artículos
enum ArticleCategory {
  reglamento('Reglamento', 'Artículos sobre el reglamento estudiantil'),
  academico('Académico', 'Contenido académico general'),
  normativas('Normativas', 'Normas y procedimientos'),
  guias('Guías', 'Guías y tutoriales'),
  noticias('Noticias', 'Noticias y anuncios');

  const ArticleCategory(this.nombre, this.descripcion);

  final String nombre;
  final String descripcion;

  static ArticleCategory? fromString(String? value) {
    if (value == null) return null;
    return ArticleCategory.values
        .where((category) => category.nombre == value)
        .firstOrNull;
  }
}