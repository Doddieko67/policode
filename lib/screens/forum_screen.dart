import 'package:flutter/material.dart';
import 'package:policode/models/forum_model.dart';
import 'package:policode/services/auth_service.dart';
import 'package:policode/services/forum_service.dart';
import 'package:policode/widgets/custom_button.dart';
import 'package:policode/widgets/loading_widgets.dart';
import 'package:policode/widgets/forum_widgets.dart';
import 'package:policode/screens/forum_post_detail_screen.dart';
import 'package:policode/screens/create_post_screen.dart';
import 'package:intl/intl.dart';

/// Pantalla principal del foro
class ForumScreen extends StatefulWidget {
  const ForumScreen({super.key});

  @override
  State<ForumScreen> createState() => _ForumScreenState();
}

class _ForumScreenState extends State<ForumScreen> with TickerProviderStateMixin {
  final ForumService _forumService = ForumService();
  final AuthService _authService = AuthService();

  late TabController _tabController;
  List<ForumPost> _posts = [];
  List<ForumPost> _pinnedPosts = [];
  bool _isLoading = true;
  String? _selectedCategory;
  String _searchQuery = '';

  final List<String> _categories = [
    'Todos',
    'General',
    'Reglamento',
    'Académico',
    'Dudas',
    'Anuncios'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPosts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPosts() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      // Cargar posts normales y fijados en paralelo
      final results = await Future.wait([
        _forumService.getPosts(
          categoria: _selectedCategory == 'Todos' ? null : _selectedCategory,
        ),
        _forumService.getPosts(isPinned: true),
      ]);

      if (mounted) {
        setState(() {
          _posts = results[0];
          _pinnedPosts = results[1];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cargando posts: $e')),
        );
      }
    }
  }

  Future<void> _searchPosts(String query) async {
    if (query.isEmpty) {
      _loadPosts();
      return;
    }

    setState(() => _isLoading = true);

    try {
      final results = await _forumService.searchPosts(query);
      if (mounted) {
        setState(() {
          _posts = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error buscando: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Foro'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: theme.colorScheme.onSurface,
          unselectedLabelColor: theme.colorScheme.onSurface.withOpacity(0.6),
          tabs: const [
            Tab(text: 'Discusiones', icon: Icon(Icons.forum)),
            Tab(text: 'Populares', icon: Icon(Icons.trending_up)),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildSearchAndFilters(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildDiscussionsTab(),
                _buildPopularTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _authService.isSignedIn
          ? FloatingActionButton.extended(
              onPressed: _showCreatePostDialog,
              icon: const Icon(Icons.add),
              label: const Text('Nuevo Post'),
            )
          : null,
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Barra de búsqueda
          TextField(
            decoration: InputDecoration(
              hintText: 'Buscar en el foro...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceVariant,
            ),
            onChanged: (value) {
              setState(() => _searchQuery = value);
              if (value.isEmpty) {
                _loadPosts();
              }
            },
            onSubmitted: _searchPosts,
          ),
          const SizedBox(height: 12),
          // Filtros de categoría
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = _selectedCategory == category ||
                    (_selectedCategory == null && category == 'Todos');

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(category),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedCategory = selected ? category : null;
                      });
                      _loadPosts();
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscussionsTab() {
    if (_isLoading) {
      return const Center(child: LoadingWidget());
    }

    final allPosts = [..._pinnedPosts, ..._posts];

    if (allPosts.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadPosts,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: allPosts.length,
        itemBuilder: (context, index) {
          final post = allPosts[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ForumPostCard(
              post: post,
              onTap: () => _navigateToPostDetail(post),
              onLike: _authService.isSignedIn
                  ? () => _togglePostLike(post.id)
                  : null,
              currentUserId: _authService.currentUser?.uid,
            ),
          );
        },
      ),
    );
  }

  Widget _buildPopularTab() {
    return FutureBuilder<List<ForumPost>>(
      future: _forumService.getPopularPosts(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: LoadingWidget());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }

        final popularPosts = snapshot.data ?? [];

        if (popularPosts.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: popularPosts.length,
          itemBuilder: (context, index) {
            final post = popularPosts[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ForumPostCard(
                post: post,
                onTap: () => _navigateToPostDetail(post),
                onLike: _authService.isSignedIn
                    ? () => _togglePostLike(post.id)
                    : null,
                showPopularityBadge: true,
                currentUserId: _authService.currentUser?.uid,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.forum_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'No hay posts aún',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              '¡Sé el primero en iniciar una discusión!',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            if (_authService.isSignedIn) ...[
              const SizedBox(height: 16),
              CustomButton(
                text: 'Crear Post',
                onPressed: _showCreatePostDialog,
                icon: Icons.add,
                size: ButtonSize.small,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _togglePostLike(String postId) async {
    try {
      await _forumService.togglePostLike(postId, _authService.currentUser!.uid);
      _loadPosts(); // Recargar para actualizar contadores
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _navigateToPostDetail(ForumPost post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ForumPostDetailScreen(post: post),
      ),
    ).then((_) => _loadPosts()); // Recargar al volver
  }

  void _showCreatePostDialog() {
    if (!_authService.isSignedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes iniciar sesión para crear posts')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CreatePostScreen(),
      ),
    ).then((result) {
      if (result == true) {
        _loadPosts(); // Recargar posts si se creó uno nuevo
      }
    });
  }
}