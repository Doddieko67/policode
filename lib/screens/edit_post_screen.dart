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

/// Pantalla para editar un post existente
class EditPostScreen extends StatefulWidget {
  final ForumPost post;

  const EditPostScreen({
    super.key,
    required this.post,
  });

  @override
  State<EditPostScreen> createState() => _EditPostScreenState();
}

class _EditPostScreenState extends State<EditPostScreen> {
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
  
  // Medios existentes (del post original)
  List<MediaAttachment> _existingMedia = [];
  List<String> _mediaToDelete = []; // IDs de medios a eliminar
  
  bool _isSubmitting = false;
  bool _isUploading = false;

  final List<String> _categories = [
    'General',
    'Reglamento',
    'Académico',
    'Dudas',
  ];

  @override
  void initState() {
    super.initState();
    _initializeFields();
  }

  void _initializeFields() {
    // Inicializar campos con datos del post actual
    _titleController.text = widget.post.titulo;
    _contentController.text = widget.post.contenido;
    _selectedCategory = widget.post.categoria;
    _tags = List.from(widget.post.tags);
    
    // Cargar medios existentes
    _existingMedia = List.from(widget.post.mediaAttachments);
  }

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
        title: const Text('Editar Post'),
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
              onPressed: _submitPost,
              child: Text(
                'Guardar',
                style: TextStyle(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: _isSubmitting
          ? const Center(child: LoadingWidget())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTitleField(),
                  const SizedBox(height: 16),
                  _buildCategoryField(),
                  const SizedBox(height: 16),
                  _buildContentField(),
                  const SizedBox(height: 16),
                  _buildTagsField(),
                  const SizedBox(height: 16),
                  _buildMediaSection(),
                  const SizedBox(height: 32),
                  _buildSubmitButton(),
                ],
              ),
            ),
    );
  }

  Widget _buildTitleField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Título',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _titleController,
          decoration: const InputDecoration(
            hintText: 'Escribe el título de tu post...',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
          textCapitalization: TextCapitalization.sentences,
        ),
      ],
    );
  }

  Widget _buildCategoryField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Categoría',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedCategory,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
          ),
          hint: const Text('Selecciona una categoría'),
          items: _categories.map((category) {
            return DropdownMenuItem(
              value: category,
              child: Text(category),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedCategory = value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildContentField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Contenido',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _contentController,
          decoration: const InputDecoration(
            hintText: 'Escribe el contenido de tu post...',
            border: OutlineInputBorder(),
          ),
          maxLines: 8,
          textCapitalization: TextCapitalization.sentences,
        ),
      ],
    );
  }

  Widget _buildTagsField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Etiquetas',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (_tags.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            children: _tags.map((tag) {
              return Chip(
                label: Text(tag),
                onDeleted: () {
                  setState(() {
                    _tags.remove(tag);
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
        ],
        TextField(
          controller: _tagController,
          decoration: InputDecoration(
            hintText: 'Agregar etiqueta...',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: const Icon(Icons.add),
              onPressed: _addTag,
            ),
          ),
          onSubmitted: (_) => _addTag(),
        ),
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
                onPressed: _isUploading ? null : _pickVideos,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMediaButton(
                icon: Icons.attach_file,
                label: 'Archivo',
                onPressed: _isUploading ? null : _pickDocuments,
              ),
            ),
          ],
        ),
        
        // Mostrar medios existentes y nuevos archivos seleccionados
        if (_existingMedia.isNotEmpty ||
            _selectedImages.isNotEmpty ||
            _selectedVideos.isNotEmpty ||
            _selectedDocuments.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildMediaPreview(),
        ],
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

  Widget _buildMediaPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Mostrar medios existentes
        if (_existingMedia.isNotEmpty) ...[
          const Text('Archivos actuales:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildExistingMedia(),
          const SizedBox(height: 16),
        ],
        
        // Mostrar nuevas imágenes seleccionadas
        if (_selectedImages.isNotEmpty) ...[
          const Text('Nuevas imágenes:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _selectedImages.length,
              itemBuilder: (context, index) {
                return Container(
                  width: 100,
                  margin: const EdgeInsets.only(right: 8),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(_selectedImages[index].path),
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedImages.removeAt(index);
                            });
                          },
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 20,
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
        
        // Mostrar nuevos documentos seleccionados
        if (_selectedDocuments.isNotEmpty) ...[
          const Text('Nuevos documentos:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...(_selectedDocuments.map((doc) {
            return ListTile(
              leading: const Icon(Icons.attach_file),
              title: Text(doc.name),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _selectedDocuments.remove(doc);
                  });
                },
              ),
            );
          }).toList()),
        ],
      ],
    );
  }

  Widget _buildExistingMedia() {
    final existingImages = _existingMedia.where((m) => m.type == MediaType.image).toList();
    final existingVideos = _existingMedia.where((m) => m.type == MediaType.video).toList();
    final existingDocs = _existingMedia.where((m) => m.type == MediaType.document).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Imágenes existentes
        if (existingImages.isNotEmpty) ...[
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: existingImages.length,
              itemBuilder: (context, index) {
                final media = existingImages[index];
                final isMarkedForDeletion = _mediaToDelete.contains(media.id);
                
                return Container(
                  width: 100,
                  margin: const EdgeInsets.only(right: 8),
                  child: Stack(
                    children: [
                      Opacity(
                        opacity: isMarkedForDeletion ? 0.5 : 1.0,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            media.url,
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.image_not_supported),
                              );
                            },
                          ),
                        ),
                      ),
                      if (isMarkedForDeletion)
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.delete_forever,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              if (isMarkedForDeletion) {
                                _mediaToDelete.remove(media.id);
                              } else {
                                _mediaToDelete.add(media.id);
                              }
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: isMarkedForDeletion ? Colors.green : Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isMarkedForDeletion ? Icons.undo : Icons.close,
                              color: Colors.white,
                              size: 20,
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

        // Videos existentes
        if (existingVideos.isNotEmpty) ...[
          ...existingVideos.map((media) {
            final isMarkedForDeletion = _mediaToDelete.contains(media.id);
            return ListTile(
              leading: Icon(
                Icons.video_library,
                color: isMarkedForDeletion ? Colors.grey : null,
              ),
              title: Text(
                media.fileName,
                style: TextStyle(
                  decoration: isMarkedForDeletion ? TextDecoration.lineThrough : null,
                  color: isMarkedForDeletion ? Colors.grey : null,
                ),
              ),
              subtitle: const Text('Video'),
              trailing: IconButton(
                icon: Icon(
                  isMarkedForDeletion ? Icons.undo : Icons.close,
                  color: isMarkedForDeletion ? Colors.green : Colors.red,
                ),
                onPressed: () {
                  setState(() {
                    if (isMarkedForDeletion) {
                      _mediaToDelete.remove(media.id);
                    } else {
                      _mediaToDelete.add(media.id);
                    }
                  });
                },
              ),
            );
          }).toList(),
        ],

        // Documentos existentes
        if (existingDocs.isNotEmpty) ...[
          ...existingDocs.map((media) {
            final isMarkedForDeletion = _mediaToDelete.contains(media.id);
            return ListTile(
              leading: Icon(
                Icons.attach_file,
                color: isMarkedForDeletion ? Colors.grey : null,
              ),
              title: Text(
                media.fileName,
                style: TextStyle(
                  decoration: isMarkedForDeletion ? TextDecoration.lineThrough : null,
                  color: isMarkedForDeletion ? Colors.grey : null,
                ),
              ),
              subtitle: const Text('Documento'),
              trailing: IconButton(
                icon: Icon(
                  isMarkedForDeletion ? Icons.undo : Icons.close,
                  color: isMarkedForDeletion ? Colors.green : Colors.red,
                ),
                onPressed: () {
                  setState(() {
                    if (isMarkedForDeletion) {
                      _mediaToDelete.remove(media.id);
                    } else {
                      _mediaToDelete.add(media.id);
                    }
                  });
                },
              ),
            );
          }).toList(),
        ],
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: CustomButton(
        text: _isSubmitting ? 'Actualizando...' : 'Actualizar Post',
        onPressed: _isSubmitting ? null : _submitPost,
        icon: Icons.save,
      ),
    );
  }

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _tagController.clear();
      });
    }
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage();
    if (images.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(images);
      });
    }
  }

  Future<void> _pickVideos() async {
    final picker = ImagePicker();
    final video = await picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      setState(() {
        _selectedVideos.add(video);
      });
    }
  }

  Future<void> _pickDocuments() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'txt'],
    );
    
    if (result != null) {
      setState(() {
        _selectedDocuments.addAll(result.files);
      });
    }
  }

  Future<void> _submitPost() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El título es requerido')),
      );
      return;
    }

    if (_contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El contenido es requerido')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Subir medios si hay alguno
      List<MediaAttachment> newMediaAttachments = [];

      if (_selectedImages.isNotEmpty || _selectedVideos.isNotEmpty || _selectedDocuments.isNotEmpty) {
        setState(() => _isUploading = true);
        
        // Subir imágenes
        for (final image in _selectedImages) {
          final attachment = await _mediaService.uploadImage(image, widget.post.id);
          newMediaAttachments.add(attachment);
        }
        
        // Subir videos
        for (final video in _selectedVideos) {
          final attachment = await _mediaService.uploadVideo(video, widget.post.id);
          newMediaAttachments.add(attachment);
        }
        
        // Subir documentos
        for (final doc in _selectedDocuments) {
          final attachment = await _mediaService.uploadDocument(doc, widget.post.id);
          newMediaAttachments.add(attachment);
        }
        
        setState(() => _isUploading = false);
      }

      // Filtrar medios existentes (remover los marcados para eliminación)
      final remainingExistingMedia = _existingMedia
          .where((media) => !_mediaToDelete.contains(media.id))
          .toList();

      // Crear post actualizado
      final updatedPost = ForumPost(
        id: widget.post.id,
        titulo: _titleController.text.trim(),
        contenido: _contentController.text.trim(),
        autorId: widget.post.autorId,
        autorNombre: widget.post.autorNombre,
        fechaCreacion: widget.post.fechaCreacion,
        fechaActualizacion: DateTime.now(),
        categoria: _selectedCategory ?? 'General',
        tags: _tags,
        likes: widget.post.likes,
        respuestas: widget.post.respuestas,
        mediaAttachments: [...remainingExistingMedia, ...newMediaAttachments],
        isPinned: widget.post.isPinned,
        isClosed: widget.post.isClosed,
      );

      // Actualizar el post
      await _forumService.updateFullPost(updatedPost);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post actualizado exitosamente')),
        );
        Navigator.pop(context, updatedPost); // Retornar el post actualizado
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error actualizando post: $e')),
        );
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
}