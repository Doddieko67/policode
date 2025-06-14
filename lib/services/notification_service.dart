import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:equatable/equatable.dart';

/// Modelo para notificaciones
class AppNotification extends Equatable {
  final String id;
  final String userId;
  final String type;
  final String title;
  final String message;
  final bool isRead;
  final DateTime timestamp;
  final Map<String, dynamic>? data;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    required this.isRead,
    required this.timestamp,
    this.data,
  });

  factory AppNotification.fromFirestore(Map<String, dynamic> data) {
    return AppNotification(
      id: data['id'] ?? '',
      userId: data['userId'] ?? '',
      type: data['type'] ?? '',
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      isRead: data['isRead'] ?? false,
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      data: data['data'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'userId': userId,
      'type': type,
      'title': title,
      'message': message,
      'isRead': isRead,
      'timestamp': Timestamp.fromDate(timestamp),
      'data': data,
    };
  }

  AppNotification copyWith({
    String? id,
    String? userId,
    String? type,
    String? title,
    String? message,
    bool? isRead,
    DateTime? timestamp,
    Map<String, dynamic>? data,
  }) {
    return AppNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      isRead: isRead ?? this.isRead,
      timestamp: timestamp ?? this.timestamp,
      data: data ?? this.data,
    );
  }

  @override
  List<Object?> get props => [id, userId, type, title, message, isRead, timestamp, data];
}

/// Servicio de notificaciones
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Obtener notificaciones del usuario actual
  Stream<List<AppNotification>> getUserNotifications() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value([]);

    return _db
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AppNotification.fromFirestore(doc.data()))
            .toList());
  }

  /// Obtener notificaciones no leídas
  Future<int> getUnreadCount() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return 0;

    final snapshot = await _db
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();

    return snapshot.docs.length;
  }

  /// Marcar notificación como leída
  Future<void> markAsRead(String notificationId) async {
    await _db.collection('notifications').doc(notificationId).update({
      'isRead': true,
    });
  }

  /// Marcar todas las notificaciones como leídas
  Future<void> markAllAsRead() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    final snapshot = await _db
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();

    final batch = _db.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  /// Crear notificación de nuevo artículo
  Future<void> createNewArticleNotification({
    required String subscriberId,
    required String authorId,
    required String authorName,
    required String articleId,
    required String articleTitle,
  }) async {
    final notificationRef = _db.collection('notifications').doc();
    await notificationRef.set({
      'id': notificationRef.id,
      'userId': subscriberId,
      'type': 'new_article',
      'title': 'Nuevo artículo',
      'message': '$authorName publicó: "$articleTitle"',
      'isRead': false,
      'timestamp': FieldValue.serverTimestamp(),
      'data': {
        'authorId': authorId,
        'articleId': articleId,
        'articleTitle': articleTitle,
      },
    });
  }

  /// Crear notificación de nuevo post en foro
  Future<void> createNewPostNotification({
    required String subscriberId,
    required String authorId,
    required String authorName,
    required String postId,
    required String postTitle,
  }) async {
    final notificationRef = _db.collection('notifications').doc();
    await notificationRef.set({
      'id': notificationRef.id,
      'userId': subscriberId,
      'type': 'new_post',
      'title': 'Nuevo post en el foro',
      'message': '$authorName publicó: "$postTitle"',
      'isRead': false,
      'timestamp': FieldValue.serverTimestamp(),
      'data': {
        'authorId': authorId,
        'postId': postId,
        'postTitle': postTitle,
      },
    });
  }

  /// Eliminar notificación
  Future<void> deleteNotification(String notificationId) async {
    await _db.collection('notifications').doc(notificationId).delete();
  }

  /// Limpiar notificaciones antiguas (más de 30 días)
  Future<void> cleanOldNotifications() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    
    final snapshot = await _db
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('timestamp', isLessThan: Timestamp.fromDate(thirtyDaysAgo))
        .get();

    final batch = _db.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}