import 'package:flutter/material.dart';
import 'package:policode/models/forum_model.dart';
import 'package:policode/services/auth_service.dart';
import 'package:policode/services/forum_service.dart';
import 'package:policode/widgets/forum_widgets.dart';
import 'package:policode/widgets/loading_widgets.dart';
import 'package:policode/screens/forum_post_detail_screen.dart';

/// Pantalla para mostrar los posts y respuestas del usuario en el foro
class MisPostsScreen extends StatefulWidget {
  const MisPostsScreen({super.key});

  @override
  State<MisPostsScreen> createState() => _MisPostsScreenState();
}

class _MisPostsScreenState extends State<MisPostsScreen>
    with TickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final ForumService _forumService = ForumService();
  
  late TabController _tabController;
  
  List<ForumPost> _misPosts = [];
  List<ForumReply> _misRespuestas = [];
  
  bool _isLoadingPosts = true;
  bool _isLoadingReplies = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!_authService.isSignedIn) {
      Navigator.pushReplacementNamed(context, '/auth');
      return;
    }

    final userId = _authService.currentUser!.uid;
    
    // Cargar posts y respuestas en paralelo
    await Future.wait([
      _loadMisPosts(userId),
      _loadMisRespuestas(userId),
    ]);
  }

  Future<void> _loadMisPosts(String userId) async {
    try {
      final posts = await _forumService.getPostsByUser(userId);
      if (mounted) {
        setState(() {
          _misPosts = posts;
          _isLoadingPosts = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingPosts = false;
        });
      }
    }
  }

  Future<void> _loadMisRespuestas(String userId) async {
    try {
      final respuestas = await _forumService.getRepliesByUser(userId);
      if (mounted) {
        setState(() {
          _misRespuestas = respuestas;
          _isLoadingReplies = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingReplies = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!_authService.isSignedIn) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Mis Posts'),
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onPrimary,
        ),
        body: const Center(
          child: CustomErrorWidget(
            title: 'No autenticado',
            message: 'Necesitas iniciar sesión para ver tus posts.',
            icon: Icons.login,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Posts'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        bottom: TabBar(
          controller: _tabController,
          labelColor: theme.colorScheme.onPrimary,
          unselectedLabelColor: theme.colorScheme.onPrimary.withOpacity(0.7),
          indicatorColor: theme.colorScheme.onPrimary,
          tabs: const [
            Tab(text: 'Mis Posts', icon: Icon(Icons.article)),
            Tab(text: 'Mis Respuestas', icon: Icon(Icons.reply)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMisPostsTab(),
          _buildMisRespuestasTab(),
        ],
      ),
    );
  }

  Widget _buildMisPostsTab() {
    if (_isLoadingPosts) {
      return const Center(child: LoadingWidget());
    }

    if (_misPosts.isEmpty) {
      return const Center(
        child: CustomErrorWidget(
          title: 'Sin posts',
          message: 'Aún no has creado ningún post en el foro.',
          icon: Icons.article_outlined,
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadMisPosts(_authService.currentUser!.uid),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _misPosts.length,
        separatorBuilder: (context, index) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final post = _misPosts[index];
          return ForumPostCard(
            post: post,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ForumPostDetailScreen(post: post),
                ),
              ).then((_) => _loadData());
            },
            onLike: () async {
              try {
                await _forumService.togglePostLike(
                  post.id, 
                  _authService.currentUser!.uid,
                );
                _loadMisPosts(_authService.currentUser!.uid);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            showPopularityBadge: true,
            currentUserId: _authService.currentUser!.uid,
          );
        },
      ),
    );
  }

  Widget _buildMisRespuestasTab() {
    if (_isLoadingReplies) {
      return const Center(child: LoadingWidget());
    }

    if (_misRespuestas.isEmpty) {
      return const Center(
        child: CustomErrorWidget(
          title: 'Sin respuestas',
          message: 'Aún no has respondido a ningún post en el foro.',
          icon: Icons.reply_outlined,
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadMisRespuestas(_authService.currentUser!.uid),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _misRespuestas.length,
        separatorBuilder: (context, index) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final respuesta = _misRespuestas[index];
          return Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Respuesta en: ${respuesta.postTitulo ?? "Post eliminado"}',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ForumReplyCard(
                    reply: respuesta,
                    onLike: () async {
                      try {
                        await _forumService.toggleReplyLike(
                          respuesta.id,
                          _authService.currentUser!.uid,
                        );
                        _loadMisRespuestas(_authService.currentUser!.uid);
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}