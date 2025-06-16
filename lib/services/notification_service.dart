import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/notification_model.dart';

/// Servicio de notificaciones
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Crear una nueva notificación
  Future<void> createNotification(NotificationModel notification) async {
    try {
      await _firestore.collection('notifications').add(notification.toFirestore());
    } catch (e) {
      print('Error creando notificación: $e');
      rethrow;
    }
  }

  /// Obtener notificaciones del usuario actual
  Stream<List<NotificationModel>> getUserNotifications({
    int limit = 50,
    bool unreadOnly = false,
  }) {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return Stream.value([]);
    }

    Query query = _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true);

    if (unreadOnly) {
      query = query.where('isRead', isEqualTo: false);
    }

    if (limit > 0) {
      query = query.limit(limit);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => NotificationModel.fromFirestore(doc))
          .toList();
    });
  }

  /// Obtener el conteo de notificaciones no leídas
  Stream<int> getUnreadCount() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return Stream.value(0);
    }

    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Marcar una notificación como leída
  Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'isRead': true,
        'readAt': Timestamp.now(),
      });
    } catch (e) {
      print('Error marcando notificación como leída: $e');
      rethrow;
    }
  }

  /// Marcar todas las notificaciones como leídas
  Future<void> markAllAsRead() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      final unreadNotifications = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      final now = Timestamp.now();

      for (final doc in unreadNotifications.docs) {
        batch.update(doc.reference, {
          'isRead': true,
          'readAt': now,
        });
      }

      await batch.commit();
    } catch (e) {
      print('Error marcando todas las notificaciones como leídas: $e');
      rethrow;
    }
  }

  /// Eliminar una notificación
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).delete();
    } catch (e) {
      print('Error eliminando notificación: $e');
      rethrow;
    }
  }

  // === MÉTODOS PARA CREAR NOTIFICACIONES ESPECÍFICAS ===

  /// Notificar nueva respuesta a post
  Future<void> notifyPostReply({
    required String postId,
    required String postTitle,
    required String postAuthorId,
    required String fromUserId,
    required String fromUserName,
  }) async {
    // No notificar si el autor responde a su propio post
    if (postAuthorId == fromUserId) return;

    final notification = NotificationFactory.createPostReplyNotification(
      userId: postAuthorId,
      postId: postId,
      postTitle: postTitle,
      fromUserId: fromUserId,
      fromUserName: fromUserName,
    );

    await createNotification(notification);
  }

  /// Notificar like en post
  Future<void> notifyPostLiked({
    required String postId,
    required String postTitle,
    required String postAuthorId,
    required String fromUserId,
    required String fromUserName,
  }) async {
    // No notificar si el autor le da like a su propio post
    if (postAuthorId == fromUserId) return;

    final notification = NotificationFactory.createPostLikedNotification(
      userId: postAuthorId,
      postId: postId,
      postTitle: postTitle,
      fromUserId: fromUserId,
      fromUserName: fromUserName,
    );

    await createNotification(notification);
  }

  /// Notificar comentario de administrador
  Future<void> notifyAdminComment({
    required String postId,
    required String postTitle,
    required String postAuthorId,
    required String adminMessage,
  }) async {
    final notification = NotificationFactory.createAdminCommentNotification(
      userId: postAuthorId,
      postId: postId,
      postTitle: postTitle,
      adminMessage: adminMessage,
    );

    await createNotification(notification);
  }

  /// Notificar post eliminado
  Future<void> notifyPostDeleted({
    required String userId,
    required String postTitle,
    required String reason,
  }) async {
    final notification = NotificationFactory.createPostDeletedNotification(
      userId: userId,
      postTitle: postTitle,
      reason: reason,
    );

    await createNotification(notification);
  }

  /// Crear anuncio general para todos los usuarios activos
  Future<void> createGeneralAnnouncement({
    required String title,
    required String message,
    NotificationPriority priority = NotificationPriority.medium,
    String? actionUrl,
  }) async {
    try {
      // Obtener todos los usuarios activos
      final activeUsers = await _firestore
          .collection('users')
          .where('status', isEqualTo: 'active')
          .get();

      final batch = _firestore.batch();

      for (final userDoc in activeUsers.docs) {
        final notification = NotificationFactory.createGeneralAnnouncementNotification(
          targetUserIds: [userDoc.id],
          title: title,
          message: message,
          priority: priority,
          actionUrl: actionUrl,
        ).copyWith(userId: userDoc.id);

        final docRef = _firestore.collection('notifications').doc();
        batch.set(docRef, notification.toFirestore());
      }

      await batch.commit();
    } catch (e) {
      print('Error creando anuncio general: $e');
      rethrow;
    }
  }

  /// Obtener estadísticas de notificaciones
  Future<Map<String, int>> getNotificationStats() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return {};

    try {
      final results = await Future.wait([
        // Total de notificaciones
        _firestore
            .collection('notifications')
            .where('userId', isEqualTo: userId)
            .count()
            .get(),
        // Notificaciones no leídas
        _firestore
            .collection('notifications')
            .where('userId', isEqualTo: userId)
            .where('isRead', isEqualTo: false)
            .count()
            .get(),
      ]);

      return {
        'total': results[0].count ?? 0,
        'unread': results[1].count ?? 0,
      };
    } catch (e) {
      print('Error obteniendo estadísticas: $e');
      return {};
    }
  }
}