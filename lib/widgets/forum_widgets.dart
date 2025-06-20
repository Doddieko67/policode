import 'package:flutter/material.dart';
import 'package:policode/models/forum_model.dart';
import 'package:policode/models/report_model.dart';
import 'package:policode/services/auth_service.dart';
import 'package:policode/services/forum_service.dart';
import 'package:policode/services/admin_service.dart';
import 'package:policode/widgets/custom_button.dart';
import 'package:policode/widgets/media_widgets.dart';
import 'package:policode/widgets/user_avatar.dart';
import 'package:intl/intl.dart';

/// Widget para mostrar un post del foro en lista
class ForumPostCard extends StatefulWidget {
  final ForumPost post;
  final VoidCallback? onTap;
  final VoidCallback? onLike;
  final bool showPopularityBadge;
  final String? currentUserId;

  const ForumPostCard({
    super.key,
    required this.post,
    this.onTap,
    this.onLike,
    this.showPopularityBadge = false,
    this.currentUserId,
  });

  @override
  State<ForumPostCard> createState() => _ForumPostCardState();
}

class _ForumPostCardState extends State<ForumPostCard> {
  final ForumService _forumService = ForumService();
  final AuthService _authService = AuthService();
  final AdminService _adminService = AdminService();
  bool? _hasUserLiked;

  @override
  void initState() {
    super.initState();
    _loadLikeStatus();
  }

  Future<void> _loadLikeStatus() async {
    if (!_authService.isSignedIn) return;
    
    try {
      final hasLiked = await _forumService.hasUserLikedPost(widget.post.id, _authService.currentUser!.uid);
      if (mounted) {
        setState(() {
          _hasUserLiked = hasLiked;
        });
      }
    } catch (e) {
      // Error silencioso para el estado del like
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(theme),
              const SizedBox(height: 12),
              _buildTitle(theme),
              const SizedBox(height: 8),
              _buildContent(theme),
              if (widget.post.mediaAttachments.isNotEmpty) ...[
                const SizedBox(height: 12),
                MediaPreview(attachments: widget.post.mediaAttachments),
              ],
              const SizedBox(height: 16),
              _buildFooter(theme),
            ],
          ),
        ),
      ),
    );
  }

  void _showReportDialog(BuildContext context) {
    final reasonController = TextEditingController();
    ReportType selectedType = ReportType.inappropriate;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reportar post'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Tipo de reporte:'),
              const SizedBox(height: 8),
              DropdownButtonFormField<ReportType>(
                value: selectedType,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: ReportType.values.map((type) {
                  String label;
                  switch (type) {
                    case ReportType.spam:
                      label = 'Spam';
                      break;
                    case ReportType.inappropriate:
                      label = 'Contenido inapropiado';
                      break;
                    case ReportType.harassment:
                      label = 'Acoso';
                      break;
                    case ReportType.misinformation:
                      label = 'Información falsa';
                      break;
                    case ReportType.other:
                      label = 'Otro';
                      break;
                  }
                  return DropdownMenuItem(
                    value: type,
                    child: Text(label),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    selectedType = value;
                  }
                },
              ),
              const SizedBox(height: 16),
              const Text('Razón del reporte:'),
              const SizedBox(height: 8),
              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Describe la razón del reporte...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Por favor ingresa una razón'),
                  ),
                );
                return;
              }

              try {
                final report = ReportModel(
                  id: '',
                  reporterId: _authService.currentUser!.uid,
                  reporterName: _authService.currentUser!.userName,
                  reportedUserId: widget.post.autorId,
                  reportedUserName: widget.post.autorNombre,
                  contentType: ReportedContentType.post,
                  contentId: widget.post.id,
                  contentPreview: widget.post.titulo,
                  type: selectedType,
                  reason: reasonController.text.trim(),
                  createdAt: DateTime.now(),
                );

                await _adminService.createReport(report);
                
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Reporte enviado exitosamente'),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Error al enviar el reporte'),
                    ),
                  );
                }
              }
            },
            child: const Text('Enviar reporte'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Row(
      children: [
        UserAvatarFromId(
          userId: widget.post.autorId,
          radius: 16,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.post.autorNombre,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                DateFormat('dd/MM/yyyy HH:mm').format(widget.post.fechaCreacion),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        _buildBadges(theme),
        if (_authService.isSignedIn && widget.currentUserId != widget.post.autorId)
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'report') {
                _showReportDialog(context);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'report',
                child: Row(
                  children: [
                    Icon(Icons.flag, size: 16, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('Reportar', style: TextStyle(color: Colors.orange)),
                  ],
                ),
              ),
            ],
            icon: const Icon(Icons.more_vert, size: 16),
          ),
      ],
    );
  }

  Widget _buildBadges(ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.post.isPinned)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: theme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.push_pin, size: 12, color: theme.primaryColor),
                const SizedBox(width: 2),
                Text(
                  'Fijado',
                  style: TextStyle(
                    color: theme.primaryColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        if (widget.showPopularityBadge && widget.post.likes > 5) ...[
          if (widget.post.isPinned) const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.trending_up, size: 12, color: Colors.orange),
                const SizedBox(width: 2),
                Text(
                  'Popular',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
        if (widget.post.categoria != null) ...[
          if (widget.post.isPinned || (widget.showPopularityBadge && widget.post.likes > 5)) 
            const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              widget.post.categoria!,
              style: TextStyle(
                color: theme.colorScheme.onSecondaryContainer,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTitle(ThemeData theme) {
    return Text(
      widget.post.titulo,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildContent(ThemeData theme) {
    return Text(
      widget.post.contenido,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        height: 1.4,
      ),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildFooter(ThemeData theme) {
    return Row(
      children: [
        InkWell(
          onTap: _authService.isSignedIn && _hasUserLiked != null ? widget.onLike : null,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                Icon(
                  (_hasUserLiked ?? false) ? Icons.thumb_up : Icons.thumb_up_outlined,
                  size: 16,
                  color:theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  '${widget.post.likes}',
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
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(
              '${widget.post.respuestas}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        const Spacer(),
        if (widget.post.tags.isNotEmpty)
          Wrap(
            spacing: 4,
            children: widget.post.tags.take(2).map((tag) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '#$tag',
                  style: TextStyle(
                    fontSize: 10,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}

/// Widget para mostrar una respuesta del foro
class ForumReplyCard extends StatefulWidget {
  final ForumReply reply;
  final VoidCallback? onLike;
  final bool? hasUserLiked;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const ForumReplyCard({
    super.key,
    required this.reply,
    this.onLike,
    this.hasUserLiked,
    this.onEdit,
    this.onDelete,
  });

  @override
  State<ForumReplyCard> createState() => _ForumReplyCardState();
}

class _ForumReplyCardState extends State<ForumReplyCard> {
  final AuthService _authService = AuthService();
  final AdminService _adminService = AdminService();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.dividerColor.withOpacity(0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserAvatarFromId(
                userId: widget.reply.autorId,
                radius: 14,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.reply.autorNombre,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      DateFormat('dd/MM/yyyy HH:mm').format(widget.reply.fechaCreacion),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (_authService.isSignedIn)
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit' && widget.onEdit != null) {
                      widget.onEdit!();
                    } else if (value == 'delete' && widget.onDelete != null) {
                      widget.onDelete!();
                    } else if (value == 'report') {
                      _showReportDialog(context);
                    }
                  },
                  itemBuilder: (context) => [
                    if (_authService.currentUser!.uid == widget.reply.autorId) ...[
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 16),
                            SizedBox(width: 8),
                            Text('Editar'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                        children: [
                          Icon(Icons.delete, size: 16, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Eliminar', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                    ],
                    if (_authService.currentUser!.uid != widget.reply.autorId)
                      const PopupMenuItem(
                        value: 'report',
                        child: Row(
                          children: [
                            Icon(Icons.flag, size: 16, color: Colors.orange),
                            SizedBox(width: 8),
                            Text('Reportar', style: TextStyle(color: Colors.orange)),
                          ],
                        ),
                      ),
                  ],
                  icon: const Icon(Icons.more_vert, size: 16),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            widget.reply.contenido,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.4,
            ),
          ),
          if (widget.reply.mediaAttachments.isNotEmpty) ...[
            const SizedBox(height: 12),
            AttachmentsList(attachments: widget.reply.mediaAttachments),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              InkWell(
                onTap: _authService.isSignedIn && widget.hasUserLiked != null ? widget.onLike : null,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      Icon(
                        (widget.hasUserLiked ?? false) ? Icons.thumb_up : Icons.thumb_up_outlined,
                        size: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${widget.reply.likes}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showReportDialog(BuildContext context) {
    final reasonController = TextEditingController();
    ReportType selectedType = ReportType.inappropriate;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reportar contenido'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Tipo de reporte:'),
              const SizedBox(height: 8),
              DropdownButtonFormField<ReportType>(
                value: selectedType,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: ReportType.values.map((type) {
                  String label;
                  switch (type) {
                    case ReportType.spam:
                      label = 'Spam';
                      break;
                    case ReportType.inappropriate:
                      label = 'Contenido inapropiado';
                      break;
                    case ReportType.harassment:
                      label = 'Acoso';
                      break;
                    case ReportType.misinformation:
                      label = 'Información falsa';
                      break;
                    case ReportType.other:
                      label = 'Otro';
                      break;
                  }
                  return DropdownMenuItem(
                    value: type,
                    child: Text(label),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    selectedType = value;
                  }
                },
              ),
              const SizedBox(height: 16),
              const Text('Razón del reporte:'),
              const SizedBox(height: 8),
              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Describe la razón del reporte...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Por favor ingresa una razón'),
                  ),
                );
                return;
              }

              try {
                final report = ReportModel(
                  id: '',
                  reporterId: _authService.currentUser!.uid,
                  reporterName: _authService.currentUser!.userName,
                  reportedUserId: widget.reply.autorId,
                  reportedUserName: widget.reply.autorNombre,
                  contentType: ReportedContentType.reply,
                  contentId: widget.reply.id,
                  contentPreview: widget.reply.contenido.length > 100
                      ? widget.reply.contenido.substring(0, 100) + '...'
                      : widget.reply.contenido,
                  type: selectedType,
                  reason: reasonController.text.trim(),
                  createdAt: DateTime.now(),
                );

                await _adminService.createReport(report);
                
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Reporte enviado exitosamente'),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Error al enviar el reporte'),
                    ),
                  );
                }
              }
            },
            child: const Text('Enviar reporte'),
          ),
        ],
      ),
    );
  }
}

/// Diálogo para crear un nuevo post
class CreatePostDialog extends StatefulWidget {
  final VoidCallback onPostCreated;

  const CreatePostDialog({
    super.key,
    required this.onPostCreated,
  });

  @override
  State<CreatePostDialog> createState() => _CreatePostDialogState();
}

class _CreatePostDialogState extends State<CreatePostDialog> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final ForumService _forumService = ForumService();
  final AuthService _authService = AuthService();

  String? _selectedCategory;
  bool _isSubmitting = false;

  final List<String> _categories = [
    'General',
    'Reglamento',
    'Académico',
    'Dudas',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _submitPost() async {
    if (_titleController.text.trim().isEmpty || 
        _contentController.text.trim().isEmpty) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = _authService.currentUser!;
      final post = ForumPost(
        id: '',
        titulo: _titleController.text.trim(),
        contenido: _contentController.text.trim(),
        autorId: user.uid,
        autorNombre: user.userName,
        autorPhotoURL: user.photoURL,
        fechaCreacion: DateTime.now(),
        fechaActualizacion: DateTime.now(),
        categoria: _selectedCategory,
      );

      await _forumService.createPost(post);
      widget.onPostCreated();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post creado exitosamente')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creando post: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: double.maxFinite,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Text(
              'Crear Nuevo Post',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            
            // Selector de categoría
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: InputDecoration(
                labelText: 'Categoría (opcional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: _categories.map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedCategory = value);
              },
            ),
            
            const SizedBox(height: 16),
            
            // Campo de título
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Título *',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              maxLength: 100,
            ),
            
            const SizedBox(height: 16),
            
            // Campo de contenido
            TextField(
              controller: _contentController,
              decoration: InputDecoration(
                labelText: 'Contenido *',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              maxLines: 4,
              maxLength: 1000,
            ),
            
            const SizedBox(height: 16),
            
            // Botones
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 8),
                CustomButton(
                  text: 'Publicar',
                  onPressed: _isSubmitting ? null : _submitPost,
                  isLoading: _isSubmitting,
                  size: ButtonSize.small,
                ),
              ],
            ),
          ],
        ),
        ),
      ),
    );
  }
}