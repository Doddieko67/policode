import 'package:flutter/material.dart';
import 'package:policode/models/article_model.dart';
import 'package:policode/services/article_service.dart';
import 'package:policode/services/auth_service.dart';
import 'package:policode/widgets/loading_widgets.dart';
import 'package:policode/widgets/custom_button.dart';
import 'package:timeago/timeago.dart' as timeago;

class ArticlesScreen extends StatefulWidget {
  const ArticlesScreen({super.key});

  @override
  State<ArticlesScreen> createState() => _ArticlesScreenState();
}

class _ArticlesScreenState extends State<ArticlesScreen> with TickerProviderStateMixin {
  final ArticleService _articleService = ArticleService();
  final AuthService _authService = AuthService();
  
  late TabController _tabController;
  List<Article> _articles = [];
  List<Article> _featuredArticles = [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _selectedCategory;

  final List<String> _categories = [
    'Todos',
    'Reglamento',
    'Académico',
    'Normativas',
    'Guías',
    'Noticias'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    timeago.setLocaleMessages('es', timeago.EsMessages());
    _loadArticles();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadArticles() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        _articleService.getPublishedArticles(
          categoria: _selectedCategory == 'Todos' ? null : _selectedCategory,
        ),
        _articleService.getFeaturedArticles(),
      ]);

      setState(() {
        _articles = results[0] as List<Article>;
        _featuredArticles = results[1] as List<Article>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error cargando artículos: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Artículos'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Destacados', icon: Icon(Icons.star)),
            Tab(text: 'Todos', icon: Icon(Icons.article)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _showSearchDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: LoadingWidget())
          : _errorMessage != null
              ? _buildErrorState()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildFeaturedTab(),
                    _buildAllArticlesTab(),
                  ],
                ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: CustomErrorWidget.generic(
        title: 'Error',
        message: _errorMessage,
        onRetry: _loadArticles,
      ),
    );
  }

  Widget _buildFeaturedTab() {
    if (_featuredArticles.isEmpty) {
      return const Center(
        child: Text('No hay artículos destacados'),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadArticles,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _featuredArticles.length,
        itemBuilder: (context, index) {
          return _buildFeaturedArticleCard(_featuredArticles[index]);
        },
      ),
    );
  }

  Widget _buildAllArticlesTab() {
    return Column(
      children: [
        _buildCategoryFilter(),
        Expanded(
          child: _articles.isEmpty
              ? const Center(child: Text('No hay artículos'))
              : RefreshIndicator(
                  onRefresh: _loadArticles,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _articles.length,
                    itemBuilder: (context, index) {
                      return _buildArticleCard(_articles[index]);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildCategoryFilter() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
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
                  _selectedCategory = category == 'Todos' ? null : category;
                });
                _loadArticles();
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildFeaturedArticleCard(Article article) {
    final theme = Theme.of(context);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      child: InkWell(
        onTap: () => _navigateToArticle(article.id),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (article.imagenUrl != null)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: Image.network(
                  article.imagenUrl!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 200,
                    color: theme.colorScheme.surfaceVariant,
                    child: const Icon(Icons.image_not_supported),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.star, color: Colors.amber, size: 20),
                      const SizedBox(width: 4),
                      Text(
                        'DESTACADO',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.amber,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    article.titulo,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    article.resumen,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  _buildArticleMetadata(article),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArticleCard(Article article) {
    final theme = Theme.of(context);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _navigateToArticle(article.id),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (article.imagenUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    article.imagenUrl!,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 80,
                      height: 80,
                      color: theme.colorScheme.surfaceVariant,
                      child: const Icon(Icons.article),
                    ),
                  ),
                ),
              if (article.imagenUrl != null) const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      article.titulo,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      article.resumen,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    _buildArticleMetadata(article),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildArticleMetadata(Article article) {
    final theme = Theme.of(context);
    
    return Row(
      children: [
        Icon(
          Icons.person,
          size: 14,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Text(
          article.autorNombre,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 12),
        Icon(
          Icons.access_time,
          size: 14,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Text(
          timeago.format(article.fechaCreacion, locale: 'es'),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        if (article.views > 0) ...[
          Icon(
            Icons.visibility,
            size: 14,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            '${article.views}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Buscar artículos'),
        content: TextField(
          decoration: const InputDecoration(
            hintText: 'Escribe para buscar...',
            prefixIcon: Icon(Icons.search),
          ),
          onSubmitted: (query) {
            Navigator.pop(context);
            _searchArticles(query);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  Future<void> _searchArticles(String query) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final results = await _articleService.searchArticles(query);
      setState(() {
        _articles = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error en búsqueda: $e';
        _isLoading = false;
      });
    }
  }

  void _navigateToArticle(String articleId) {
    Navigator.pushNamed(
      context,
      '/article-detail',
      arguments: articleId,
    );
  }
}