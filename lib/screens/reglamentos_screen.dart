import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:policode/models/articulo_model.dart';
import 'package:policode/widgets/loading_widgets.dart';
import 'package:policode/widgets/custom_button.dart';
import 'package:share_plus/share_plus.dart';

class ReglamentosScreen extends StatefulWidget {
  const ReglamentosScreen({super.key});

  @override
  State<ReglamentosScreen> createState() => _ReglamentosScreenState();
}

class _ReglamentosScreenState extends State<ReglamentosScreen> {
  List<Articulo> _articulos = [];
  List<Articulo> _articulosFiltrados = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';
  String? _selectedCategory;
  
  final TextEditingController _searchController = TextEditingController();
  final List<String> _categories = ['Todas'];

  @override
  void initState() {
    super.initState();
    _loadReglamentos();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadReglamentos() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Cargar el JSON desde assets
      final String jsonString = await rootBundle.loadString('assets/data/reglamento.json');
      final List<dynamic> jsonData = json.decode(jsonString);

      // Convertir a lista de artículos
      final articulos = jsonData.map((item) => Articulo.fromJson(item)).toList();
      
      // Extraer categorías únicas
      final categories = articulos
          .map((a) => a.categoria)
          .where((c) => c != null)
          .cast<String>()
          .toSet()
          .toList()
        ..sort();
      
      setState(() {
        _articulos = articulos;
        _articulosFiltrados = articulos;
        _categories.addAll(categories);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error cargando reglamentos: $e';
        _isLoading = false;
      });
    }
  }

  void _filterArticulos() {
    setState(() {
      _articulosFiltrados = _articulos.where((articulo) {
        // Filtro por búsqueda
        final matchesSearch = _searchQuery.isEmpty ||
            articulo.titulo.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            articulo.contenido.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            articulo.numero.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            articulo.palabrasClave.any((keyword) => 
                keyword.toLowerCase().contains(_searchQuery.toLowerCase()));

        // Filtro por categoría
        final matchesCategory = _selectedCategory == null ||
            _selectedCategory == 'Todas' ||
            articulo.categoria == _selectedCategory;

        return matchesSearch && matchesCategory;
      }).toList();

      // Ordenar por prioridad y luego por número
      _articulosFiltrados.sort((a, b) {
        final prioCompare = (b.prioridad ?? 0).compareTo(a.prioridad ?? 0);
        if (prioCompare != 0) return prioCompare;
        return a.numero.compareTo(b.numero);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reglamento Estudiantil'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReglamentos,
            tooltip: 'Recargar',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: LoadingWidget())
          : _errorMessage != null
              ? _buildErrorState()
              : Column(
                  children: [
                    _buildSearchAndFilter(),
                    Expanded(child: _buildArticlesList()),
                  ],
                ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: CustomErrorWidget.generic(
        title: 'Error',
        message: _errorMessage,
        onRetry: _loadReglamentos,
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      color: theme.colorScheme.surface,
      child: Column(
        children: [
          // Barra de búsqueda
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Buscar en reglamento...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                        _filterArticulos();
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (value) {
              setState(() => _searchQuery = value);
              _filterArticulos();
            },
          ),
          const SizedBox(height: 12),
          
          // Filtro por categoría
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = _selectedCategory == category ||
                    (_selectedCategory == null && category == 'Todas');

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(category),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedCategory = category == 'Todas' ? null : category;
                      });
                      _filterArticulos();
                    },
                  ),
                );
              },
            ),
          ),
          
          // Contador de resultados
          const SizedBox(height: 8),
          Text(
            '${_articulosFiltrados.length} artículo(s) encontrado(s)',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArticlesList() {
    if (_articulosFiltrados.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No se encontraron artículos',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Intenta con otros términos de búsqueda',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _articulosFiltrados.length,
      itemBuilder: (context, index) {
        return _buildArticleCard(_articulosFiltrados[index]);
      },
    );
  }

  Widget _buildArticleCard(Articulo articulo) {
    final theme = Theme.of(context);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        onTap: () => _navigateToArticle(articulo),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header con número y prioridad
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      articulo.numero,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (articulo.prioridad != null && articulo.prioridad! > 30) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.star,
                            size: 12,
                            color: Colors.orange[700],
                          ),
                          const SizedBox(width: 2),
                          Text(
                            'Importante',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.orange[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const Spacer(),
                  PopupMenuButton<String>(
                    onSelected: (value) => _handleArticleAction(value, articulo),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'share',
                        child: Row(
                          children: [
                            Icon(Icons.share, size: 20),
                            SizedBox(width: 8),
                            Text('Compartir'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'copy',
                        child: Row(
                          children: [
                            Icon(Icons.copy, size: 20),
                            SizedBox(width: 8),
                            Text('Copiar enlace'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'ask_ai',
                        child: Row(
                          children: [
                            Icon(Icons.smart_toy, size: 20),
                            SizedBox(width: 8),
                            Text('Preguntar a la IA'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Título
              Text(
                articulo.titulo,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              
              // Resumen/Contenido
              Text(
                articulo.resumen,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              
              // Footer con categoría y palabras clave
              if (articulo.categoria != null) ...[
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    Chip(
                      label: Text(articulo.categoria!),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      labelStyle: theme.textTheme.labelSmall,
                    ),
                    ...articulo.palabrasClave.take(3).map((keyword) => Chip(
                      label: Text('#$keyword'),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      labelStyle: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                      backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                    )),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToArticle(Articulo articulo) {
    Navigator.pushNamed(
      context,
      '/articulo',
      arguments: {'articuloId': articulo.id},
    );
  }

  void _handleArticleAction(String action, Articulo articulo) {
    switch (action) {
      case 'share':
        _shareArticle(articulo);
        break;
      case 'copy':
        _copyArticleLink(articulo);
        break;
      case 'ask_ai':
        _askAIAboutArticle(articulo);
        break;
    }
  }

  void _shareArticle(Articulo articulo) {
    final String textoCompartir = '''📋 ${articulo.numero}: ${articulo.titulo}

📄 CONTENIDO:
${articulo.contenido}

🏛️ Fuente: Reglamento Estudiantil del IPN
📱 Compartido desde PoliCode''';
    
    Share.share(
      textoCompartir,
      subject: '${articulo.numero}: ${articulo.titulo}',
    );
  }

  void _copyArticleLink(Articulo articulo) {
    Clipboard.setData(ClipboardData(
      text: 'policode://articulo/${articulo.id}',
    ));
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Enlace copiado al portapapeles')),
    );
  }

  void _askAIAboutArticle(Articulo articulo) {
    Navigator.pushNamed(
      context,
      '/chat',
      arguments: {
        'preguntaInicial': 'Cuéntame sobre el ${articulo.numero}: ${articulo.titulo}',
        'articuloSeleccionado': articulo,
      },
    );
  }
}