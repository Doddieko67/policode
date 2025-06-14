import 'package:flutter/material.dart';
import 'package:policode/models/article_model.dart';
import 'package:policode/services/article_service.dart';
import 'package:policode/services/auth_service.dart';
import 'package:policode/widgets/loading_widgets.dart';
import 'package:policode/widgets/custom_button.dart';
import 'package:policode/widgets/custom_input.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> with TickerProviderStateMixin {
  final ArticleService _articleService = ArticleService();
  final AuthService _authService = AuthService();
  
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  
  // Controladores de texto
  final _titleController = TextEditingController();
  final _summaryController = TextEditingController();
  final _contentController = TextEditingController();
  final _tagsController = TextEditingController();
  
  // Estado del editor
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isDraft = true;
  bool _isFeatured = false;
  String _selectedCategory = 'Reglamento';
  String? _editingArticleId;
  
  final List<String> _categories = [
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
    
    // Verificar si estamos editando un artículo existente
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final articleId = ModalRoute.of(context)?.settings.arguments as String?;
      if (articleId != null) {
        _loadArticleForEditing(articleId);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _summaryController.dispose();
    _contentController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _loadArticleForEditing(String articleId) async {
    setState(() => _isLoading = true);
    
    try {
      final article = await _articleService.getArticleById(articleId);
      if (article != null) {
        setState(() {
          _editingArticleId = articleId;
          _titleController.text = article.titulo;
          _summaryController.text = article.resumen;
          _contentController.text = article.contenido;
          _tagsController.text = article.tags.join(', ');
          _selectedCategory = article.categoria;
          _isDraft = !article.isPublished;
          _isFeatured = article.isFeatured;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cargando artículo: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_editingArticleId != null ? 'Editar Artículo' : 'Nuevo Artículo'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Escribir', icon: Icon(Icons.edit)),
            Tab(text: 'Vista Previa', icon: Icon(Icons.preview)),
          ],
        ),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            PopupMenuButton<String>(
              onSelected: _handleMenuAction,
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'save_draft',
                  child: Row(
                    children: [
                      Icon(Icons.save, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      const Text('Guardar Borrador'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'publish',
                  child: Row(
                    children: [
                      Icon(Icons.publish, color: Colors.green),
                      const SizedBox(width: 8),
                      const Text('Publicar'),
                    ],
                  ),
                ),
                if (_editingArticleId != null)
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: theme.colorScheme.error),
                        const SizedBox(width: 8),
                        Text(
                          'Eliminar',
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: LoadingWidget())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildEditorTab(),
                _buildPreviewTab(),
              ],
            ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildEditorTab() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Configuración del artículo
            _buildArticleSettings(),
            const SizedBox(height: 24),
            
            // Título
            CustomInput(
              controller: _titleController,
              label: 'Título del artículo',
              hint: 'Escribe un título llamativo...',
              maxLines: 2,
              type: InputType.multiline,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'El título es obligatorio';
                }
                if (value.length < 10) {
                  return 'El título debe tener al menos 10 caracteres';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Resumen
            CustomInput(
              controller: _summaryController,
              label: 'Resumen',
              hint: 'Un breve resumen del artículo...',
              maxLines: 3,
              type: InputType.multiline,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'El resumen es obligatorio';
                }
                if (value.length < 20) {
                  return 'El resumen debe tener al menos 20 caracteres';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Tags
            CustomInput(
              controller: _tagsController,
              label: 'Etiquetas (separadas por comas)',
              hint: 'estudiantes, reglamento, derechos...',
              type: InputType.text,
            ),
            const SizedBox(height: 24),
            
            // Contenido
            Text(
              'Contenido',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextFormField(
                controller: _contentController,
                maxLines: 15,
                decoration: const InputDecoration(
                  hintText: 'Escribe el contenido de tu artículo aquí...\n\nPuedes usar Markdown para formato:\n# Título\n## Subtítulo\n**Negrita**\n*Cursiva*\n- Lista\n1. Lista numerada',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'El contenido es obligatorio';
                  }
                  if (value.length < 100) {
                    return 'El contenido debe tener al menos 100 caracteres';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 100), // Espacio para bottom bar
          ],
        ),
      ),
    );
  }

  Widget _buildArticleSettings() {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Configuración',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Categoría
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Categoría',
                border: OutlineInputBorder(),
              ),
              items: _categories.map((category) => DropdownMenuItem(
                value: category,
                child: Text(category),
              )).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedCategory = value);
                }
              },
            ),
            const SizedBox(height: 16),
            
            // Opciones
            Row(
              children: [
                Expanded(
                  child: CheckboxListTile(
                    title: const Text('Borrador'),
                    subtitle: const Text('No publicar aún'),
                    value: _isDraft,
                    onChanged: (value) {
                      setState(() => _isDraft = value ?? true);
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ),
                Expanded(
                  child: CheckboxListTile(
                    title: const Text('Destacado'),
                    subtitle: const Text('Mostrar en portada'),
                    value: _isFeatured,
                    onChanged: (value) {
                      setState(() => _isFeatured = value ?? false);
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header del artículo
          if (_selectedCategory.isNotEmpty)
            Chip(
              label: Text(_selectedCategory),
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            ),
          const SizedBox(height: 16),
          
          // Título
          Text(
            _titleController.text.isEmpty ? 'Título del artículo' : _titleController.text,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          
          // Metadata
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                child: Text(
                  _authService.currentUser?.nombre?.substring(0, 1).toUpperCase() ?? 'U',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _authService.currentUser?.nombre ?? 'Usuario',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      'Ahora',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (_isFeatured)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star, size: 16, color: Colors.amber[700]),
                      const SizedBox(width: 4),
                      Text(
                        'Destacado',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.amber[700],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Resumen
          if (_summaryController.text.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _summaryController.text,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          // Contenido
          Text(
            _contentController.text.isEmpty 
                ? 'El contenido de tu artículo aparecerá aquí...' 
                : _contentController.text,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              height: 1.6,
            ),
          ),
          const SizedBox(height: 16),
          
          // Tags
          if (_tagsController.text.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _getTags().map((tag) => Chip(
                label: Text('#$tag'),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
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
          Text(
            _getWordCount(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          CustomButton(
            text: 'Guardar Borrador',
            onPressed: _isSaving ? null : () => _saveArticle(isDraft: true),
            type: ButtonType.secondary,
            size: ButtonSize.small,
            icon: Icons.save,
          ),
          const SizedBox(width: 12),
          CustomButton(
            text: _editingArticleId != null ? 'Actualizar' : 'Publicar',
            onPressed: _isSaving ? null : () => _saveArticle(isDraft: false),
            type: ButtonType.primary,
            size: ButtonSize.small,
            icon: _editingArticleId != null ? Icons.update : Icons.publish,
          ),
        ],
      ),
    );
  }

  List<String> _getTags() {
    return _tagsController.text
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .take(5)
        .toList();
  }

  String _getWordCount() {
    final words = _contentController.text.split(RegExp(r'\s+')).where((word) => word.isNotEmpty).length;
    final chars = _contentController.text.length;
    return '$words palabras, $chars caracteres';
  }

  Future<void> _saveArticle({required bool isDraft}) async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor corrige los errores')),
      );
      return;
    }

    final user = _authService.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes iniciar sesión')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final now = DateTime.now();
      final article = Article(
        id: _editingArticleId ?? '',
        titulo: _titleController.text.trim(),
        contenido: _contentController.text.trim(),
        resumen: _summaryController.text.trim(),
        autorId: user.uid,
        autorNombre: user.nombre ?? 'Usuario',
        fechaCreacion: now,
        fechaActualizacion: now,
        tags: _getTags(),
        categoria: _selectedCategory,
        views: 0,
        likes: 0,
        isPublished: !isDraft,
        isFeatured: _isFeatured,
      );

      // Aquí llamarías al servicio para guardar
      // await _articleService.saveArticle(article);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isDraft ? 'Borrador guardado' : 'Artículo publicado'),
        ),
      );

      if (!isDraft) {
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'save_draft':
        _saveArticle(isDraft: true);
        break;
      case 'publish':
        _saveArticle(isDraft: false);
        break;
      case 'delete':
        _showDeleteDialog();
        break;
    }
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar artículo'),
        content: const Text('¿Estás seguro? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          CustomButton.danger(
            text: 'Eliminar',
            onPressed: () {
              Navigator.pop(context);
              _deleteArticle();
            },
            size: ButtonSize.small,
          ),
        ],
      ),
    );
  }

  Future<void> _deleteArticle() async {
    // Implementar eliminación
    Navigator.pop(context);
  }
}