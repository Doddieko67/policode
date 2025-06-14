import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:policode/models/forum_model.dart';

/// Servicio para manejar las operaciones del foro en Firebase
class ForumService {
  static final ForumService _instance = ForumService._internal();
  factory ForumService() => _instance;
  ForumService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Colección principal de posts del foro
  CollectionReference get _postsCollection => _db.collection('forum_posts');

  /// Colección de respuestas
  CollectionReference get _repliesCollection => _db.collection('forum_replies');

  // ===== OPERACIONES DE POSTS =====

  /// Obtener posts del foro con paginación
  Future<List<ForumPost>> getPosts({
    int limit = 20,
    DocumentSnapshot? startAfter,
    String? categoria,
    bool? isPinned,
  }) async {
    try {
      Query query = _postsCollection.orderBy('fechaCreacion', descending: true);

      if (categoria != null) {
        query = query.where('categoria', isEqualTo: categoria);
      }

      if (isPinned != null) {
        query = query.where('isPinned', isEqualTo: isPinned);
      }

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      query = query.limit(limit);

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => ForumPost.fromFirestore(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Error obteniendo posts del foro: $e');
    }
  }

  /// Obtener un post específico por ID
  Future<ForumPost?> getPost(String postId) async {
    try {
      final doc = await _postsCollection.doc(postId).get();
      if (doc.exists) {
        return ForumPost.fromFirestore(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      throw Exception('Error obteniendo post: $e');
    }
  }

  /// Crear un nuevo post
  Future<String> createPost(ForumPost post) async {
    try {
      final docRef = await _postsCollection.add(post.toFirestore());
      
      // Actualizar el post con su ID
      await docRef.update({'id': docRef.id});
      
      return docRef.id;
    } catch (e) {
      throw Exception('Error creando post: $e');
    }
  }

  /// Actualizar un post existente
  Future<void> updatePost(String postId, Map<String, dynamic> updates) async {
    try {
      updates['fechaActualizacion'] = Timestamp.now();
      await _postsCollection.doc(postId).update(updates);
    } catch (e) {
      throw Exception('Error actualizando post: $e');
    }
  }

  /// Actualizar un post completo
  Future<void> updateFullPost(ForumPost post) async {
    try {
      final updates = {
        'titulo': post.titulo,
        'contenido': post.contenido,
        'categoria': post.categoria,
        'tags': post.tags,
        'mediaAttachments': post.mediaAttachments.map((m) => m.toFirestore()).toList(),
        'fechaActualizacion': Timestamp.now(),
      };
      await _postsCollection.doc(post.id).update(updates);
    } catch (e) {
      throw Exception('Error actualizando post: $e');
    }
  }

  /// Eliminar un post
  Future<void> deletePost(String postId) async {
    try {
      // Eliminar también todas las respuestas del post
      await _deletePostReplies(postId);
      
      // Eliminar el post
      await _postsCollection.doc(postId).delete();
    } catch (e) {
      throw Exception('Error eliminando post: $e');
    }
  }

  /// Dar o quitar like a un post
  Future<void> togglePostLike(String postId, String userId) async {
    try {
      final likeDoc = await _db
          .collection('forum_likes')
          .where('postId', isEqualTo: postId)
          .where('userId', isEqualTo: userId)
          .get();

      if (likeDoc.docs.isEmpty) {
        // Agregar like
        await _db.collection('forum_likes').add({
          'postId': postId,
          'userId': userId,
          'timestamp': Timestamp.now(),
        });

        // Incrementar contador
        await _postsCollection.doc(postId).update({
          'likes': FieldValue.increment(1),
        });
      } else {
        // Quitar like
        await likeDoc.docs.first.reference.delete();

        // Decrementar contador
        await _postsCollection.doc(postId).update({
          'likes': FieldValue.increment(-1),
        });
      }
    } catch (e) {
      throw Exception('Error actualizando like: $e');
    }
  }

  /// Verificar si un usuario ha dado like a un post
  Future<bool> hasUserLikedPost(String postId, String userId) async {
    try {
      final likeDoc = await _db
          .collection('forum_likes')
          .where('postId', isEqualTo: postId)
          .where('userId', isEqualTo: userId)
          .get();

      return likeDoc.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // ===== OPERACIONES DE RESPUESTAS =====

  /// Obtener respuestas de un post
  Future<List<ForumReply>> getReplies(String postId) async {
    try {
      final snapshot = await _repliesCollection
          .where('postId', isEqualTo: postId)
          .where('isDeleted', isEqualTo: false)
          .orderBy('fechaCreacion', descending: false)
          .get();

      return snapshot.docs
          .map((doc) => ForumReply.fromFirestore(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Error obteniendo respuestas: $e');
    }
  }

  /// Crear una nueva respuesta
  Future<String> createReply(ForumReply reply) async {
    try {
      final docRef = await _repliesCollection.add(reply.toFirestore());
      
      // Actualizar la respuesta con su ID
      await docRef.update({'id': docRef.id});
      
      // Incrementar contador de respuestas en el post
      await _postsCollection.doc(reply.postId).update({
        'respuestas': FieldValue.increment(1),
        'fechaActualizacion': Timestamp.now(),
      });
      
      return docRef.id;
    } catch (e) {
      throw Exception('Error creando respuesta: $e');
    }
  }

  /// Actualizar una respuesta
  Future<void> updateReply(String replyId, Map<String, dynamic> updates) async {
    try {
      updates['fechaActualizacion'] = Timestamp.now();
      await _repliesCollection.doc(replyId).update(updates);
    } catch (e) {
      throw Exception('Error actualizando respuesta: $e');
    }
  }

  /// Eliminar una respuesta (marca como eliminada)
  Future<void> deleteReply(String replyId, String postId) async {
    try {
      await _repliesCollection.doc(replyId).update({
        'isDeleted': true,
        'contenido': '[Mensaje eliminado]',
        'fechaActualizacion': Timestamp.now(),
      });

      // Decrementar contador de respuestas en el post
      await _postsCollection.doc(postId).update({
        'respuestas': FieldValue.increment(-1),
        'fechaActualizacion': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('Error eliminando respuesta: $e');
    }
  }

  /// Dar o quitar like a una respuesta
  Future<void> toggleReplyLike(String replyId, String userId) async {
    try {
      final likeDoc = await _db
          .collection('forum_reply_likes')
          .where('replyId', isEqualTo: replyId)
          .where('userId', isEqualTo: userId)
          .get();

      if (likeDoc.docs.isEmpty) {
        // Agregar like
        await _db.collection('forum_reply_likes').add({
          'replyId': replyId,
          'userId': userId,
          'timestamp': Timestamp.now(),
        });

        // Incrementar contador
        await _repliesCollection.doc(replyId).update({
          'likes': FieldValue.increment(1),
        });
      } else {
        // Quitar like
        await likeDoc.docs.first.reference.delete();

        // Decrementar contador
        await _repliesCollection.doc(replyId).update({
          'likes': FieldValue.increment(-1),
        });
      }
    } catch (e) {
      throw Exception('Error actualizando like de respuesta: $e');
    }
  }

  /// Verificar si un usuario ha dado like a una respuesta
  Future<bool> hasUserLikedReply(String replyId, String userId) async {
    try {
      final likeDoc = await _db
          .collection('forum_reply_likes')
          .where('replyId', isEqualTo: replyId)
          .where('userId', isEqualTo: userId)
          .get();

      return likeDoc.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // ===== BÚSQUEDA Y FILTROS =====

  /// Buscar posts por título o contenido
  Future<List<ForumPost>> searchPosts(String query) async {
    try {
      // Buscar en títulos
      final titleResults = await _postsCollection
          .where('titulo', isGreaterThanOrEqualTo: query)
          .where('titulo', isLessThanOrEqualTo: '$query\uf8ff')
          .get();

      final posts = titleResults.docs
          .map((doc) => ForumPost.fromFirestore(doc.data() as Map<String, dynamic>))
          .toList();

      return posts;
    } catch (e) {
      throw Exception('Error buscando posts: $e');
    }
  }

  /// Obtener posts por categoría
  Future<List<ForumPost>> getPostsByCategory(String categoria) async {
    try {
      final snapshot = await _postsCollection
          .where('categoria', isEqualTo: categoria)
          .orderBy('fechaCreacion', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => ForumPost.fromFirestore(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Error obteniendo posts por categoría: $e');
    }
  }

  /// Obtener posts más populares (por likes)
  Future<List<ForumPost>> getPopularPosts({int limit = 10}) async {
    try {
      final snapshot = await _postsCollection
          .orderBy('likes', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => ForumPost.fromFirestore(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Error obteniendo posts populares: $e');
    }
  }

  /// Obtener posts de un usuario específico
  Future<List<ForumPost>> getUserPosts(String userId) async {
    try {
      final snapshot = await _postsCollection
          .where('autorId', isEqualTo: userId)
          .orderBy('fechaCreacion', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => ForumPost.fromFirestore(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Error obteniendo posts del usuario: $e');
    }
  }

  // ===== MÉTODOS PRIVADOS =====

  /// Eliminar todas las respuestas de un post
  Future<void> _deletePostReplies(String postId) async {
    try {
      final repliesSnapshot = await _repliesCollection
          .where('postId', isEqualTo: postId)
          .get();

      for (final doc in repliesSnapshot.docs) {
        await doc.reference.delete();
      }

      // También eliminar los likes de las respuestas
      final replyLikesSnapshot = await _db
          .collection('forum_reply_likes')
          .where('replyId', whereIn: repliesSnapshot.docs.map((doc) => doc.id).toList())
          .get();

      for (final doc in replyLikesSnapshot.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      // Log error but don't throw to avoid breaking post deletion
      print('Error eliminando respuestas del post: $e');
    }
  }

  // ===== ESTADÍSTICAS =====

  /// Obtener estadísticas del foro
  Future<Map<String, int>> getForumStats() async {
    try {
      final postsSnapshot = await _postsCollection.get();
      final repliesSnapshot = await _repliesCollection
          .where('isDeleted', isEqualTo: false)
          .get();

      return {
        'totalPosts': postsSnapshot.docs.length,
        'totalReplies': repliesSnapshot.docs.length,
        'totalTopics': postsSnapshot.docs.length + repliesSnapshot.docs.length,
      };
    } catch (e) {
      return {
        'totalPosts': 0,
        'totalReplies': 0,
        'totalTopics': 0,
      };
    }
  }
}