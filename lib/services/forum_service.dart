import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:policode/models/forum_model.dart';
import 'notification_service.dart';
import 'push_notification_service.dart';
import 'cloud_functions_service.dart';

/// Servicio para manejar las operaciones del foro en Firebase
class ForumService {
  static final ForumService _instance = ForumService._internal();
  factory ForumService() => _instance;
  ForumService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();
  final PushNotificationService _pushNotificationService = PushNotificationService();
  final CloudFunctionsService _cloudFunctionsService = CloudFunctionsService();

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

  /// Obtener todos los posts (para administradores)
  Future<List<ForumPost>> getAllPosts() async {
    try {
      final snapshot = await _postsCollection
          .orderBy('fechaCreacion', descending: true)
          .get();
      return snapshot.docs
          .map((doc) => ForumPost.fromFirestore(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Error obteniendo todos los posts: $e');
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

        // Obtener información del post y usuario para la notificación
        final postDoc = await _postsCollection.doc(postId).get();
        if (postDoc.exists) {
          final postData = postDoc.data() as Map<String, dynamic>;
          final postTitle = postData['titulo'] ?? '';
          final postAuthorId = postData['autorId'] ?? '';
          
          // Obtener nombre del usuario que dio like
          final userDoc = await _db.collection('users').doc(userId).get();
          final userName = userDoc.data()?['username'] ?? 'Usuario';
          
          // Enviar notificación al autor del post (si no es el mismo)
          if (postAuthorId != userId) {
            // 1. Crear notificación en base de datos
            await _notificationService.notifyPostLiked(
              postId: postId,
              postTitle: postTitle,
              postAuthorId: postAuthorId,
              fromUserId: userId,
              fromUserName: userName,
            );

            // 2. Enviar notificación push (Cloud Functions + FCM respaldo)
            await _sendHybridNotification(
              targetUserId: postAuthorId,
              title: 'Like en tu post',
              body: 'A $userName le gustó tu post "$postTitle"',
              type: 'post_liked',
              postId: postId,
              fromUserId: userId,
              fromUserName: userName,
              priority: 'low',
            );
          }
        }
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
          .map((doc) => ForumReply.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
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

      // Obtener información del post para la notificación
      final postDoc = await _postsCollection.doc(reply.postId).get();
      if (postDoc.exists) {
        final postData = postDoc.data() as Map<String, dynamic>;
        final postTitle = postData['titulo'] ?? '';
        final postAuthorId = postData['autorId'] ?? '';
        
        // Enviar notificación al autor del post (si no es el mismo que responde)
        if (postAuthorId != reply.autorId) {
          // 1. Crear notificación en base de datos
          await _notificationService.notifyPostReply(
            postId: reply.postId,
            postTitle: postTitle,
            postAuthorId: postAuthorId,
            fromUserId: reply.autorId,
            fromUserName: reply.autorNombre,
          );

          // 2. Enviar notificación push (Cloud Functions + FCM respaldo)
          await _sendHybridNotification(
            targetUserId: postAuthorId,
            title: 'Nueva respuesta',
            body: '${reply.autorNombre} respondió a tu post "$postTitle"',
            type: 'post_reply',
            postId: reply.postId,
            fromUserId: reply.autorId,
            fromUserName: reply.autorNombre,
            priority: 'medium',
          );
        }
      }
      
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

  /// Obtener un post específico por su ID
  Future<ForumPost?> getPostById(String postId) async {
    try {
      final docSnapshot = await _postsCollection.doc(postId).get();
      
      if (docSnapshot.exists) {
        final data = docSnapshot.data() as Map<String, dynamic>;
        data['id'] = docSnapshot.id; // Agregar el id del documento
        return ForumPost.fromFirestore(data);
      }
      
      return null;
    } catch (e) {
      print('❌ Error obteniendo post por ID: $e');
      throw Exception('Error obteniendo post: $e');
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

  /// Obtener posts de un usuario específico
  Future<List<ForumPost>> getPostsByUser(String userId) async {
    try {
      print('🔍 Buscando posts para usuario: $userId');
      
      // Primero intentar sin filtro de isDeleted para ver si hay posts
      final allUserPosts = await _postsCollection
          .where('autorId', isEqualTo: userId)
          .orderBy('fechaCreacion', descending: true)
          .get();
      
      print('📊 Total posts del usuario (sin filtrar): ${allUserPosts.docs.length}');
      
      // Filtrar manualmente los posts no eliminados
      final posts = <ForumPost>[];
      for (final doc in allUserPosts.docs) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        
        // Verificar si el post está eliminado (por defecto false si no existe el campo)
        final isDeleted = data['isDeleted'] ?? false;
        print('📝 Post: ${data['titulo']} - isDeleted: $isDeleted');
        
        if (!isDeleted) {
          posts.add(ForumPost.fromFirestore(data));
        }
      }
      
      print('📊 Posts no eliminados: ${posts.length}');
      return posts;
    } catch (e) {
      print('❌ Error obteniendo posts del usuario: $e');
      throw Exception('Error obteniendo posts del usuario: $e');
    }
  }

  /// Obtener respuestas de un usuario específico
  Future<List<ForumReply>> getRepliesByUser(String userId) async {
    try {
      final querySnapshot = await _repliesCollection
          .where('autorId', isEqualTo: userId)
          .where('isDeleted', isEqualTo: false)
          .orderBy('fechaCreacion', descending: true)
          .get();

      List<ForumReply> respuestas = [];
      
      for (var doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final respuesta = ForumReply.fromFirestore(data, doc.id);
        
        // Obtener el título del post para mostrar contexto
        String? postTitulo;
        try {
          final postDoc = await _postsCollection.doc(respuesta.postId).get();
          if (postDoc.exists) {
            final postData = postDoc.data() as Map<String, dynamic>;
            postTitulo = postData['titulo'] as String?;
          }
        } catch (e) {
          // Si no se puede obtener el post, continuar sin título
        }
        
        // Crear una nueva instancia con el título del post
        final respuestaConTitulo = ForumReply(
          id: respuesta.id,
          postId: respuesta.postId,
          contenido: respuesta.contenido,
          autorId: respuesta.autorId,
          autorNombre: respuesta.autorNombre,
          autorPhotoURL: respuesta.autorPhotoURL,
          fechaCreacion: respuesta.fechaCreacion,
          fechaActualizacion: respuesta.fechaActualizacion,
          likes: respuesta.likes,
          replyToId: respuesta.replyToId,
          isDeleted: respuesta.isDeleted,
          mediaAttachments: respuesta.mediaAttachments,
          postTitulo: postTitulo,
        );
        
        respuestas.add(respuestaConTitulo);
      }

      return respuestas;
    } catch (e) {
      throw Exception('Error obteniendo respuestas del usuario: $e');
    }
  }

  // ===== MÉTODOS PARA IA =====

  /// Buscar posts relevantes para una consulta usando búsqueda por texto
  Future<List<ForumPost>> searchPostsForAI(String query, {int limit = 5}) async {
    try {
      final queryLower = query.toLowerCase();
      
      // Obtener posts recientes para buscar manualmente
      final querySnapshot = await _postsCollection
          .where('isDeleted', isEqualTo: false)
          .orderBy('fechaCreacion', descending: true)
          .limit(50) // Buscar en los últimos 50 posts
          .get();

      final List<ForumPost> relevantPosts = [];
      
      for (final doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        
        final post = ForumPost.fromFirestore(data);
        
        // Buscar coincidencias en título, contenido, tags o categoría
        final titleLower = post.titulo.toLowerCase();
        final contentLower = post.contenido.toLowerCase();
        final tagsLower = post.tags.join(' ').toLowerCase();
        final categoryLower = (post.categoria ?? '').toLowerCase();
        
        // Calcular relevancia (simple scoring)
        int score = 0;
        if (titleLower.contains(queryLower)) score += 10;
        if (contentLower.contains(queryLower)) score += 5;
        if (tagsLower.contains(queryLower)) score += 8;
        if (categoryLower.contains(queryLower)) score += 6;
        
        // Buscar palabras individuales
        final queryWords = queryLower.split(' ').where((w) => w.length > 2);
        for (final word in queryWords) {
          if (titleLower.contains(word)) score += 3;
          if (contentLower.contains(word)) score += 1;
          if (tagsLower.contains(word)) score += 2;
        }
        
        if (score > 0) {
          relevantPosts.add(post);
        }
      }
      
      // Ordenar por likes y respuestas (popularidad) y tomar los primeros
      relevantPosts.sort((a, b) {
        final scoreA = a.likes + a.respuestas;
        final scoreB = b.likes + b.respuestas;
        return scoreB.compareTo(scoreA);
      });
      
      return relevantPosts.take(limit).toList();
    } catch (e) {
      print('Error buscando posts para IA: $e');
      return [];
    }
  }

  /// Generar contexto de posts para la IA
  Future<String> generarContextoPostsParaIA(String query) async {
    try {
      final postsRelevantes = await searchPostsForAI(query);
      
      if (postsRelevantes.isEmpty) {
        return 'No se encontraron posts relevantes en el foro para esta consulta.';
      }
      
      final buffer = StringBuffer();
      buffer.writeln('CONTEXTO DEL FORO:');
      buffer.writeln('Posts relevantes encontrados en el foro de la comunidad:');
      buffer.writeln();
      
      for (int i = 0; i < postsRelevantes.length; i++) {
        final post = postsRelevantes[i];
        buffer.writeln('POST ${i + 1}:');
        buffer.writeln('Título: ${post.titulo}');
        buffer.writeln('Autor: ${post.autorNombre}');
        buffer.writeln('Categoría: ${post.categoria ?? "General"}');
        if (post.tags.isNotEmpty) {
          buffer.writeln('Tags: ${post.tags.join(", ")}');
        }
        buffer.writeln('Likes: ${post.likes} | Respuestas: ${post.respuestas}');
        
        // Truncar contenido para no sobrecargar el prompt
        final contenidoTruncado = post.contenido.length > 200 
            ? '${post.contenido.substring(0, 200)}...'
            : post.contenido;
        buffer.writeln('Contenido: $contenidoTruncado');
        buffer.writeln('---');
      }
      
      return buffer.toString();
    } catch (e) {
      print('Error generando contexto de posts: $e');
      return 'Error al obtener información del foro.';
    }
  }

  /// Obtener posts más populares para contexto general
  Future<List<ForumPost>> getPopularPostsForContext({int limit = 10}) async {
    try {
      final querySnapshot = await _postsCollection
          .where('isDeleted', isEqualTo: false)
          .orderBy('likes', descending: true)
          .limit(limit)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return ForumPost.fromFirestore(data);
      }).toList();
    } catch (e) {
      print('Error obteniendo posts populares: $e');
      return [];
    }
  }

  // ===== SISTEMA HÍBRIDO DE NOTIFICACIONES =====

  /// Enviar notificación usando sistema híbrido:
  /// 1. Intenta Cloud Functions (preferido)
  /// 2. Si falla, usa FCM directo como respaldo
  Future<void> _sendHybridNotification({
    required String targetUserId,
    required String title,
    required String body,
    String? type,
    String? postId,
    String? fromUserId,
    String? fromUserName,
    String? priority,
  }) async {
    try {
      print('🚀 Intentando envío via Cloud Functions...');
      
      // Intento 1: Cloud Functions (v2 con triggers automáticos)
      final cloudSuccess = await _cloudFunctionsService.sendDirectNotification(
        targetUserId: targetUserId,
        title: title,
        body: body,
        type: type,
        postId: postId,
        fromUserId: fromUserId,
        fromUserName: fromUserName,
        priority: priority,
      );

      if (cloudSuccess) {
        print('✅ Notificación enviada via Cloud Functions');
        return;
      }

      print('⚠️ Cloud Functions falló, usando FCM directo como respaldo...');
      
      // Intento 2: FCM directo como respaldo
      await _pushNotificationService.sendPushOnly(
        userId: targetUserId,
        title: title,
        body: body,
        data: {
          'type': type ?? 'system_message',
          'postId': postId ?? '',
          'fromUserId': fromUserId ?? '',
          'fromUserName': fromUserName ?? '',
          'actionUrl': postId != null ? '/forum-post-detail?postId=$postId' : '',
          'priority': priority ?? 'medium',
        },
      );
      
      print('✅ Notificación enviada via FCM directo (respaldo)');

    } catch (e) {
      print('❌ Error en sistema híbrido de notificaciones: $e');
      
      // Último intento: FCM directo
      try {
        await _pushNotificationService.sendPushOnly(
          userId: targetUserId,
          title: title,
          body: body,
          data: {
            'type': type ?? 'system_message',
            'postId': postId ?? '',
            'fromUserId': fromUserId ?? '',
            'fromUserName': fromUserName ?? '',
            'actionUrl': postId != null ? '/forum-post-detail?postId=$postId' : '',
            'priority': priority ?? 'medium',
          },
        );
        print('✅ Notificación enviada via FCM directo (último recurso)');
      } catch (fcmError) {
        print('❌ Error total en notificaciones: $fcmError');
      }
    }
  }
}