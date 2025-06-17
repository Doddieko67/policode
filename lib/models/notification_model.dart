import 'package:cloud_firestore/cloud_firestore.dart';

/// Tipos de notificaciones disponibles
enum NotificationType {
  postReply('post_reply'),           // Alguien respondió a tu post
  postLiked('post_liked'),           // Alguien le dio like a tu post
  replyLiked('reply_liked'),         // Alguien le dio like a tu respuesta
  adminComment('admin_comment'),     // Un admin comentó en tu post
  postPinned('post_pinned'),         // Tu post fue fijado por un admin
  postLocked('post_locked'),         // Tu post fue cerrado por un admin
  postDeleted('post_deleted'),       // Tu post fue eliminado por un admin
  replyDeleted('reply_deleted'),     // Tu respuesta fue eliminada por un admin
  userSuspended('user_suspended'),   // Tu cuenta fue suspendida
  userReactivated('user_reactivated'), // Tu cuenta fue reactivada
  systemMessage('system_message'),   // Mensaje del sistema
  generalAnnouncement('general_announcement'); // Anuncio general

  const NotificationType(this.value);
  final String value;

  static NotificationType fromString(String value) {
    return NotificationType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => NotificationType.systemMessage,
    );
  }
}

/// Prioridad de la notificación
enum NotificationPriority {
  low('low'),
  medium('medium'),
  high('high'),
  urgent('urgent');

  const NotificationPriority(this.value);
  final String value;

  static NotificationPriority fromString(String value) {
    return NotificationPriority.values.firstWhere(
      (priority) => priority.value == value,
      orElse: () => NotificationPriority.medium,
    );
  }
}

/// Modelo para notificaciones
class NotificationModel {
  final String id;
  final String userId;
  final NotificationType type;
  final String title;
  final String message;
  final NotificationPriority priority;
  final bool isRead;
  final DateTime createdAt;
  final DateTime? readAt;
  
  // Datos adicionales según el tipo de notificación
  final String? postId;        // ID del post relacionado
  final String? replyId;       // ID de la respuesta relacionada
  final String? fromUserId;    // ID del usuario que generó la notificación
  final String? fromUserName;  // Nombre del usuario que generó la notificación
  final String? actionUrl;     // URL para navegar cuando se toque la notificación
  final Map<String, dynamic>? metadata; // Datos adicionales

  const NotificationModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    required this.priority,
    required this.isRead,
    required this.createdAt,
    this.readAt,
    this.postId,
    this.replyId,
    this.fromUserId,
    this.fromUserName,
    this.actionUrl,
    this.metadata,
  });

  /// Crear desde Firestore
  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return NotificationModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      type: NotificationType.fromString(data['type'] ?? ''),
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      priority: NotificationPriority.fromString(data['priority'] ?? 'medium'),
      isRead: data['isRead'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      readAt: (data['readAt'] as Timestamp?)?.toDate(),
      postId: data['postId'],
      replyId: data['replyId'],
      fromUserId: data['fromUserId'],
      fromUserName: data['fromUserName'],
      actionUrl: data['actionUrl'],
      metadata: data['metadata']?.cast<String, dynamic>(),
    );
  }

  /// Convertir a Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'type': type.value,
      'title': title,
      'message': message,
      'priority': priority.value,
      'isRead': isRead,
      'createdAt': Timestamp.fromDate(createdAt),
      'readAt': readAt != null ? Timestamp.fromDate(readAt!) : null,
      'postId': postId,
      'replyId': replyId,
      'fromUserId': fromUserId,
      'fromUserName': fromUserName,
      'actionUrl': actionUrl,
      'metadata': metadata,
    };
  }

  /// Crear copia con cambios
  NotificationModel copyWith({
    String? id,
    String? userId,
    NotificationType? type,
    String? title,
    String? message,
    NotificationPriority? priority,
    bool? isRead,
    DateTime? createdAt,
    DateTime? readAt,
    String? postId,
    String? replyId,
    String? fromUserId,
    String? fromUserName,
    String? actionUrl,
    Map<String, dynamic>? metadata,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      priority: priority ?? this.priority,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      readAt: readAt ?? this.readAt,
      postId: postId ?? this.postId,
      replyId: replyId ?? this.replyId,
      fromUserId: fromUserId ?? this.fromUserId,
      fromUserName: fromUserName ?? this.fromUserName,
      actionUrl: actionUrl ?? this.actionUrl,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Marcar como leída
  NotificationModel markAsRead() {
    return copyWith(
      isRead: true,
      readAt: DateTime.now(),
    );
  }

  /// Obtener icono según el tipo
  String get iconName {
    switch (type) {
      case NotificationType.postReply:
        return 'chat_bubble_outline';
      case NotificationType.postLiked:
      case NotificationType.replyLiked:
        return 'favorite';
      case NotificationType.adminComment:
        return 'admin_panel_settings';
      case NotificationType.postPinned:
        return 'push_pin';
      case NotificationType.postLocked:
        return 'lock';
      case NotificationType.postDeleted:
      case NotificationType.replyDeleted:
        return 'delete';
      case NotificationType.userSuspended:
        return 'block';
      case NotificationType.userReactivated:
        return 'check_circle';
      case NotificationType.systemMessage:
        return 'info';
      case NotificationType.generalAnnouncement:
        return 'campaign';
    }
  }

  /// Obtener color según prioridad
  String get priorityColor {
    switch (priority) {
      case NotificationPriority.low:
        return 'grey';
      case NotificationPriority.medium:
        return 'blue';
      case NotificationPriority.high:
        return 'orange';
      case NotificationPriority.urgent:
        return 'red';
    }
  }

  /// Verificar si es una notificación del sistema/admin
  bool get isSystemNotification {
    return type == NotificationType.adminComment ||
           type == NotificationType.postPinned ||
           type == NotificationType.postLocked ||
           type == NotificationType.postDeleted ||
           type == NotificationType.replyDeleted ||
           type == NotificationType.userSuspended ||
           type == NotificationType.userReactivated ||
           type == NotificationType.systemMessage ||
           type == NotificationType.generalAnnouncement;
  }

  /// Verificar si es una notificación social (de otros usuarios)
  bool get isSocialNotification {
    return type == NotificationType.postReply ||
           type == NotificationType.postLiked ||
           type == NotificationType.replyLiked;
  }

  /// Verificar si la notificación está expirada (más de 30 días)
  bool get isExpired {
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    return createdAt.isBefore(thirtyDaysAgo);
  }

  /// Obtener tiempo relativo (ej: "hace 2 horas")
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 0) {
      return 'hace ${difference.inDays} día${difference.inDays > 1 ? 's' : ''}';
    } else if (difference.inHours > 0) {
      return 'hace ${difference.inHours} hora${difference.inHours > 1 ? 's' : ''}';
    } else if (difference.inMinutes > 0) {
      return 'hace ${difference.inMinutes} minuto${difference.inMinutes > 1 ? 's' : ''}';
    } else {
      return 'hace un momento';
    }
  }

  @override
  String toString() {
    return 'NotificationModel(id: $id, type: $type, title: $title, isRead: $isRead)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NotificationModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Factory para crear notificaciones específicas
class NotificationFactory {
  
  /// Notificación de nueva respuesta a post
  static NotificationModel createPostReplyNotification({
    required String userId,
    required String postId,
    required String postTitle,
    required String fromUserId,
    required String fromUserName,
  }) {
    return NotificationModel(
      id: '', // Se asigna en Firestore
      userId: userId,
      type: NotificationType.postReply,
      title: 'Nueva respuesta',
      message: '$fromUserName respondió a tu post "$postTitle"',
      priority: NotificationPriority.medium,
      isRead: false,
      createdAt: DateTime.now(),
      postId: postId,
      fromUserId: fromUserId,
      fromUserName: fromUserName,
      actionUrl: '/forum-post-detail?postId=$postId',
    );
  }

  /// Notificación de like en post
  static NotificationModel createPostLikedNotification({
    required String userId,
    required String postId,
    required String postTitle,
    required String fromUserId,
    required String fromUserName,
  }) {
    return NotificationModel(
      id: '',
      userId: userId,
      type: NotificationType.postLiked,
      title: 'Like en tu post',
      message: 'A $fromUserName le gustó tu post "$postTitle"',
      priority: NotificationPriority.low,
      isRead: false,
      createdAt: DateTime.now(),
      postId: postId,
      fromUserId: fromUserId,
      fromUserName: fromUserName,
      actionUrl: '/forum-post-detail?postId=$postId',
    );
  }

  /// Notificación de comentario de admin
  static NotificationModel createAdminCommentNotification({
    required String userId,
    required String postId,
    required String postTitle,
    required String adminMessage,
  }) {
    return NotificationModel(
      id: '',
      userId: userId,
      type: NotificationType.adminComment,
      title: 'Comentario oficial',
      message: 'Un administrador comentó en tu post "$postTitle": $adminMessage',
      priority: NotificationPriority.high,
      isRead: false,
      createdAt: DateTime.now(),
      postId: postId,
      fromUserName: 'Administrador',
      actionUrl: '/forum-post-detail?postId=$postId',
      metadata: {'adminMessage': adminMessage},
    );
  }

  /// Notificación de post eliminado
  static NotificationModel createPostDeletedNotification({
    required String userId,
    required String postTitle,
    required String reason,
  }) {
    return NotificationModel(
      id: '',
      userId: userId,
      type: NotificationType.postDeleted,
      title: 'Post eliminado',
      message: 'Tu post "$postTitle" fue eliminado por un administrador. Razón: $reason',
      priority: NotificationPriority.urgent,
      isRead: false,
      createdAt: DateTime.now(),
      fromUserName: 'Administrador',
      metadata: {'reason': reason, 'postTitle': postTitle},
    );
  }

  /// Notificación de suspensión
  static NotificationModel createUserSuspendedNotification({
    required String userId,
    required String reason,
    required DateTime suspendedUntil,
  }) {
    return NotificationModel(
      id: '',
      userId: userId,
      type: NotificationType.userSuspended,
      title: 'Cuenta suspendida',
      message: 'Tu cuenta ha sido suspendida hasta ${suspendedUntil.day}/${suspendedUntil.month}/${suspendedUntil.year}. Razón: $reason',
      priority: NotificationPriority.urgent,
      isRead: false,
      createdAt: DateTime.now(),
      fromUserName: 'Administrador',
      metadata: {
        'reason': reason,
        'suspendedUntil': suspendedUntil.toIso8601String(),
      },
    );
  }

  /// Notificación de anuncio general
  static NotificationModel createGeneralAnnouncementNotification({
    required List<String> targetUserIds, // Se creará una para cada usuario
    required String title,
    required String message,
    NotificationPriority priority = NotificationPriority.medium,
    String? actionUrl,
  }) {
    return NotificationModel(
      id: '',
      userId: '', // Se asigna individualmente
      type: NotificationType.generalAnnouncement,
      title: title,
      message: message,
      priority: priority,
      isRead: false,
      createdAt: DateTime.now(),
      fromUserName: 'Sistema PoliCode',
      actionUrl: actionUrl,
    );
  }
}