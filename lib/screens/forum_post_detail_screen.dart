import 'package:flutter/material.dart';
import 'package:policode/models/forum_model.dart';
import 'package:policode/services/auth_service.dart';
import 'package:policode/services/forum_service.dart';
import 'package:policode/widgets/custom_button.dart';
import 'package:policode/widgets/loading_widgets.dart';
import 'package:policode/widgets/forum_widgets.dart';
import 'package:policode/widgets/media_widgets.dart';
import 'package:policode/screens/edit_post_screen.dart';
import 'package:intl/intl.dart';

/// Pantalla de detalle de un post del foro
class ForumPostDetailScreen extends StatefulWidget {
  final ForumPost post;

  const ForumPostDetailScreen({
    super.key,
    required this.post,
  });

  @override
  State<ForumPostDetailScreen> createState() => _ForumPostDetailScreenState();
}

class _ForumPostDetailScreenState extends State<ForumPostDetailScreen> {
  final ForumService _forumService = ForumService();
  final AuthService _authService = AuthService();
  final TextEditingController _replyController = TextEditingController();

  List<ForumReply> _replies = [];
  bool _isLoading = true;
  bool _isSubmittingReply = false;
  late ForumPost _currentPost;

  @override
  void initState() {
    super.initState();
    _currentPost = widget.post;
    _loadReplies();
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _loadReplies() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      final replies = await _forumService.getReplies(_currentPost.id);
      final updatedPost = await _forumService.getPost(_currentPost.id);

      if (mounted) {
        setState(() {
          _replies = replies;
          if (updatedPost != null) _currentPost = updatedPost;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cargando respuestas: $e')),
        );
      }
    }
  }

  Future<void> _submitReply() async {
    if (_replyController.text.trim().isEmpty || !_authService.isSignedIn) {
      return;
    }

    setState(() => _isSubmittingReply = true);

    try {
      final user = _authService.currentUser!;
      final reply = ForumReply(
        id: '',
        postId: _currentPost.id,
        contenido: _replyController.text.trim(),
        autorId: user.uid,
        autorNombre: user.nombre ?? 'Usuario',
        fechaCreacion: DateTime.now(),
        fechaActualizacion: DateTime.now(),
      );

      await _forumService.createReply(reply);
      _replyController.clear();
      _loadReplies(); // Recargar respuestas

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Respuesta publicada')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error publicando respuesta: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmittingReply = false);
      }
    }
  }

  Future<void> _togglePostLike() async {
    if (!_authService.isSignedIn) return;

    try {
      await _forumService.togglePostLike(_currentPost.id, _authService.currentUser!.uid);
      _loadReplies(); // Recargar para actualizar contadores
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _toggleReplyLike(String replyId) async {
    if (!_authService.isSignedIn) return;

    try {
      await _forumService.toggleReplyLike(replyId, _authService.currentUser!.uid);
      _loadReplies(); // Recargar para actualizar contadores
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Discusión'),
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        actions: [
          if (_authService.isSignedIn && 
              _authService.currentUser!.uid == _currentPost.autorId)
            PopupMenuButton<String>(
              onSelected: _handlePostAction,
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 20),
                      SizedBox(width: 12),
                      Text('Editar'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 20, color: Colors.red),
                      SizedBox(width: 12),
                      Text('Eliminar', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: LoadingWidget())
                : RefreshIndicator(
                    onRefresh: _loadReplies,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildPostHeader(),
                          const SizedBox(height: 16),
                          _buildPostContent(),
                          if (_currentPost.mediaAttachments.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            AttachmentsList(attachments: _currentPost.mediaAttachments),
                          ],
                          const SizedBox(height: 24),
                          _buildPostActions(),
                          const SizedBox(height: 32),
                          _buildRepliesSection(),
                        ],
                      ),
                    ),
                  ),
          ),
          if (_authService.isSignedIn) _buildReplyInput(),
        ],
      ),
    );
  }

  Widget _buildPostHeader() {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (_currentPost.isPinned)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.push_pin, size: 16, color: theme.primaryColor),
                    const SizedBox(width: 4),
                    Text(
                      'Fijado',
                      style: TextStyle(
                        color: theme.primaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            if (_currentPost.categoria != null) ...[
              if (_currentPost.isPinned) const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _currentPost.categoria!,
                  style: TextStyle(
                    color: theme.colorScheme.onSecondaryContainer,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Text(
          _currentPost.titulo,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: theme.primaryColor.withOpacity(0.1),
              child: Text(
                _currentPost.autorNombre.isNotEmpty
                    ? _currentPost.autorNombre[0].toUpperCase()
                    : 'U',
                style: TextStyle(
                  color: theme.primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _currentPost.autorNombre,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  DateFormat('dd/MM/yyyy HH:mm').format(_currentPost.fechaCreacion),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPostContent() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.5),
        ),
      ),
      child: Text(
        _currentPost.contenido,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              height: 1.5,
            ),
      ),
    );
  }

  Widget _buildPostActions() {
    final theme = Theme.of(context);

    return Row(
      children: [
        InkWell(
          onTap: _authService.isSignedIn ? _togglePostLike : null,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Icon(
                  Icons.thumb_up_outlined,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  '${_currentPost.likes}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Row(
          children: [
            Icon(
              Icons.comment_outlined,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(
              '${_currentPost.respuestas}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRepliesSection() {
    if (_replies.isEmpty) {
      return Column(
        children: [
          const Divider(),
          const SizedBox(height: 24),
          Text(
            'No hay respuestas aún',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '¡Sé el primero en responder!',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const SizedBox(height: 16),
        Text(
          'Respuestas (${_replies.length})',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _replies.length,
          separatorBuilder: (context, index) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final reply = _replies[index];
            return ForumReplyCard(
              reply: reply,
              onLike: _authService.isSignedIn
                  ? () => _toggleReplyLike(reply.id)
                  : null,
            );
          },
        ),
      ],
    );
  }

  Widget _buildReplyInput() {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.dividerColor),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _replyController,
              decoration: InputDecoration(
                hintText: 'Escribe tu respuesta...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceVariant,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _submitReply(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _isSubmittingReply ? null : _submitReply,
            icon: _isSubmittingReply
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
            style: IconButton.styleFrom(
              backgroundColor: theme.primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _handlePostAction(String action) {
    switch (action) {
      case 'edit':
        _editPost();
        break;
      case 'delete':
        _showDeleteConfirmation();
        break;
    }
  }

  Future<void> _editPost() async {
    final result = await Navigator.push<ForumPost>(
      context,
      MaterialPageRoute(
        builder: (context) => EditPostScreen(post: _currentPost),
      ),
    );

    // Si se actualizó el post, actualizar la UI
    if (result != null) {
      setState(() {
        _currentPost = result;
      });
    }
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Post'),
        content: const Text('¿Estás seguro de que quieres eliminar este post? Esta acción no se puede deshacer.'),
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
                await _forumService.deletePost(_currentPost.id);
                Navigator.pop(context); // Volver a la lista de posts
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Post eliminado')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error eliminando post: $e')),
                );
              }
            },
            size: ButtonSize.small,
          ),
        ],
      ),
    );
  }
}