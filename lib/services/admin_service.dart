import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
      
      await _firestore.collection('users').doc(uid).update({
        'status': UserStatus.suspended.name,
        'suspendedUntil': Timestamp.fromDate(suspendedUntil),
        'suspensionReason': reason,
      });

      // Registrar la acción
      await _logAdminAction(
        action: 'suspend_user',
        targetUserId: uid,
        details: 'Suspendido hasta: ${suspendedUntil.toIso8601String()}. Razón: $reason',
      );
    } catch (e) {
      print('Error suspendiendo usuario: $e');
      rethrow;
    }
  }

  // Banear usuario permanentemente
  Future<void> banUser(String uid, String reason) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'status': UserStatus.banned.name,
        'suspensionReason': reason,
      });

      // Registrar la acción
      await _logAdminAction(
        action: 'ban_user',
        targetUserId: uid,
        details: 'Usuario baneado permanentemente. Razón: $reason',
      );
    } catch (e) {
      print('Error baneando usuario: $e');
      rethrow;
    }
  }

  // Reactivar usuario
  Future<void> reactivateUser(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'status': UserStatus.active.name,
        'suspendedUntil': null,
        'suspensionReason': null,
      });

      // Registrar la acción
      await _logAdminAction(
        action: 'reactivate_user',
        targetUserId: uid,
        details: 'Usuario reactivado',
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
      await _firestore.collection('regulations').add({
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
        details: 'Nuevo reglamento: "$title"',
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
      await _firestore
          .collection('regulations')
          .doc(regulationId)
          .update(updates);

      // Registrar la acción
      await _logAdminAction(
        action: 'update_regulation',
        details: 'Reglamento actualizado: $regulationId',
      );
    } catch (e) {
      print('Error actualizando reglamento: $e');
      rethrow;
    }
  }

  // Eliminar reglamento
  Future<void> deleteRegulation(String regulationId) async {
    try {
      await _firestore
          .collection('regulations')
          .doc(regulationId)
          .update({'isActive': false});

      // Registrar la acción
      await _logAdminAction(
        action: 'delete_regulation',
        details: 'Reglamento desactivado: $regulationId',
      );
    } catch (e) {
      print('Error eliminando reglamento: $e');
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
}