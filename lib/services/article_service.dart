import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:policode/models/article_model.dart';
import 'package:policode/services/auth_service.dart';

class ArticleService {
  static final ArticleService _instance = ArticleService._internal();
  factory ArticleService() => _instance;
  ArticleService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  /// Obtener todos los artículos publicados
  Future<List<Article>> getPublishedArticles({
    int limit = 20,
    String? categoria,
    DocumentSnapshot? lastDocument,
  }) async {
    Query query = _db
        .collection('articles')
        .where('isPublished', isEqualTo: true)
        .orderBy('fechaCreacion', descending: true);

    if (categoria != null) {
      query = query.where('categoria', isEqualTo: categoria);
    }

    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    query = query.limit(limit);

    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => Article.fromFirestore(doc.data() as Map<String, dynamic>))
        .toList();
  }

  /// Obtener artículos destacados
  Future<List<Article>> getFeaturedArticles({int limit = 5}) async {
    final snapshot = await _db
        .collection('articles')
        .where('isPublished', isEqualTo: true)
        .where('isFeatured', isEqualTo: true)
        .orderBy('fechaCreacion', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs
        .map((doc) => Article.fromFirestore(doc.data() as Map<String, dynamic>))
        .toList();
  }

  /// Obtener artículo por ID
  Future<Article?> getArticleById(String articleId) async {
    final doc = await _db.collection('articles').doc(articleId).get();
    if (!doc.exists) return null;
    
    // Incrementar views
    await _incrementViews(articleId);
    
    return Article.fromFirestore(doc.data() as Map<String, dynamic>);
  }

  /// Buscar artículos por texto
  Future<List<Article>> searchArticles(String searchText) async {
    final snapshot = await _db
        .collection('articles')
        .where('isPublished', isEqualTo: true)
        .orderBy('fechaCreacion', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => Article.fromFirestore(doc.data() as Map<String, dynamic>))
        .where((article) => 
            article.titulo.toLowerCase().contains(searchText.toLowerCase()) ||
            article.contenido.toLowerCase().contains(searchText.toLowerCase()) ||
            article.tags.any((tag) => tag.toLowerCase().contains(searchText.toLowerCase())))
        .toList();
  }

  /// Incrementar views de un artículo
  Future<void> _incrementViews(String articleId) async {
    await _db.collection('articles').doc(articleId).update({
      'views': FieldValue.increment(1),
    });
  }

  /// Dar like a un artículo
  Future<void> likeArticle(String articleId) async {
    final userId = _authService.currentUser?.uid;
    if (userId == null) throw Exception('Usuario no autenticado');

    final userLikeDoc = _db
        .collection('articles')
        .doc(articleId)
        .collection('likes')
        .doc(userId);

    final userLike = await userLikeDoc.get();
    
    if (userLike.exists) {
      // Ya dio like, remover
      await userLikeDoc.delete();
      await _db.collection('articles').doc(articleId).update({
        'likes': FieldValue.increment(-1),
      });
    } else {
      // Dar like
      await userLikeDoc.set({
        'userId': userId,
        'timestamp': FieldValue.serverTimestamp(),
      });
      await _db.collection('articles').doc(articleId).update({
        'likes': FieldValue.increment(1),
      });
    }
  }

  /// Verificar si el usuario ya dio like
  Future<bool> hasUserLiked(String articleId) async {
    final userId = _authService.currentUser?.uid;
    if (userId == null) return false;

    final userLike = await _db
        .collection('articles')
        .doc(articleId)
        .collection('likes')
        .doc(userId)
        .get();

    return userLike.exists;
  }

  /// Suscribirse a un usuario
  Future<void> subscribeToUser(String targetUserId) async {
    final userId = _authService.currentUser?.uid;
    if (userId == null) throw Exception('Usuario no autenticado');
    if (userId == targetUserId) throw Exception('No puedes suscribirte a ti mismo');

    final subscriptionId = '${userId}_$targetUserId';
    
    await _db.collection('subscriptions').doc(subscriptionId).set({
      'id': subscriptionId,
      'userId': userId,
      'subscribedToUserId': targetUserId,
      'fechaSuscripcion': FieldValue.serverTimestamp(),
    });
  }

  /// Desuscribirse de un usuario
  Future<void> unsubscribeFromUser(String targetUserId) async {
    final userId = _authService.currentUser?.uid;
    if (userId == null) throw Exception('Usuario no autenticado');

    final subscriptionId = '${userId}_$targetUserId';
    await _db.collection('subscriptions').doc(subscriptionId).delete();
  }

  /// Verificar si está suscrito a un usuario
  Future<bool> isSubscribedToUser(String targetUserId) async {
    final userId = _authService.currentUser?.uid;
    if (userId == null) return false;

    final subscriptionId = '${userId}_$targetUserId';
    final doc = await _db.collection('subscriptions').doc(subscriptionId).get();
    return doc.exists;
  }

  /// Obtener suscriptores de un usuario
  Future<List<String>> getUserSubscribers(String targetUserId) async {
    final snapshot = await _db
        .collection('subscriptions')
        .where('subscribedToUserId', isEqualTo: targetUserId)
        .get();

    return snapshot.docs
        .map((doc) => doc.data()['userId'] as String)
        .toList();
  }

  /// Crear notificación para suscriptores
  Future<void> notifySubscribers(String authorId, String articleId, String articleTitle) async {
    final subscribers = await getUserSubscribers(authorId);
    
    final batch = _db.batch();
    
    for (final subscriberId in subscribers) {
      final notificationRef = _db.collection('notifications').doc();
      batch.set(notificationRef, {
        'id': notificationRef.id,
        'userId': subscriberId,
        'type': 'new_article',
        'authorId': authorId,
        'articleId': articleId,
        'title': 'Nuevo artículo publicado',
        'message': 'Se publicó: "$articleTitle"',
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
    
    await batch.commit();
  }
}