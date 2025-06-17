import 'package:flutter/material.dart';
import 'package:policode/models/forum_model.dart';
import 'package:policode/services/auth_service.dart';
import 'package:policode/services/forum_service.dart';
import 'package:policode/services/media_service.dart';
import 'package:policode/widgets/custom_button.dart';
import 'package:policode/widgets/loading_widgets.dart';
import 'package:policode/widgets/forum_widgets.dart';
import 'package:policode/widgets/media_widgets.dart';
import 'package:policode/screens/edit_post_screen.dart';
import 'package:policode/screens/edit_reply_screen.dart';
import 'package:intl/intl.dart';
import 'dart:io';

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
  final MediaService _mediaService = MediaService();
  final TextEditingController _replyController = TextEditingController();

  List<ForumReply> _replies = [];
  List<File> _selectedFiles = [];
  List<MediaAttachment> _uploadedMedia = [];
  bool _isLoading = true;
  bool _isSubmittingReply = false;
  late ForumPost _currentPost;
  bool? _hasUserLiked;
  Map<String, bool> _replyLikes = {}; // Track reply likes locally

  @override
  void initState() {
    super.initState();
    _currentPost = widget.post;
    _loadReplies();
    _loadLikeStatus();
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _pickMedia() async {
    final files = await _mediaService.pickMultipleMedia();
    if (files.isNotEmpty) {
      setState(() {
        _selectedFiles.addAll(files);
      });
    }
  }

  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });
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
        
        // Load reply likes status
        _loadReplyLikes();
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
      // Subir archivos multimedia si hay alguno seleccionado
      final mediaAttachments = <MediaAttachment>[];
      if (_selectedFiles.isNotEmpty) {
        for (final file in _selectedFiles) {
          final attachment = await _mediaService.uploadForumMedia(
            file: file,
            userId: _authService.currentUser!.uid,
            postId: _currentPost.id,
          );
          if (attachment != null) {
            mediaAttachments.add(attachment);
          }
        }
      }

      final user = _authService.currentUser!;
      final reply = ForumReply(
        id: '',
        postId: _currentPost.id,
        contenido: _replyController.text.trim(),
        autorId: user.uid,
        autorNombre: user.nombre ?? 'Usuario',
        fechaCreacion: DateTime.now(),
        fechaActualizacion: DateTime.now(),
        mediaAttachments: mediaAttachments,
      );

      await _forumService.createReply(reply);
      _replyController.clear();
      setState(() {
        _selectedFiles.clear();
        _uploadedMedia.clear();
      });
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

  Future<void> _loadLikeStatus() async {
    if (!_authService.isSignedIn) return;
    
    try {
      final hasLiked = await _forumService.hasUserLikedPost(_currentPost.id, _authService.currentUser!.uid);
      if (mounted) {
        setState(() {
          _hasUserLiked = hasLiked;
        });
      }
    } catch (e) {
      // Error silencioso para el estado del like
    }
  }

  Future<void> _loadReplyLikes() async {
    if (!_authService.isSignedIn) return;
    
    try {
      final Map<String, bool> likes = {};
      for (final reply in _replies) {
        final hasLiked = await _forumService.hasUserLikedReply(reply.id, _authService.currentUser!.uid);
        likes[reply.id] = hasLiked;
      }
      
      if (mounted) {
        setState(() {
          _replyLikes = likes;
        });
      }
    } catch (e) {
      // Error silencioso para el estado del like
    }
  }

  Future<void> _togglePostLike() async {
    if (!_authService.isSignedIn || _hasUserLiked == null) return;

    // Optimistic update - actualizar UI inmediatamente
    final wasLiked = _hasUserLiked!;
    
    setState(() {
      _hasUserLiked = !wasLiked;
      _currentPost = _currentPost.copyWith(
        likes: wasLiked ? _currentPost.likes - 1 : _currentPost.likes + 1,
      );
    });

    try {
      // Actualizar en servidor
      await _forumService.togglePostLike(_currentPost.id, _authService.currentUser!.uid);
    } catch (e) {
      // Si hay error, revertir el cambio optimista
      setState(() {
        _hasUserLiked = wasLiked;
        _currentPost = _currentPost.copyWith(
          likes: wasLiked ? _currentPost.likes + 1 : _currentPost.likes - 1,
        );
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _toggleReplyLike(String replyId) async {
    if (!_authService.isSignedIn || !_replyLikes.containsKey(replyId)) return;

    // Optimistic update - actualizar UI inmediatamente
    final wasLiked = _replyLikes[replyId]!;
    final replyIndex = _replies.indexWhere((r) => r.id == replyId);
    
    if (replyIndex == -1) return;
    
    setState(() {
      _replyLikes[replyId] = !wasLiked;
      _replies[replyIndex] = _replies[replyIndex].copyWith(
        likes: wasLiked ? _replies[replyIndex].likes - 1 : _replies[replyIndex].likes + 1,
      );
    });

    try {
      // Actualizar en servidor
      await _forumService.toggleReplyLike(replyId, _authService.currentUser!.uid);
    } catch (e) {
      // Si hay error, revertir el cambio optimista
      setState(() {
        _replyLikes[replyId] = wasLiked;
        _replies[replyIndex] = _replies[replyIndex].copyWith(
          likes: wasLiked ? _replies[replyIndex].likes + 1 : _replies[replyIndex].likes - 1,
        );
      });
      
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
        centerTitle: true,
        actions: [
          if (_authService.isSignedIn)
            PopupMenuButton<String>(
              onSelected: _handlePostAction,
              itemBuilder: (context) => [
                if (_authService.currentUser!.uid == _currentPost.autorId) ...[
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
                if (_authService.currentUser!.uid != _currentPost.autorId)
                  const PopupMenuItem(
                    value: 'report',
                    child: Row(
                      children: [
                        Icon(Icons.report, size: 20, color: Colors.orange),
                        SizedBox(width: 12),
                        Text('Reportar', style: TextStyle(color: Colors.orange)),
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
          onTap: _authService.isSignedIn && _hasUserLiked != null ? _togglePostLike : null,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Icon(
                  (_hasUserLiked ?? false) ? Icons.thumb_up : Icons.thumb_up_outlined,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  '${_currentPost.likes}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
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
              hasUserLiked: _replyLikes[reply.id],
              onEdit: _authService.isSignedIn && 
                      _authService.currentUser!.uid == reply.autorId
                  ? () => _editReply(reply)
                  : null,
              onDelete: _authService.isSignedIn && 
                        _authService.currentUser!.uid == reply.autorId
                    ? () => _deleteReply(reply.id)
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Mostrar archivos seleccionados
          if (_selectedFiles.isNotEmpty) ...[
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _selectedFiles.length,
                itemBuilder: (context, index) {
                  final file = _selectedFiles[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Stack(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: theme.colorScheme.outline.withOpacity(0.3),
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: _isImageFile(file.path)
                                ? Image.file(
                                    file,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return const Center(
                                        child: Icon(Icons.broken_image),
                                      );
                                    },
                                  )
                                : Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          _getFileIcon(file.path),
                                          size: 32,
                                          color: theme.colorScheme.primary,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          file.path.split('/').last,
                                          style: theme.textTheme.labelSmall,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                          ),
                        ),
                        Positioned(
                          top: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: () => _removeFile(index),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.error,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              IconButton(
                onPressed: _pickMedia,
                icon: const Icon(Icons.attach_file),
                tooltip: 'Adjuntar archivo',
              ),
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
        ],
      ),
    );
  }

  bool _isImageFile(String path) {
    return _mediaService.isImageFile(path);
  }

  IconData _getFileIcon(String path) {
    if (_mediaService.isVideoFile(path)) {
      return Icons.video_file;
    } else if (_mediaService.isImageFile(path)) {
      return Icons.image;
    } else {
      final ext = path.split('.').last.toLowerCase();
      if (['pdf'].contains(ext)) {
        return Icons.picture_as_pdf;
      } else if (['doc', 'docx'].contains(ext)) {
        return Icons.description;
      } else {
        return Icons.insert_drive_file;
      }
    }
  }

  void _handlePostAction(String action) {
    switch (action) {
      case 'edit':
        _editPost();
        break;
      case 'delete':
        _showDeleteConfirmation();
        break;
      case 'report':
        _showReportDialog();
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

  void _showReportDialog() {
    final TextEditingController reasonController = TextEditingController();
    String selectedReason = 'spam';
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Reportar Post'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('¿Por qué quieres reportar este post?'),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedReason,
                items: const [
                  DropdownMenuItem(value: 'spam', child: Text('Spam')),
                  DropdownMenuItem(value: 'harassment', child: Text('Acoso')),
                  DropdownMenuItem(value: 'inappropriate', child: Text('Contenido inapropiado')),
                  DropdownMenuItem(value: 'misinformation', child: Text('Información falsa')),
                  DropdownMenuItem(value: 'other', child: Text('Otro')),
                ],
                onChanged: (value) {
                  setState(() {
                    selectedReason = value!;
                  });
                },
                decoration: const InputDecoration(
                  labelText: 'Razón',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Detalles adicionales (opcional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  // Aquí agregarías la lógica para enviar el reporte
                  // await _forumService.reportPost(_currentPost.id, selectedReason, reasonController.text);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Post reportado. Gracias por tu colaboración.')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error reportando post: $e')),
                  );
                }
              },
              child: const Text('Reportar'),
            ),
          ],
        ),
      ),
    );
  }

  void _editReply(ForumReply reply) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => EditReplyScreen(reply: reply),
      ),
    );

    // Si se editó exitosamente, recargar las respuestas
    if (result == true) {
      _loadReplies();
    }
  }

  void _deleteReply(String replyId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar respuesta'),
        content: const Text('¿Estás seguro de que quieres eliminar esta respuesta?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _forumService.deleteReply(replyId, _currentPost.id);
                _loadReplies(); // Recargar respuestas
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Respuesta eliminada')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error eliminando respuesta: $e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}