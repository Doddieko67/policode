import 'dart:io';
import 'package:flutter/material.dart';
import 'package:policode/models/forum_model.dart';
import 'package:policode/services/auth_service.dart';
import 'package:policode/services/forum_service.dart';
import 'package:policode/services/media_service.dart';
import 'package:policode/widgets/custom_button.dart';
import 'package:policode/widgets/loading_widgets.dart';
import 'package:policode/widgets/media_widgets.dart';

/// Pantalla para editar una respuesta del foro con soporte multimedia
class EditReplyScreen extends StatefulWidget {
  final ForumReply reply;

  const EditReplyScreen({
    super.key,
    required this.reply,
  });

  @override
  State<EditReplyScreen> createState() => _EditReplyScreenState();
}

class _EditReplyScreenState extends State<EditReplyScreen> {
  final TextEditingController _contentController = TextEditingController();
  final ForumService _forumService = ForumService();
  final AuthService _authService = AuthService();
  final MediaService _mediaService = MediaService();
  
  // Media attachments
  List<File> _selectedFiles = [];
  List<MediaAttachment> _existingAttachments = [];
  
  bool _isSubmitting = false;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _contentController.text = widget.reply.contenido;
    _existingAttachments = List.from(widget.reply.mediaAttachments);
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickMedia() async {
    final files = await _mediaService.pickMultipleMedia();
    if (files.isNotEmpty) {
      setState(() {
        _selectedFiles.addAll(files);
      });
    }
  }

  void _removeSelectedFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });
  }

  void _removeExistingFile(int index) {
    setState(() {
      _existingAttachments.removeAt(index);
    });
  }

  Future<void> _submitReply() async {
    if (_contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El contenido no puede estar vacío')),
      );
      return;
    }

    if (!_authService.isSignedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes iniciar sesión para editar')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Subir nuevos archivos multimedia si hay alguno seleccionado
      final newMediaAttachments = <MediaAttachment>[];
      if (_selectedFiles.isNotEmpty) {
        setState(() => _isUploading = true);
        
        for (final file in _selectedFiles) {
          final attachment = await _mediaService.uploadForumMedia(
            file: file,
            userId: _authService.currentUser!.uid,
            postId: widget.reply.postId,
          );
          if (attachment != null) {
            newMediaAttachments.add(attachment);
          }
        }
        
        setState(() => _isUploading = false);
      }

      // Combinar archivos existentes con los nuevos
      final allAttachments = [..._existingAttachments, ...newMediaAttachments];

      // Actualizar la respuesta
      final updatedData = {
        'contenido': _contentController.text.trim(),
        'mediaAttachments': allAttachments.map((a) => a.toFirestore()).toList(),
      };

      await _forumService.updateReply(widget.reply.id, updatedData);

      if (mounted) {
        Navigator.pop(context, true); // Retornar true para indicar que se actualizó
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Respuesta actualizada exitosamente')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error actualizando respuesta: $e')),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Respuesta'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : _submitReply,
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    'Guardar',
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
            // Campo de contenido
            TextField(
              controller: _contentController,
              decoration: InputDecoration(
                labelText: 'Contenido de la respuesta',
                hintText: 'Escribe el contenido de tu respuesta aquí...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                alignLabelWithHint: true,
              ),
              maxLines: 8,
              textInputAction: TextInputAction.newline,
            ),

            const SizedBox(height: 24),

            // Archivos multimedia existentes
            if (_existingAttachments.isNotEmpty) ...[
              Text(
                'Archivos actuales',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              AttachmentsList(attachments: _existingAttachments),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _existingAttachments.asMap().entries.map((entry) {
                  final index = entry.key;
                  final attachment = entry.value;
                  return Chip(
                    label: Text(attachment.fileName),
                    onDeleted: () => _removeExistingFile(index),
                    deleteIcon: const Icon(Icons.close, size: 18),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
            ],

            // Botón para agregar archivos
            Card(
              child: InkWell(
                onTap: _pickMedia,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.attach_file,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Agregar archivos multimedia',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.add,
                        color: theme.colorScheme.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Mostrar archivos seleccionados
            if (_selectedFiles.isNotEmpty) ...[
              Text(
                'Nuevos archivos (${_selectedFiles.length})',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedFiles.length,
                  itemBuilder: (context, index) {
                    final file = _selectedFiles[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Stack(
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: theme.colorScheme.outline.withOpacity(0.3),
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: _mediaService.isImageFile(file.path)
                                  ? Image.file(
                                      file,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return const Center(
                                          child: Icon(Icons.broken_image),
                                        );
                                      },
                                    )
                                  : Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            _getFileIcon(file.path),
                                            size: 32,
                                            color: theme.colorScheme.primary,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            file.path.split('/').last,
                                            style: theme.textTheme.labelSmall,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                                    ),
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () => _removeSelectedFile(index),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.error,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  size: 16,
                                  color: Colors.white,
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
              const SizedBox(height: 24),
            ],

            // Mensaje de carga
            if (_isUploading)
              const Column(
                children: [
                  LoadingWidget(),
                  SizedBox(height: 8),
                  Text('Subiendo archivos...'),
                  SizedBox(height: 24),
                ],
              ),

            // Información adicional
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 20,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Información',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Los cambios se guardarán inmediatamente\n'
                    '• Puedes eliminar archivos existentes\n'
                    '• Formatos soportados: imágenes, videos, documentos\n'
                    '• Tamaño máximo: 50MB por archivo',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
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

  IconData _getFileIcon(String path) {
    if (_mediaService.isVideoFile(path)) {
      return Icons.video_file;
    } else if (_mediaService.isImageFile(path)) {
      return Icons.image;
    } else {
      final ext = path.split('.').last.toLowerCase();
      if (['pdf'].contains(ext)) {
        return Icons.picture_as_pdf;
      } else if (['doc', 'docx'].contains(ext)) {
        return Icons.description;
      } else {
        return Icons.insert_drive_file;
      }
    }
  }
}