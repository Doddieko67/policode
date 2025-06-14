import 'package:flutter/material.dart';
import 'package:policode/models/private_chat_model.dart';
import 'package:policode/services/private_chat_service.dart';
import 'package:policode/services/auth_service.dart';
import 'package:policode/widgets/loading_widgets.dart';
import 'package:policode/widgets/custom_button.dart';
import 'package:timeago/timeago.dart' as timeago;

class ChatsListScreen extends StatefulWidget {
  const ChatsListScreen({super.key});

  @override
  State<ChatsListScreen> createState() => _ChatsListScreenState();
}

class _ChatsListScreenState extends State<ChatsListScreen> {
  final PrivateChatService _chatService = PrivateChatService();
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();

  bool _isSearching = false;
  List<Map<String, dynamic>> _searchResults = [];

  @override
  void initState() {
    super.initState();
    timeago.setLocaleMessages('es', timeago.EsMessages());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _showSearchDialog,
          ),
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'new_chat',
                child: Row(
                  children: [
                    Icon(Icons.chat),
                    SizedBox(width: 8),
                    Text('Nuevo chat'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'mark_all_read',
                child: Row(
                  children: [
                    Icon(Icons.mark_chat_read),
                    SizedBox(width: 8),
                    Text('Marcar todo como leído'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: StreamBuilder<List<PrivateChat>>(
        stream: _chatService.getUserChats(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: LoadingWidget());
          }

          if (snapshot.hasError) {
            return Center(
              child: CustomErrorWidget.generic(
                title: 'Error',
                message: 'Error cargando chats: ${snapshot.error}',
                onRetry: () => setState(() {}),
              ),
            );
          }

          final chats = snapshot.data ?? [];

          if (chats.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            itemCount: chats.length,
            itemBuilder: (context, index) {
              return _buildChatTile(chats[index]);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showSearchDialog,
        child: const Icon(Icons.chat),
        tooltip: 'Nuevo chat',
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 80,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'No tienes chats aún',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Busca usuarios y empieza una conversación',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          CustomButton(
            text: 'Buscar usuarios',
            onPressed: _showSearchDialog,
            icon: Icons.search,
          ),
        ],
      ),
    );
  }

  Widget _buildChatTile(PrivateChat chat) {
    final theme = Theme.of(context);
    final currentUserId = _authService.currentUser?.uid ?? '';
    
    // Obtener información del otro usuario
    final otherUserId = chat.participantIds.firstWhere((id) => id != currentUserId);
    final otherUserName = chat.participantNames[otherUserId] ?? 'Usuario';
    final unreadCount = chat.unreadCount[currentUserId] ?? 0;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primaryContainer,
        child: Text(
          chat.isGroup 
              ? (chat.groupName?.substring(0, 1).toUpperCase() ?? 'G')
              : otherUserName.substring(0, 1).toUpperCase(),
          style: TextStyle(
            color: theme.colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(
        chat.isGroup ? (chat.groupName ?? 'Grupo') : otherUserName,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: chat.lastMessage != null
          ? Text(
              chat.lastMessage!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: unreadCount > 0 
                    ? theme.colorScheme.onSurface 
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
              ),
            )
          : Text(
              'Toca para enviar un mensaje',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            timeago.format(chat.lastActivity, locale: 'es'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (unreadCount > 0) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(minWidth: 20),
              child: Text(
                unreadCount > 99 ? '99+' : unreadCount.toString(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
      onTap: () => _openChat(chat),
      onLongPress: () => _showChatOptions(chat),
    );
  }

  void _openChat(PrivateChat chat) {
    Navigator.pushNamed(
      context,
      '/private-chat',
      arguments: chat.id,
    ).then((_) {
      // Marcar como leído cuando regrese del chat
      _chatService.markMessagesAsRead(chat.id);
    });
  }

  void _showChatOptions(PrivateChat chat) {
    final theme = Theme.of(context);
    
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.mark_chat_read),
              title: const Text('Marcar como leído'),
              onTap: () {
                Navigator.pop(context);
                _chatService.markMessagesAsRead(chat.id);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete, color: theme.colorScheme.error),
              title: Text(
                'Eliminar chat',
                style: TextStyle(color: theme.colorScheme.error),
              ),
              onTap: () {
                Navigator.pop(context);
                _confirmDeleteChat(chat);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteChat(PrivateChat chat) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar chat'),
        content: const Text('¿Estás seguro? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          CustomButton.danger(
            text: 'Eliminar',
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _chatService.deleteChat(chat.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Chat eliminado')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            size: ButtonSize.small,
          ),
        ],
      ),
    );
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Buscar usuarios'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Nombre del usuario...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: _searchUsers,
            ),
            const SizedBox(height: 16),
            if (_isSearching)
              const CircularProgressIndicator()
            else if (_searchResults.isNotEmpty)
              SizedBox(
                height: 200,
                width: double.maxFinite,
                child: ListView.builder(
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final user = _searchResults[index];
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(user['nombre'].toString().substring(0, 1).toUpperCase()),
                      ),
                      title: Text(user['nombre']),
                      subtitle: Text(user['email']),
                      onTap: () {
                        Navigator.pop(context);
                        _startChat(user['id'], user['nombre']);
                      },
                    );
                  },
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _searchController.clear();
              _searchResults.clear();
              Navigator.pop(context);
            },
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  Future<void> _searchUsers(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults.clear());
      return;
    }

    setState(() => _isSearching = true);

    try {
      final results = await _chatService.searchUsers(query);
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() => _isSearching = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error buscando usuarios: $e')),
      );
    }
  }

  Future<void> _startChat(String userId, String userName) async {
    try {
      final chatId = await _chatService.createOrGetChat(userId, userName);
      Navigator.pushNamed(
        context,
        '/private-chat',
        arguments: chatId,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error iniciando chat: $e')),
      );
    }
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'new_chat':
        _showSearchDialog();
        break;
      case 'mark_all_read':
        _markAllAsRead();
        break;
    }
  }

  Future<void> _markAllAsRead() async {
    // Implementar marcar todos como leídos
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Todos los chats marcados como leídos')),
    );
  }
}