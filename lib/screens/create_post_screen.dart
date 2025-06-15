import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:policode/models/forum_model.dart';
import 'package:policode/services/auth_service.dart';
import 'package:policode/services/forum_service.dart';
import 'package:policode/services/media_service.dart';
import 'package:policode/widgets/custom_button.dart';
import 'package:policode/widgets/loading_widgets.dart';

/// Pantalla para crear un nuevo post con soporte multimedia
class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final ForumService _forumService = ForumService();
  final AuthService _authService = AuthService();
  final MediaService _mediaService = MediaService();

  String? _selectedCategory;
  List<String> _tags = [];
  final TextEditingController _tagController = TextEditingController();
  
  // Media attachments
  List<XFile> _selectedImages = [];
  List<XFile> _selectedVideos = [];
  List<PlatformFile> _selectedDocuments = [];
  
  bool _isSubmitting = false;
  bool _isUploading = false;

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
    _tagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear Post'),
        centerTitle: true,
        elevation: 2,
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        actions: [
          if (_isSubmitting)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: _canSubmit() ? _submitPost : null,
              child: Text(
                'Publicar',
                style: TextStyle(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCategorySelector(),
            const SizedBox(height: 16),
            _buildTitleField(),
            const SizedBox(height: 16),
            _buildContentField(),
            const SizedBox(height: 16),
            _buildTagsSection(),
            const SizedBox(height: 24),
            _buildMediaSection(),
            const SizedBox(height: 24),
            _buildAttachmentsPreview(),
            const SizedBox(height: 100), // Espacio extra para botones flotantes
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildCategorySelector() {
    return DropdownButtonFormField<String>(
      value: _selectedCategory,
      decoration: InputDecoration(
        labelText: 'Categoría (opcional)',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        prefixIcon: const Icon(Icons.category),
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
    );
  }

  Widget _buildTitleField() {
    return TextField(
      controller: _titleController,
      decoration: InputDecoration(
        labelText: 'Título *',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        prefixIcon: const Icon(Icons.title),
        counterText: '${_titleController.text.length}/100',
      ),
      maxLength: 100,
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildContentField() {
    return TextField(
      controller: _contentController,
      decoration: InputDecoration(
        labelText: 'Contenido *',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        prefixIcon: const Icon(Icons.description),
        alignLabelWithHint: true,
        counterText: '${_contentController.text.length}/2000',
      ),
      maxLines: 6,
      maxLength: 2000,
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildTagsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tags (opcional)',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _tagController,
                decoration: InputDecoration(
                  hintText: 'Agregar tag...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.tag),
                ),
                onSubmitted: _addTag,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () => _addTag(_tagController.text),
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        if (_tags.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _tags.map((tag) {
              return Chip(
                label: Text('#$tag'),
                deleteIcon: const Icon(Icons.close, size: 18),
                onDeleted: () => _removeTag(tag),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildMediaSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Multimedia',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMediaButton(
                icon: Icons.image,
                label: 'Imágenes',
                onPressed: _isUploading ? null : _pickImages,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMediaButton(
                icon: Icons.videocam,
                label: 'Video',
                onPressed: _isUploading ? null : _pickVideo,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMediaButton(
                icon: Icons.attach_file,
                label: 'Archivo',
                onPressed: _isUploading ? null : _pickDocument,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMediaButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _buildAttachmentsPreview() {
    final hasAttachments = _selectedImages.isNotEmpty || 
                         _selectedVideos.isNotEmpty || 
                         _selectedDocuments.isNotEmpty;
    
    if (!hasAttachments) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Archivos adjuntos',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
        ),
        const SizedBox(height: 12),
        
        // Imágenes
        if (_selectedImages.isNotEmpty) ...[
          Text('Imágenes (${_selectedImages.length})',
               style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _selectedImages.length,
              itemBuilder: (context, index) {
                final image = _selectedImages[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(image.path),
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: InkWell(
                          onTap: () => _removeImage(index),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 14,
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
          const SizedBox(height: 16),
        ],
        
        // Videos
        if (_selectedVideos.isNotEmpty) ...[
          ...(_selectedVideos.map((video) {
            return Card(
              child: ListTile(
                leading: const Icon(Icons.videocam),
                title: Text(video.name),
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => _removeVideo(video),
                ),
              ),
            );
          })),
          const SizedBox(height: 16),
        ],
        
        // Documentos
        if (_selectedDocuments.isNotEmpty) ...[
          ...(_selectedDocuments.map((doc) {
            return Card(
              child: ListTile(
                leading: const Icon(Icons.description),
                title: Text(doc.name),
                subtitle: Text(_mediaService.formatFileSize(doc.size)),
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => _removeDocument(doc),
                ),
              ),
            );
          })),
        ],
      ],
    );
  }

  Widget _buildBottomBar() {
    if (_isSubmitting || _isUploading) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            top: BorderSide(color: Theme.of(context).dividerColor),
          ),
        ),
        child: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Text(_isUploading ? 'Subiendo archivos...' : 'Publicando post...'),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: CustomButton(
              text: 'Publicar Post',
              onPressed: _canSubmit() ? _submitPost : null,
              icon: Icons.send,
            ),
          ),
        ],
      ),
    );
  }

  // ===== MÉTODOS DE FUNCIONALIDAD =====

  bool _canSubmit() {
    return _titleController.text.trim().isNotEmpty &&
           _contentController.text.trim().isNotEmpty &&
           !_isSubmitting &&
           !_isUploading;
  }

  void _addTag(String tag) {
    final cleanTag = tag.trim().toLowerCase();
    if (cleanTag.isNotEmpty && !_tags.contains(cleanTag) && _tags.length < 5) {
      setState(() {
        _tags.add(cleanTag);
        _tagController.clear();
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
  }

  // ===== SELECCIÓN DE ARCHIVOS =====

  Future<void> _pickImages() async {
    try {
      setState(() => _isUploading = true);
      final images = await _mediaService.pickMultipleImages();
      setState(() {
        _selectedImages.addAll(images);
        _isUploading = false;
      });
    } catch (e) {
      setState(() => _isUploading = false);
      _showError('Error seleccionando imágenes: $e');
    }
  }

  Future<void> _pickVideo() async {
    try {
      setState(() => _isUploading = true);
      final video = await _mediaService.pickVideo();
      if (video != null) {
        setState(() {
          _selectedVideos.add(video);
        });
      }
    } catch (e) {
      _showError('Error seleccionando video: $e');
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Future<void> _pickDocument() async {
    try {
      setState(() => _isUploading = true);
      final document = await _mediaService.pickFile();
      if (document != null) {
        setState(() {
          _selectedDocuments.add(document);
        });
      }
    } catch (e) {
      _showError('Error seleccionando documento: $e');
    } finally {
      setState(() => _isUploading = false);
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  void _removeVideo(XFile video) {
    setState(() {
      _selectedVideos.remove(video);
    });
  }

  void _removeDocument(PlatformFile document) {
    setState(() {
      _selectedDocuments.remove(document);
    });
  }

  // ===== ENVÍO DEL POST =====

  Future<void> _submitPost() async {
    if (!_canSubmit()) return;

    setState(() => _isSubmitting = true);

    try {
      final user = _authService.currentUser!;
      final tempPostId = DateTime.now().millisecondsSinceEpoch.toString();
      
      // Subir archivos multimedia
      List<MediaAttachment> mediaAttachments = [];
      
      if (_selectedImages.isNotEmpty || _selectedVideos.isNotEmpty || _selectedDocuments.isNotEmpty) {
        setState(() => _isUploading = true);
        
        // Subir imágenes
        for (final image in _selectedImages) {
          final attachment = await _mediaService.uploadImage(image, tempPostId);
          mediaAttachments.add(attachment);
        }
        
        // Subir videos
        for (final video in _selectedVideos) {
          final attachment = await _mediaService.uploadVideo(video, tempPostId);
          mediaAttachments.add(attachment);
        }
        
        // Subir documentos
        for (final doc in _selectedDocuments) {
          final attachment = await _mediaService.uploadDocument(doc, tempPostId);
          mediaAttachments.add(attachment);
        }
        
        setState(() => _isUploading = false);
      }

      // Crear post
      final post = ForumPost(
        id: '',
        titulo: _titleController.text.trim(),
        contenido: _contentController.text.trim(),
        autorId: user.uid,
        autorNombre: user.nombre ?? 'Usuario',
        fechaCreacion: DateTime.now(),
        fechaActualizacion: DateTime.now(),
        categoria: _selectedCategory,
        tags: _tags,
        mediaAttachments: mediaAttachments,
      );

      await _forumService.createPost(post);

      if (mounted) {
        Navigator.pop(context, true); // Retornar true para indicar éxito
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post creado exitosamente')),
        );
      }
    } catch (e) {
      if (mounted) {
        _showError('Error creando post: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _isUploading = false;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}