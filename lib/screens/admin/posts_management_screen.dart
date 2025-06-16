import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/admin_service.dart';
import '../../models/forum_model.dart';
import '../../widgets/loading_widgets.dart';
import '../../widgets/admin_guard.dart';

class PostsManagementScreen extends StatefulWidget {
  const PostsManagementScreen({super.key});

  @override
  State<PostsManagementScreen> createState() => _PostsManagementScreenState();
}

class _PostsManagementScreenState extends State<PostsManagementScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final AdminService _adminService = AdminService();
  
  // Controllers para comentarios de admin
  final Map<String, TextEditingController> _commentControllers = {};
  final Map<String, bool> _isCommentingMap = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    // Limpiar controllers
    for (final controller in _commentControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdminGuard(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Gestión de Posts'),
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Todos los Posts', icon: Icon(Icons.list)),
              Tab(text: 'Posts Reportados', icon: Icon(Icons.report)),
              Tab(text: 'Estadísticas', icon: Icon(Icons.analytics)),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildAllPostsTab(),
            _buildReportedPostsTab(),
            _buildStatsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildAllPostsTab() {
    return StreamBuilder<List<ForumPost>>(
      stream: _adminService.getAllPostsForAdmin(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingWidget();
        }

        if (snapshot.hasError) {
          return CustomErrorWidget(
            title: 'Error',
            message: 'Error cargando posts: ${snapshot.error}',
          );
        }

        final posts = snapshot.data ?? [];

        if (posts.isEmpty) {
          return const Center(
            child: Text('No hay posts en el foro'),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            return _buildPostCard(post, false);
          },
        );
      },
    );
  }

  Widget _buildReportedPostsTab() {
    return StreamBuilder<List<ForumPost>>(
      stream: _adminService.getReportedPosts(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingWidget();
        }

        if (snapshot.hasError) {
          return CustomErrorWidget(
            title: 'Error',
            message: 'Error cargando posts reportados: ${snapshot.error}',
          );
        }

        final posts = snapshot.data ?? [];

        if (posts.isEmpty) {
          return const Center(
            child: Text('No hay posts reportados'),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            return _buildPostCard(post, true);
          },
        );
      },
    );
  }

  Widget _buildStatsTab() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _adminService.getPostStats(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingWidget();
        }

        if (snapshot.hasError) {
          return CustomErrorWidget(
            title: 'Error',
            message: 'Error cargando estadísticas: ${snapshot.error}',
          );
        }

        final stats = snapshot.data ?? {};

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildStatCard(
                'Posts Totales',
                stats['totalPosts']?.toString() ?? '0',
                Icons.article,
                Colors.blue,
              ),
              const SizedBox(height: 16),
              _buildStatCard(
                'Posts Esta Semana',
                stats['postsLastWeek']?.toString() ?? '0',
                Icons.schedule,
                Colors.green,
              ),
              const SizedBox(height: 16),
              _buildStatCard(
                'Posts Este Mes',
                stats['postsLastMonth']?.toString() ?? '0',
                Icons.calendar_month,
                Colors.orange,
              ),
              const SizedBox(height: 16),
              _buildStatCard(
                'Posts Fijados',
                stats['pinnedPosts']?.toString() ?? '0',
                Icons.push_pin,
                Colors.purple,
              ),
              const SizedBox(height: 16),
              _buildStatCard(
                'Posts Cerrados',
                stats['lockedPosts']?.toString() ?? '0',
                Icons.lock,
                Colors.red,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostCard(ForumPost post, bool isReported) {
    final theme = Theme.of(context);
    final isCommenting = _isCommentingMap[post.id] ?? false;
    
    if (!_commentControllers.containsKey(post.id)) {
      _commentControllers[post.id] = TextEditingController();
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header del post
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.titulo,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Por: ${post.autorNombre} • ${DateFormat('dd/MM/yyyy HH:mm').format(post.fechaCreacion)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                if (isReported)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'REPORTADO',
                      style: TextStyle(
                        color: Colors.red[800],
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // Contenido del post (preview)
            Text(
              post.contenido,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),

            const SizedBox(height: 16),

            // Tags si las tiene
            if (post.tags.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                children: post.tags.map((tag) => Chip(
                  label: Text(tag),
                  backgroundColor: theme.primaryColor.withOpacity(0.1),
                  side: BorderSide.none,
                )).toList(),
              ),
              const SizedBox(height: 16),
            ],

            // Botones de acción
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // Ver post completo
                ElevatedButton.icon(
                  onPressed: () => _viewPost(post),
                  icon: const Icon(Icons.visibility, size: 16),
                  label: const Text('Ver'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[50],
                    foregroundColor: Colors.blue[700],
                  ),
                ),

                // Agregar comentario
                ElevatedButton.icon(
                  onPressed: () => _toggleCommenting(post.id),
                  icon: const Icon(Icons.comment, size: 16),
                  label: Text(isCommenting ? 'Cancelar' : 'Comentar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[50],
                    foregroundColor: Colors.green[700],
                  ),
                ),

                // Fijar/Desfijar
                ElevatedButton.icon(
                  onPressed: () => _togglePin(post),
                  icon: Icon(
                    (post.isPinned ?? false) ? Icons.push_pin : Icons.push_pin_outlined,
                    size: 16,
                  ),
                  label: Text((post.isPinned ?? false) ? 'Desfijar' : 'Fijar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple[50],
                    foregroundColor: Colors.purple[700],
                  ),
                ),

                // Cerrar/Abrir
                ElevatedButton.icon(
                  onPressed: () => _toggleLock(post),
                  icon: Icon(
                    (post.isLocked ?? false) ? Icons.lock_open : Icons.lock,
                    size: 16,
                  ),
                  label: Text((post.isLocked ?? false) ? 'Abrir' : 'Cerrar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[50],
                    foregroundColor: Colors.orange[700],
                  ),
                ),

                // Eliminar
                ElevatedButton.icon(
                  onPressed: () => _deletePost(post),
                  icon: const Icon(Icons.delete, size: 16),
                  label: const Text('Eliminar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[50],
                    foregroundColor: Colors.red[700],
                  ),
                ),
              ],
            ),

            // Campo de comentario si está activo
            if (isCommenting) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              TextField(
                controller: _commentControllers[post.id],
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Comentario oficial como administrador',
                  border: OutlineInputBorder(),
                  hintText: 'Escribe tu comentario oficial...',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _addAdminComment(post.id, false),
                      child: const Text('Comentar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _addAdminComment(post.id, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primaryColor,
                      ),
                      child: const Text('Comentar y Fijar'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _viewPost(ForumPost post) {
    Navigator.pushNamed(
      context,
      '/forum-post-detail',
      arguments: {'postId': post.id},
    );
  }

  void _toggleCommenting(String postId) {
    setState(() {
      _isCommentingMap[postId] = !(_isCommentingMap[postId] ?? false);
    });
  }

  Future<void> _addAdminComment(String postId, bool isPinned) async {
    final comment = _commentControllers[postId]?.text.trim();
    if (comment == null || comment.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe un comentario')),
      );
      return;
    }

    try {
      await _adminService.addAdminComment(postId, comment, isPinned: isPinned);
      
      // Limpiar el campo
      _commentControllers[postId]?.clear();
      _toggleCommenting(postId);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isPinned 
                ? 'Comentario oficial agregado y fijado'
                : 'Comentario oficial agregado'
          ),
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
  }

  Future<void> _togglePin(ForumPost post) async {
    try {
      await _adminService.togglePinPost(post.id);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            (post.isPinned ?? false) 
                ? 'Post desfijado' 
                : 'Post fijado'
          ),
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
  }

  Future<void> _toggleLock(ForumPost post) async {
    try {
      await _adminService.toggleLockPost(post.id);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            (post.isLocked ?? false) 
                ? 'Post abierto para comentarios' 
                : 'Post cerrado para comentarios'
          ),
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
  }

  Future<void> _deletePost(ForumPost post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Post'),
        content: Text(
          '¿Estás seguro de que quieres eliminar el post "${post.titulo}"?\n\n'
          'Esta acción también eliminará todas las respuestas asociadas y no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Pedir razón
    final reason = await _showReasonDialog();
    if (reason == null || reason.isEmpty) return;

    try {
      await _adminService.deletePost(post.id, reason);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Post eliminado correctamente'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error eliminando post: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<String?> _showReasonDialog() async {
    final controller = TextEditingController();
    
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Razón de eliminación'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Razón',
            border: OutlineInputBorder(),
            hintText: 'Explica por qué eliminas este post...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }
}