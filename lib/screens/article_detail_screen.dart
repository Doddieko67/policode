import 'package:flutter/material.dart';
import 'package:policode/models/article_model.dart';
import 'package:policode/services/article_service.dart';
import 'package:policode/services/auth_service.dart';
import 'package:policode/widgets/loading_widgets.dart';
import 'package:policode/widgets/custom_button.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:flutter/services.dart';

class ArticleDetailScreen extends StatefulWidget {
  const ArticleDetailScreen({super.key});

  @override
  State<ArticleDetailScreen> createState() => _ArticleDetailScreenState();
}

class _ArticleDetailScreenState extends State<ArticleDetailScreen> {
  final ArticleService _articleService = ArticleService();
  final AuthService _authService = AuthService();
  
  Article? _article;
  bool _isLoading = true;
  bool _hasLiked = false;
  bool _isSubscribed = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    timeago.setLocaleMessages('es', timeago.EsMessages());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final articleId = ModalRoute.of(context)?.settings.arguments as String?;
    if (articleId != null) {
      _loadArticle(articleId);
    }
  }

  Future<void> _loadArticle(String articleId) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final article = await _articleService.getArticleById(articleId);
      
      if (article == null) {
        setState(() {
          _errorMessage = 'Artículo no encontrado';
          _isLoading = false;
        });
        return;
      }

      // Verificar si el usuario ya dio like y si está suscrito
      final results = await Future.wait([
        _articleService.hasUserLiked(articleId),
        _articleService.isSubscribedToUser(article.autorId),
      ]);

      setState(() {
        _article = article;
        _hasLiked = results[0] as bool;
        _isSubscribed = results[1] as bool;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error cargando artículo: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: _isLoading
          ? const Center(child: LoadingWidget())
          : _errorMessage != null
              ? _buildErrorState()
              : _buildArticleContent(),
      floatingActionButton: _article != null ? _buildFAB() : null,
    );
  }

  Widget _buildErrorState() {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: CustomErrorWidget.generic(
          title: 'Error',
          message: _errorMessage,
          onRetry: () {
            final articleId = ModalRoute.of(context)?.settings.arguments as String?;
            if (articleId != null) _loadArticle(articleId);
          },
        ),
      ),
    );
  }

  Widget _buildArticleContent() {
    final article = _article!;
    final theme = Theme.of(context);

    return CustomScrollView(
      slivers: [
        _buildAppBar(article),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildArticleHeader(article),
                const SizedBox(height: 24),
                _buildArticleBody(article),
                const SizedBox(height: 32),
                _buildArticleActions(article),
                const SizedBox(height: 100), // Espacio para el FAB
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAppBar(Article article) {
    return SliverAppBar(
      expandedHeight: article.imagenUrl != null ? 300 : 100,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          article.titulo,
          style: const TextStyle(
            color: Colors.white,
            shadows: [
              Shadow(
                offset: Offset(0, 1),
                blurRadius: 3,
                color: Colors.black54,
              ),
            ],
          ),
        ),
        background: article.imagenUrl != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    article.imagenUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Theme.of(context).colorScheme.surfaceVariant,
                      child: const Icon(Icons.article, size: 64),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : Container(
                color: Theme.of(context).primaryColor,
              ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.share),
          onPressed: () => _shareArticle(article),
        ),
        PopupMenuButton<String>(
          onSelected: (value) => _handleMenuAction(value, article),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'copy_link',
              child: Row(
                children: [
                  Icon(Icons.link),
                  SizedBox(width: 8),
                  Text('Copiar enlace'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'report',
              child: Row(
                children: [
                  Icon(Icons.flag),
                  SizedBox(width: 8),
                  Text('Reportar'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildArticleHeader(Article article) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Chip(
              label: Text(article.categoria),
              backgroundColor: theme.colorScheme.primaryContainer,
            ),
            if (article.isFeatured) ...[
              const SizedBox(width: 8),
              Chip(
                label: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star, size: 16, color: Colors.amber),
                    SizedBox(width: 4),
                    Text('Destacado'),
                  ],
                ),
                backgroundColor: Colors.amber.withOpacity(0.2),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            CircleAvatar(
              radius: 20,
              child: Text(
                article.autorNombre.substring(0, 1).toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    article.autorNombre,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    timeago.format(article.fechaCreacion, locale: 'es'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (_authService.isSignedIn && 
                _authService.currentUser!.uid != article.autorId)
              CustomButton(
                text: _isSubscribed ? 'Suscrito' : 'Suscribirse',
                onPressed: _toggleSubscription,
                type: _isSubscribed ? ButtonType.secondary : ButtonType.primary,
                size: ButtonSize.small,
                icon: _isSubscribed ? Icons.notifications : Icons.notifications_none,
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (article.tags.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: article.tags.map((tag) => Chip(
              label: Text('#$tag'),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            )).toList(),
          ),
      ],
    );
  }

  Widget _buildArticleBody(Article article) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (article.resumen.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.outline.withOpacity(0.3),
              ),
            ),
            child: Text(
              article.resumen,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontStyle: FontStyle.italic,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
        Text(
          article.contenido,
          style: theme.textTheme.bodyLarge?.copyWith(
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _buildArticleActions(Article article) {
    final theme = Theme.of(context);

    return Row(
      children: [
        _buildStatChip(
          icon: _hasLiked ? Icons.favorite : Icons.favorite_border,
          label: '${article.likes}',
          color: _hasLiked ? Colors.red : theme.colorScheme.onSurfaceVariant,
          onTap: _toggleLike,
        ),
        const SizedBox(width: 12),
        _buildStatChip(
          icon: Icons.visibility,
          label: '${article.views}',
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const Spacer(),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.access_time,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(
              'Actualizado ${timeago.format(article.fechaActualizacion, locale: 'es')}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFAB() {
    return FloatingActionButton.extended(
      onPressed: () => Navigator.pushNamed(context, '/chat'),
      icon: const Icon(Icons.chat),
      label: const Text('Preguntar sobre esto'),
    );
  }

  Future<void> _toggleLike() async {
    if (!_authService.isSignedIn) {
      _showLoginDialog();
      return;
    }

    try {
      await _articleService.likeArticle(_article!.id);
      setState(() {
        _hasLiked = !_hasLiked;
        _article = _article!.copyWith(
          likes: _hasLiked 
              ? _article!.likes + 1 
              : _article!.likes - 1,
        );
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _toggleSubscription() async {
    if (!_authService.isSignedIn) {
      _showLoginDialog();
      return;
    }

    try {
      if (_isSubscribed) {
        await _articleService.unsubscribeFromUser(_article!.autorId);
      } else {
        await _articleService.subscribeToUser(_article!.autorId);
      }
      
      setState(() {
        _isSubscribed = !_isSubscribed;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isSubscribed 
                ? 'Te suscribiste a ${_article!.autorNombre}'
                : 'Te desuscribiste de ${_article!.autorNombre}',
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _shareArticle(Article article) {
    // Implementar compartir
    Clipboard.setData(ClipboardData(
      text: '${article.titulo}\n\nLee más en PoliCode',
    ));
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Enlace copiado al portapapeles')),
    );
  }

  void _handleMenuAction(String action, Article article) {
    switch (action) {
      case 'copy_link':
        _shareArticle(article);
        break;
      case 'report':
        _showReportDialog();
        break;
    }
  }

  void _showLoginDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Iniciar sesión'),
        content: const Text('Debes iniciar sesión para realizar esta acción.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          CustomButton(
            text: 'Iniciar sesión',
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/auth');
            },
            size: ButtonSize.small,
          ),
        ],
      ),
    );
  }

  void _showReportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reportar artículo'),
        content: const Text('¿Qué problema tiene este artículo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          CustomButton.danger(
            text: 'Reportar',
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Reporte enviado')),
              );
            },
            size: ButtonSize.small,
          ),
        ],
      ),
    );
  }
}