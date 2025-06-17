import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';
import '../models/report_model.dart';
import '../models/forum_model.dart';

class AdminService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Verificar si el usuario actual es admin
  Future<bool> isCurrentUserAdmin() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return false;

    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (!userDoc.exists) return false;

      final userData = UserModel.fromFirestore(userDoc);
      return userData.isAdmin;
    } catch (e) {
      print('Error verificando admin: $e');
      return false;
    }
  }

  // Obtener información del usuario
  Future<UserModel?> getUserById(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error obteniendo usuario: $e');
      return null;
    }
  }

  // Crear o actualizar usuario
  Future<void> createOrUpdateUser(UserModel user) async {
    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .set(user.toFirestore(), SetOptions(merge: true));
    } catch (e) {
      print('Error actualizando usuario: $e');
      rethrow;
    }
  }

  // Suspender usuario
  Future<void> suspendUser(
    String uid,
    Duration duration,
    String reason,
  ) async {
    try {
      final suspendedUntil = DateTime.now().add(duration);
      
      // Obtener información del usuario antes del cambio
      final userDoc = await _firestore.collection('users').doc(uid).get();
      final userData = userDoc.data() as Map<String, dynamic>? ?? {};
      final userName = userData['displayName'] ?? userData['email'] ?? 'Usuario desconocido';
      
      await _firestore.collection('users').doc(uid).update({
        'status': UserStatus.suspended.name,
        'suspendedUntil': Timestamp.fromDate(suspendedUntil),
        'suspensionReason': reason,
      });

      // Registrar la acción
      await _logAdminAction(
        action: 'suspend_user',
        targetUserId: uid,
        details: 'Usuario "$userName" suspendido hasta: ${DateFormat('dd/MM/yyyy HH:mm').format(suspendedUntil)}. Duración: ${duration.inDays > 0 ? '${duration.inDays} días' : '${duration.inHours} horas'}. Razón: $reason',
      );
    } catch (e) {
      print('Error suspendiendo usuario: $e');
      rethrow;
    }
  }

  // Banear usuario permanentemente
  Future<void> banUser(String uid, String reason) async {
    try {
      // Obtener información del usuario antes del cambio
      final userDoc = await _firestore.collection('users').doc(uid).get();
      final userData = userDoc.data() as Map<String, dynamic>? ?? {};
      final userName = userData['displayName'] ?? userData['email'] ?? 'Usuario desconocido';
      
      await _firestore.collection('users').doc(uid).update({
        'status': UserStatus.banned.name,
        'suspensionReason': reason,
      });

      // Registrar la acción
      await _logAdminAction(
        action: 'ban_user',
        targetUserId: uid,
        details: 'Usuario "$userName" baneado permanentemente. Razón: $reason',
      );
    } catch (e) {
      print('Error baneando usuario: $e');
      rethrow;
    }
  }

  // Reactivar usuario
  Future<void> reactivateUser(String uid) async {
    try {
      // Obtener información del usuario antes del cambio
      final userDoc = await _firestore.collection('users').doc(uid).get();
      final userData = userDoc.data() as Map<String, dynamic>? ?? {};
      final userName = userData['displayName'] ?? userData['email'] ?? 'Usuario desconocido';
      final previousStatus = userData['status'] ?? 'desconocido';
      
      await _firestore.collection('users').doc(uid).update({
        'status': UserStatus.active.name,
        'suspendedUntil': null,
        'suspensionReason': null,
      });

      // Registrar la acción
      await _logAdminAction(
        action: 'reactivate_user',
        targetUserId: uid,
        details: 'Usuario "$userName" reactivado (estado anterior: $previousStatus)',
      );
    } catch (e) {
      print('Error reactivando usuario: $e');
      rethrow;
    }
  }

  // Crear reporte
  Future<void> createReport(ReportModel report) async {
    try {
      await _firestore
          .collection('reports')
          .add(report.toFirestore());

      // Incrementar contador de reportes del usuario reportado
      await _firestore.collection('users').doc(report.reportedUserId).update({
        'reportCount': FieldValue.increment(1),
      });
    } catch (e) {
      print('Error creando reporte: $e');
      rethrow;
    }
  }

  // Obtener reportes
  Stream<List<ReportModel>> getReports({ReportStatus? status}) {
    Query query = _firestore.collection('reports');

    if (status != null) {
      query = query.where('status', isEqualTo: status.name);
    }

    return query
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ReportModel.fromFirestore(doc))
          .toList();
    });
  }

  // Resolver reporte
  Future<void> resolveReport(
    String reportId,
    String resolutionNotes,
    String actionTaken,
  ) async {
    try {
      final adminId = _auth.currentUser?.uid;
      
      await _firestore.collection('reports').doc(reportId).update({
        'status': ReportStatus.resolved.name,
        'reviewedAt': Timestamp.now(),
        'reviewedBy': adminId,
        'resolutionNotes': resolutionNotes,
        'actionTaken': actionTaken,
      });
    } catch (e) {
      print('Error resolviendo reporte: $e');
      rethrow;
    }
  }

  // Desestimar reporte
  Future<void> dismissReport(String reportId, String reason) async {
    try {
      final adminId = _auth.currentUser?.uid;
      
      await _firestore.collection('reports').doc(reportId).update({
        'status': ReportStatus.dismissed.name,
        'reviewedAt': Timestamp.now(),
        'reviewedBy': adminId,
        'resolutionNotes': reason,
      });
    } catch (e) {
      print('Error desestimando reporte: $e');
      rethrow;
    }
  }

  // Eliminar post
  Future<void> deletePost(String postId, String reason) async {
    try {
      // Obtener el post para registrar información
      final postDoc = await _firestore
          .collection('forum_posts')
          .doc(postId)
          .get();
      
      if (postDoc.exists) {
        final postData = postDoc.data() as Map<String, dynamic>;
        final post = ForumPost.fromFirestore(postData);
        
        // Eliminar el post
        await _firestore.collection('forum_posts').doc(postId).delete();
        
        // Eliminar respuestas asociadas
        final replies = await _firestore
            .collection('forum_replies')
            .where('postId', isEqualTo: postId)
            .get();
        
        for (var reply in replies.docs) {
          await reply.reference.delete();
        }

        // Registrar la acción
        await _logAdminAction(
          action: 'delete_post',
          targetUserId: post.autorId,
          details: 'Post eliminado: "${post.titulo}". Razón: $reason',
          contentId: postId,
        );
      }
    } catch (e) {
      print('Error eliminando post: $e');
      rethrow;
    }
  }

  // Eliminar respuesta
  Future<void> deleteReply(String replyId, String reason) async {
    try {
      // Obtener la respuesta para registrar información
      final replyDoc = await _firestore
          .collection('forum_replies')
          .doc(replyId)
          .get();
      
      if (replyDoc.exists) {
        final replyData = replyDoc.data() as Map<String, dynamic>;
        final reply = ForumReply.fromFirestore(replyData, replyDoc.id);
        
        // Eliminar la respuesta
        await _firestore.collection('forum_replies').doc(replyId).delete();

        // Registrar la acción
        await _logAdminAction(
          action: 'delete_reply',
          targetUserId: reply.autorId,
          details: 'Respuesta eliminada. Razón: $reason',
          contentId: replyId,
        );
      }
    } catch (e) {
      print('Error eliminando respuesta: $e');
      rethrow;
    }
  }

  // Subir nuevo reglamento/ley
  Future<void> uploadRegulation(
    String title,
    String content,
    String category,
    List<String> tags,
  ) async {
    try {
      final docRef = await _firestore.collection('regulations').add({
        'title': title,
        'content': content,
        'category': category,
        'tags': tags,
        'uploadedBy': _auth.currentUser?.uid,
        'uploadedAt': Timestamp.now(),
        'isActive': true,
      });

      // Registrar la acción
      await _logAdminAction(
        action: 'upload_regulation',
        details: 'Nuevo reglamento creado: "$title" en categoría: $category. Etiquetas: ${tags.join(', ')}',
        contentId: docRef.id,
      );
    } catch (e) {
      print('Error subiendo reglamento: $e');
      rethrow;
    }
  }

  // Actualizar reglamento
  Future<void> updateRegulation(
    String regulationId,
    Map<String, dynamic> updates,
  ) async {
    try {
      // Obtener información del reglamento antes del cambio
      final regDoc = await _firestore.collection('regulations').doc(regulationId).get();
      final regData = regDoc.data() as Map<String, dynamic>? ?? {};
      final regTitle = regData['title'] ?? 'Reglamento sin título';
      
      await _firestore
          .collection('regulations')
          .doc(regulationId)
          .update(updates);

      // Crear descripción de los cambios
      final changesDesc = updates.entries.map((entry) {
        switch (entry.key) {
          case 'title':
            return 'Título: "${entry.value}"';
          case 'category':
            return 'Categoría: ${entry.value}';
          case 'isActive':
            return entry.value ? 'Activado' : 'Desactivado';
          case 'tags':
            return 'Etiquetas: ${(entry.value as List).join(', ')}';
          default:
            return '${entry.key}: ${entry.value}';
        }
      }).join(', ');

      // Registrar la acción
      await _logAdminAction(
        action: 'update_regulation',
        details: 'Reglamento "$regTitle" actualizado. Cambios: $changesDesc',
        contentId: regulationId,
      );
    } catch (e) {
      print('Error actualizando reglamento: $e');
      rethrow;
    }
  }

  // Eliminar reglamento
  Future<void> deleteRegulation(String regulationId) async {
    try {
      // Obtener información del reglamento antes del cambio
      final regDoc = await _firestore.collection('regulations').doc(regulationId).get();
      final regData = regDoc.data() as Map<String, dynamic>? ?? {};
      final regTitle = regData['title'] ?? 'Reglamento sin título';
      
      await _firestore
          .collection('regulations')
          .doc(regulationId)
          .update({'isActive': false});

      // Registrar la acción
      await _logAdminAction(
        action: 'delete_regulation',
        details: 'Reglamento "$regTitle" desactivado',
        contentId: regulationId,
      );
    } catch (e) {
      print('Error eliminando reglamento: $e');
      rethrow;
    }
  }

  // Hacer administrador
  Future<void> makeAdmin(String uid) async {
    try {
      // Obtener información del usuario antes del cambio
      final userDoc = await _firestore.collection('users').doc(uid).get();
      final userData = userDoc.data() as Map<String, dynamic>? ?? {};
      final userName = userData['displayName'] ?? userData['email'] ?? 'Usuario desconocido';
      
      await _firestore.collection('users').doc(uid).update({
        'role': UserRole.admin.name,
      });

      // Registrar la acción
      await _logAdminAction(
        action: 'make_admin',
        targetUserId: uid,
        details: 'Usuario "$userName" promovido a administrador',
      );
    } catch (e) {
      print('Error promoviendo usuario a admin: $e');
      rethrow;
    }
  }

  // Remover privilegios de administrador
  Future<void> removeAdmin(String uid) async {
    try {
      // Obtener información del usuario antes del cambio
      final userDoc = await _firestore.collection('users').doc(uid).get();
      final userData = userDoc.data() as Map<String, dynamic>? ?? {};
      final userName = userData['displayName'] ?? userData['email'] ?? 'Usuario desconocido';
      
      await _firestore.collection('users').doc(uid).update({
        'role': UserRole.user.name,
      });

      // Registrar la acción
      await _logAdminAction(
        action: 'remove_admin',
        targetUserId: uid,
        details: 'Privilegios de administrador removidos de "$userName"',
      );
    } catch (e) {
      print('Error removiendo privilegios de admin: $e');
      rethrow;
    }
  }

  // Obtener estadísticas del sistema
  Future<Map<String, dynamic>> getSystemStats() async {
    try {
      // Ejecutar todas las consultas en paralelo para mejor performance
      final results = await Future.wait([
        // Usuarios totales
        _firestore.collection('users').count().get(),
        // Posts totales
        _firestore.collection('forum_posts').count().get(),
        // Respuestas totales
        _firestore.collection('forum_replies').count().get(),
        // Reportes pendientes
        _firestore.collection('reports')
            .where('status', isEqualTo: ReportStatus.pending.name)
            .count().get(),
        // Reportes totales
        _firestore.collection('reports').count().get(),
        // Usuarios suspendidos
        _firestore.collection('users')
            .where('status', isEqualTo: UserStatus.suspended.name)
            .count().get(),
        // Usuarios baneados
        _firestore.collection('users')
            .where('status', isEqualTo: UserStatus.banned.name)
            .count().get(),
        // Usuarios activos (últimos 30 días)
        _firestore.collection('users')
            .where('status', isEqualTo: UserStatus.active.name)
            .count().get(),
        // Reglamentos activos
        _firestore.collection('regulations')
            .where('isActive', isEqualTo: true)
            .count().get(),
      ]);

      // Estadísticas adicionales
      final now = DateTime.now();
      final lastWeek = now.subtract(const Duration(days: 7));
      final lastMonth = now.subtract(const Duration(days: 30));

      // Posts de la última semana
      final recentPosts = await _firestore
          .collection('forum_posts')
          .where('fechaCreacion', isGreaterThan: Timestamp.fromDate(lastWeek))
          .count()
          .get();

      // Reportes de la última semana
      final recentReports = await _firestore
          .collection('reports')
          .where('createdAt', isGreaterThan: Timestamp.fromDate(lastWeek))
          .count()
          .get();

      return {
        'totalUsers': results[0].count ?? 0,
        'totalPosts': results[1].count ?? 0,
        'totalReplies': results[2].count ?? 0,
        'pendingReports': results[3].count ?? 0,
        'totalReports': results[4].count ?? 0,
        'suspendedUsers': results[5].count ?? 0,
        'bannedUsers': results[6].count ?? 0,
        'activeUsers': results[7].count ?? 0,
        'activeRegulations': results[8].count ?? 0,
        'recentPosts': recentPosts.count ?? 0,
        'recentReports': recentReports.count ?? 0,
        'lastUpdated': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      print('Error obteniendo estadísticas: $e');
      return {};
    }
  }

  // Registrar acción de administrador
  Future<void> _logAdminAction({
    required String action,
    String? targetUserId,
    String? contentId,
    required String details,
  }) async {
    try {
      await _firestore.collection('admin_logs').add({
        'adminId': _auth.currentUser?.uid,
        'action': action,
        'targetUserId': targetUserId,
        'contentId': contentId,
        'details': details,
        'timestamp': Timestamp.now(),
      });
    } catch (e) {
      print('Error registrando log de admin: $e');
    }
  }

  // Obtener logs de administrador
  Stream<QuerySnapshot> getAdminLogs({int limit = 50}) {
    return _firestore
        .collection('admin_logs')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots();
  }

  // === GESTIÓN DE POSTS PARA ADMIN ===
  
  // Obtener todos los posts para gestión admin
  Stream<List<ForumPost>> getAllPostsForAdmin() {
    return _firestore
        .collection('forum_posts')
        .orderBy('fechaCreacion', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return ForumPost.fromFirestore(data);
      }).toList();
    });
  }

  // Obtener posts reportados
  Stream<List<ForumPost>> getReportedPosts() {
    return _firestore
        .collection('reports')
        .where('status', isEqualTo: ReportStatus.pending.name)
        .where('contentType', isEqualTo: 'post')
        .snapshots()
        .asyncMap((reportSnapshot) async {
      final postIds = reportSnapshot.docs
          .map((doc) => doc.data()['contentId'] as String)
          .toSet()
          .toList();

      if (postIds.isEmpty) return <ForumPost>[];

      final posts = <ForumPost>[];
      
      // Obtener posts en lotes de 10 (límite de Firestore)
      for (int i = 0; i < postIds.length; i += 10) {
        final batch = postIds.skip(i).take(10).toList();
        final postSnapshots = await _firestore
            .collection('forum_posts')
            .where(FieldPath.documentId, whereIn: batch)
            .get();
        
        for (final doc in postSnapshots.docs) {
          if (doc.exists) {
            final data = doc.data() as Map<String, dynamic>;
            posts.add(ForumPost.fromFirestore(data));
          }
        }
      }
      
      return posts;
    });
  }

  // Obtener posts reportados como lista (no stream)
  Future<List<ForumPost>> getReportedPostsList() async {
    try {
      final reportSnapshot = await _firestore
          .collection('reports')
          .where('status', isEqualTo: ReportStatus.pending.name)
          .where('contentType', isEqualTo: 'post')
          .get();

      final postIds = reportSnapshot.docs
          .map((doc) => doc.data()['contentId'] as String)
          .toSet()
          .toList();

      if (postIds.isEmpty) return <ForumPost>[];

      final posts = <ForumPost>[];
      
      // Obtener posts en lotes de 10 (límite de Firestore)
      for (int i = 0; i < postIds.length; i += 10) {
        final batch = postIds.skip(i).take(10).toList();
        final postSnapshots = await _firestore
            .collection('forum_posts')
            .where(FieldPath.documentId, whereIn: batch)
            .get();
        
        for (final doc in postSnapshots.docs) {
          if (doc.exists) {
            final data = doc.data() as Map<String, dynamic>;
            posts.add(ForumPost.fromFirestore(data));
          }
        }
      }
      
      return posts;
    } catch (e) {
      print('Error obteniendo posts reportados: $e');
      return [];
    }
  }

  // Agregar comentario oficial de admin a un post
  Future<void> addAdminCommentToPost(String postId, String comment) async {
    return addAdminComment(postId, comment, isPinned: false);
  }

  // Agregar comentario oficial de admin a un post
  Future<void> addAdminComment(
    String postId,
    String comment,
    {bool isPinned = false}
  ) async {
    try {
      // Obtener información del post
      final postDoc = await _firestore
          .collection('forum_posts')
          .doc(postId)
          .get();
      
      if (!postDoc.exists) {
        throw Exception('Post no encontrado');
      }

      final postData = postDoc.data() as Map<String, dynamic>;
      final postTitle = postData['titulo'] ?? 'Post sin título';

      // Crear la respuesta como admin
      await _firestore.collection('forum_replies').add({
        'postId': postId,
        'autorId': _auth.currentUser?.uid,
        'autorNombre': 'Administrador',
        'contenido': comment,
        'fechaCreacion': Timestamp.now(),
        'likes': 0,
        'isAdminComment': true,
        'isPinned': isPinned,
        'attachments': [],
      });

      // Registrar la acción
      await _logAdminAction(
        action: 'admin_comment',
        contentId: postId,
        details: 'Comentario oficial agregado al post "$postTitle"${isPinned ? ' (fijado)' : ''}',
      );
    } catch (e) {
      print('Error agregando comentario de admin: $e');
      rethrow;
    }
  }

  // Fijar/desfijar post
  Future<void> togglePinPost(String postId) async {
    try {
      final postDoc = await _firestore
          .collection('forum_posts')
          .doc(postId)
          .get();
      
      if (!postDoc.exists) {
        throw Exception('Post no encontrado');
      }

      final postData = postDoc.data() as Map<String, dynamic>;
      final currentlyPinned = postData['isPinned'] ?? false;
      final postTitle = postData['titulo'] ?? 'Post sin título';

      await _firestore.collection('forum_posts').doc(postId).update({
        'isPinned': !currentlyPinned,
        'pinnedAt': !currentlyPinned ? Timestamp.now() : null,
        'pinnedBy': !currentlyPinned ? _auth.currentUser?.uid : null,
      });

      // Registrar la acción
      await _logAdminAction(
        action: currentlyPinned ? 'unpin_post' : 'pin_post',
        contentId: postId,
        details: 'Post "$postTitle" ${currentlyPinned ? 'desfijado' : 'fijado'}',
      );
    } catch (e) {
      print('Error cambiando estado de pin del post: $e');
      rethrow;
    }
  }

  // Cerrar/abrir post para comentarios
  Future<void> toggleLockPost(String postId) async {
    try {
      final postDoc = await _firestore
          .collection('forum_posts')
          .doc(postId)
          .get();
      
      if (!postDoc.exists) {
        throw Exception('Post no encontrado');
      }

      final postData = postDoc.data() as Map<String, dynamic>;
      final currentlyLocked = postData['isLocked'] ?? false;
      final postTitle = postData['titulo'] ?? 'Post sin título';

      await _firestore.collection('forum_posts').doc(postId).update({
        'isLocked': !currentlyLocked,
        'lockedAt': !currentlyLocked ? Timestamp.now() : null,
        'lockedBy': !currentlyLocked ? _auth.currentUser?.uid : null,
      });

      // Registrar la acción
      await _logAdminAction(
        action: currentlyLocked ? 'unlock_post' : 'lock_post',
        contentId: postId,
        details: 'Post "$postTitle" ${currentlyLocked ? 'abierto' : 'cerrado'} para comentarios',
      );
    } catch (e) {
      print('Error cambiando estado de bloqueo del post: $e');
      rethrow;
    }
  }

  // Obtener estadísticas de posts
  Future<Map<String, dynamic>> getPostStats() async {
    try {
      final now = DateTime.now();
      final lastWeek = now.subtract(const Duration(days: 7));
      final lastMonth = now.subtract(const Duration(days: 30));

      final results = await Future.wait([
        // Posts totales
        _firestore.collection('forum_posts').count().get(),
        // Posts de la última semana
        _firestore.collection('forum_posts')
            .where('fechaCreacion', isGreaterThan: Timestamp.fromDate(lastWeek))
            .count().get(),
        // Posts del último mes
        _firestore.collection('forum_posts')
            .where('fechaCreacion', isGreaterThan: Timestamp.fromDate(lastMonth))
            .count().get(),
        // Posts fijados
        _firestore.collection('forum_posts')
            .where('isPinned', isEqualTo: true)
            .count().get(),
        // Posts cerrados
        _firestore.collection('forum_posts')
            .where('isLocked', isEqualTo: true)
            .count().get(),
      ]);

      return {
        'totalPosts': results[0].count ?? 0,
        'postsLastWeek': results[1].count ?? 0,
        'postsLastMonth': results[2].count ?? 0,
        'pinnedPosts': results[3].count ?? 0,
        'lockedPosts': results[4].count ?? 0,
      };
    } catch (e) {
      print('Error obteniendo estadísticas de posts: $e');
      return {};
    }
  }
}