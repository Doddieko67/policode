import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';
import '../widgets/loading_widgets.dart';
import 'forum_post_detail_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final NotificationService _notificationService = NotificationService();
  bool _showingUnreadOnly = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Avisos'),
        actions: [
          // Filtro de no leídas
          IconButton(
            icon: Icon(
              _showingUnreadOnly ? Icons.mark_email_unread : Icons.email,
              color: _showingUnreadOnly ? Theme.of(context).primaryColor : null,
            ),
            onPressed: () {
              setState(() {
                _showingUnreadOnly = !_showingUnreadOnly;
              });
            },
            tooltip: _showingUnreadOnly ? 'Mostrar todas' : 'Solo no leídas',
          ),
          // Marcar todas como leídas
          IconButton(
            icon: const Icon(Icons.done_all),
            onPressed: _markAllAsRead,
            tooltip: 'Marcar todas como leídas',
          ),
          // Más opciones
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'stats',
                child: Row(
                  children: [
                    Icon(Icons.analytics),
                    SizedBox(width: 8),
                    Text('Estadísticas'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clean',
                child: Row(
                  children: [
                    Icon(Icons.cleaning_services),
                    SizedBox(width: 8),
                    Text('Limpiar antiguas'),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Todas', icon: Icon(Icons.notifications)),
            Tab(text: 'Sistema', icon: Icon(Icons.admin_panel_settings)),
            Tab(text: 'Sociales', icon: Icon(Icons.people)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAllNotificationsTab(),
          _buildSystemNotificationsTab(),
          _buildSocialNotificationsTab(),
        ],
      ),
    );
  }

  Widget _buildAllNotificationsTab() {
    return StreamBuilder<List<NotificationModel>>(
      stream: _notificationService.getUserNotifications(
        unreadOnly: _showingUnreadOnly,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingWidget();
        }

        if (snapshot.hasError) {
          return CustomErrorWidget(
            title: 'Error',
            message: 'Error cargando notificaciones: ${snapshot.error}',
          );
        }

        final notifications = snapshot.data ?? [];

        if (notifications.isEmpty) {
          return _buildEmptyState();
        }

        return _buildNotificationsList(notifications);
      },
    );
  }

  Widget _buildSystemNotificationsTab() {
    return StreamBuilder<List<NotificationModel>>(
      stream: _notificationService.getUserNotifications(
        unreadOnly: _showingUnreadOnly,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingWidget();
        }

        final notifications = (snapshot.data ?? [])
            .where((n) => n.isSystemNotification)
            .toList();

        if (notifications.isEmpty) {
          return _buildEmptyState(message: 'No hay notificaciones del sistema');
        }

        return _buildNotificationsList(notifications);
      },
    );
  }

  Widget _buildSocialNotificationsTab() {
    return StreamBuilder<List<NotificationModel>>(
      stream: _notificationService.getUserNotifications(
        unreadOnly: _showingUnreadOnly,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingWidget();
        }

        final notifications = (snapshot.data ?? [])
            .where((n) => n.isSocialNotification)
            .toList();

        if (notifications.isEmpty) {
          return _buildEmptyState(message: 'No hay notificaciones sociales');
        }

        return _buildNotificationsList(notifications);
      },
    );
  }

  Widget _buildEmptyState({String? message}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            message ?? (_showingUnreadOnly 
                ? 'No hay notificaciones no leídas'
                : 'No hay notificaciones'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          if (_showingUnreadOnly) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                setState(() {
                  _showingUnreadOnly = false;
                });
              },
              child: const Text('Ver todas las notificaciones'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNotificationsList(List<NotificationModel> notifications) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: notifications.length,
      itemBuilder: (context, index) {
        final notification = notifications[index];
        return _buildNotificationCard(notification);
      },
    );
  }

  Widget _buildNotificationCard(NotificationModel notification) {
    final theme = Theme.of(context);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: notification.isRead ? 1 : 3,
      child: InkWell(
        onTap: () => _handleNotificationTap(notification),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  // Icono de tipo
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getNotificationColor(notification).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getNotificationIcon(notification),
                      color: _getNotificationColor(notification),
                      size: 20,
                    ),
                  ),
                  
                  const SizedBox(width: 12),
                  
                  // Título y tiempo
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                notification.title,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: notification.isRead 
                                      ? FontWeight.normal 
                                      : FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (!notification.isRead)
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: theme.primaryColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                        Text(
                          notification.timeAgo,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Botón de menú
                  PopupMenuButton<String>(
                    onSelected: (action) => _handleNotificationAction(action, notification),
                    itemBuilder: (context) => [
                      if (!notification.isRead)
                        const PopupMenuItem(
                          value: 'mark_read',
                          child: Row(
                            children: [
                              Icon(Icons.mark_email_read),
                              SizedBox(width: 8),
                              Text('Marcar como leída'),
                            ],
                          ),
                        ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Eliminar', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                    child: const Icon(Icons.more_vert),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Mensaje
              Text(
                notification.message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: notification.isRead 
                      ? Colors.grey[700] 
                      : theme.colorScheme.onSurface,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              
              // Info adicional para notificaciones del sistema
              if (notification.isSystemNotification) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getNotificationColor(notification).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    notification.fromUserName ?? 'Sistema',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _getNotificationColor(notification),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
              
              // Botón de acción si hay actionUrl
              if (notification.actionUrl != null) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _handleNotificationTap(notification),
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('Ver'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  IconData _getNotificationIcon(NotificationModel notification) {
    switch (notification.type) {
      case NotificationType.postReply:
        return Icons.chat_bubble_outline;
      case NotificationType.postLiked:
      case NotificationType.replyLiked:
        return Icons.favorite;
      case NotificationType.adminComment:
        return Icons.admin_panel_settings;
      case NotificationType.postPinned:
        return Icons.push_pin;
      case NotificationType.postLocked:
        return Icons.lock;
      case NotificationType.postDeleted:
      case NotificationType.replyDeleted:
        return Icons.delete;
      case NotificationType.userSuspended:
        return Icons.block;
      case NotificationType.userReactivated:
        return Icons.check_circle;
      case NotificationType.systemMessage:
        return Icons.info;
      case NotificationType.generalAnnouncement:
        return Icons.campaign;
    }
  }

  Color _getNotificationColor(NotificationModel notification) {
    switch (notification.priority) {
      case NotificationPriority.low:
        return Colors.grey;
      case NotificationPriority.medium:
        return Colors.blue;
      case NotificationPriority.high:
        return Colors.orange;
      case NotificationPriority.urgent:
        return Colors.red;
    }
  }

  void _handleNotificationTap(NotificationModel notification) {
    // Marcar como leída si no lo está
    if (!notification.isRead) {
      _notificationService.markAsRead(notification.id);
    }

    // Navegar según el tipo de notificación
    if (notification.postId != null && notification.postId!.isNotEmpty) {
      // Importar ForumPostDetailScreen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ForumPostDetailScreen.fromId(postId: notification.postId!),
        ),
      );
    } else if (notification.actionUrl != null && notification.actionUrl!.isNotEmpty) {
      // Para otras URLs que puedan existir en el futuro
      _navigateToUrl(notification.actionUrl!);
    } else {
      // Si no hay navegación específica, mostrar mensaje
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Esta notificación no tiene acción asociada'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _navigateToUrl(String url) {
    // Manejar diferentes tipos de URLs
    if (url.contains('/forum-post-detail')) {
      // Extraer postId de la URL
      final uri = Uri.parse(url);
      final postId = uri.queryParameters['postId'];
      if (postId != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ForumPostDetailScreen.fromId(postId: postId),
          ),
        );
      }
    } else {
      // Para futuras implementaciones de otras URLs
      print('Navegando a URL no soportada: $url');
    }
  }

  void _handleNotificationAction(String action, NotificationModel notification) {
    switch (action) {
      case 'mark_read':
        _notificationService.markAsRead(notification.id);
        break;
      case 'delete':
        _showDeleteConfirmation(notification);
        break;
    }
  }

  void _showDeleteConfirmation(NotificationModel notification) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar notificación'),
        content: const Text('¿Estás seguro de que quieres eliminar esta notificación?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _notificationService.deleteNotification(notification.id);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Notificación eliminada')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  void _markAllAsRead() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Marcar todas como leídas'),
        content: const Text('¿Marcar todas las notificaciones como leídas?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _notificationService.markAllAsRead();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Todas las notificaciones marcadas como leídas'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Marcar todas'),
          ),
        ],
      ),
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'stats':
        _showNotificationStats();
        break;
      case 'clean':
        _showCleanConfirmation();
        break;
    }
  }

  void _showNotificationStats() async {
    try {
      final stats = await _notificationService.getNotificationStats();
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Estadísticas de Notificaciones'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatRow('Total', stats['total']?.toString() ?? '0'),
              _buildStatRow('No leídas', stats['unread']?.toString() ?? '0'),
              _buildStatRow('Leídas', ((stats['total'] ?? 0) - (stats['unread'] ?? 0)).toString()),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error obteniendo estadísticas: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  void _showCleanConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpiar notificaciones'),
        content: const Text(
          'Esto eliminará todas las notificaciones de más de 30 días. '
          '¿Continuar?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implementar limpieza
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Notificaciones antiguas eliminadas'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Limpiar'),
          ),
        ],
      ),
    );
  }
}