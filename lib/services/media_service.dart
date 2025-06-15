import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:policode/models/forum_model.dart';

/// Servicio para manejar subida y descarga de archivos multimedia
class MediaService {
  static final MediaService _instance = MediaService._internal();
  factory MediaService() => _instance;
  MediaService._internal();

  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _imagePicker = ImagePicker();

  /// Referencia base para archivos del foro
  Reference get _forumRef => _storage.ref().child('forum');

  // ===== SELECCIÓN DE ARCHIVOS =====

  /// Seleccionar imagen desde cámara o galería
  Future<XFile?> pickImage({ImageSource source = ImageSource.gallery}) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      return image;
    } catch (e) {
      throw Exception('Error seleccionando imagen: $e');
    }
  }

  /// Seleccionar múltiples imágenes
  Future<List<XFile>> pickMultipleImages() async {
    try {
      final List<XFile> images = await _imagePicker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      return images;
    } catch (e) {
      throw Exception('Error seleccionando imágenes: $e');
    }
  }

  /// Seleccionar video
  Future<XFile?> pickVideo({ImageSource source = ImageSource.gallery}) async {
    try {
      final XFile? video = await _imagePicker.pickVideo(
        source: source,
        maxDuration: const Duration(minutes: 5), // Máximo 5 minutos
      );
      return video;
    } catch (e) {
      throw Exception('Error seleccionando video: $e');
    }
  }

  /// Seleccionar archivo general
  Future<PlatformFile?> pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'ppt', 'pptx', 'xls', 'xlsx'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.size <= 10 * 1024 * 1024) { // Max 10MB
        return result.files.first;
      }
      
      if (result != null && result.files.single.size > 10 * 1024 * 1024) {
        throw Exception('El archivo es demasiado grande (máximo 10MB)');
      }
      
      return null;
    } catch (e) {
      throw Exception('Error seleccionando archivo: $e');
    }
  }

  /// Seleccionar múltiples archivos multimedia (imágenes, videos y documentos)
  Future<List<File>> pickMultipleMedia() async {
    try {
      final List<File> files = [];
      
      // Mostrar dialog de opciones
      // Por simplicidad, vamos a usar el selector de archivos general
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'webp', 'mp4', 'avi', 'mov', 'wmv', 'pdf', 'doc', 'docx', 'txt'],
        allowMultiple: true,
      );

      if (result != null) {
        for (PlatformFile file in result.files) {
          if (file.path != null) {
            files.add(File(file.path!));
          }
        }
      }
      
      return files;
    } catch (e) {
      throw Exception('Error seleccionando archivos: $e');
    }
  }

  // ===== SUBIDA DE ARCHIVOS =====

  /// Subir imagen y obtener MediaAttachment
  Future<MediaAttachment> uploadImage(XFile imageFile, String postId) async {
    try {
      final String fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(imageFile.path)}';
      final Reference ref = _forumRef.child('images').child(postId).child(fileName);

      // Subir archivo
      final UploadTask uploadTask = ref.putFile(File(imageFile.path));
      final TaskSnapshot snapshot = await uploadTask;
      
      // Obtener URL de descarga
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      
      // Obtener información del archivo
      final File file = File(imageFile.path);
      final int fileSize = await file.length();
      
      return MediaAttachment(
        id: ref.name,
        url: downloadUrl,
        fileName: path.basename(imageFile.path),
        type: MediaType.image,
        fileSize: fileSize,
        aspectRatio: await _getImageAspectRatio(imageFile),
      );
    } catch (e) {
      throw Exception('Error subiendo imagen: $e');
    }
  }

  /// Subir video y obtener MediaAttachment
  Future<MediaAttachment> uploadVideo(XFile videoFile, String postId) async {
    try {
      final String fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(videoFile.path)}';
      final Reference ref = _forumRef.child('videos').child(postId).child(fileName);

      // Verificar tamaño del archivo (max 50MB para videos)
      final File file = File(videoFile.path);
      final int fileSize = await file.length();
      
      if (fileSize > 50 * 1024 * 1024) {
        throw Exception('El video es demasiado grande (máximo 50MB)');
      }

      // Subir archivo
      final UploadTask uploadTask = ref.putFile(file);
      final TaskSnapshot snapshot = await uploadTask;
      
      // Obtener URL de descarga
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      
      return MediaAttachment(
        id: ref.name,
        url: downloadUrl,
        fileName: path.basename(videoFile.path),
        type: MediaType.video,
        fileSize: fileSize,
      );
    } catch (e) {
      throw Exception('Error subiendo video: $e');
    }
  }

  /// Subir archivo de documento
  Future<MediaAttachment> uploadDocument(PlatformFile file, String postId) async {
    try {
      final String fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      final Reference ref = _forumRef.child('documents').child(postId).child(fileName);

      Uint8List? fileBytes = file.bytes;
      if (fileBytes == null && file.path != null) {
        fileBytes = await File(file.path!).readAsBytes();
      }
      
      if (fileBytes == null) {
        throw Exception('No se pudo leer el archivo');
      }

      // Subir archivo
      final UploadTask uploadTask = ref.putData(fileBytes);
      final TaskSnapshot snapshot = await uploadTask;
      
      // Obtener URL de descarga
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      
      return MediaAttachment(
        id: ref.name,
        url: downloadUrl,
        fileName: file.name,
        type: MediaType.document,
        fileSize: file.size,
      );
    } catch (e) {
      throw Exception('Error subiendo documento: $e');
    }
  }

  /// Subir múltiples archivos
  Future<List<MediaAttachment>> uploadMultipleFiles(
    List<dynamic> files, // List<XFile> o List<PlatformFile>
    String postId,
  ) async {
    final List<MediaAttachment> attachments = [];
    
    for (final file in files) {
      try {
        if (file is XFile) {
          if (_isImageFile(file.path)) {
            final attachment = await uploadImage(file, postId);
            attachments.add(attachment);
          } else if (_isVideoFile(file.path)) {
            final attachment = await uploadVideo(file, postId);
            attachments.add(attachment);
          }
        } else if (file is PlatformFile) {
          final attachment = await uploadDocument(file, postId);
          attachments.add(attachment);
        }
      } catch (e) {
        // Log error pero continúa con otros archivos
        print('Error subiendo archivo ${file is XFile ? file.name : (file as PlatformFile).name}: $e');
      }
    }
    
    return attachments;
  }

  /// Subir archivo multimedia para el foro
  Future<MediaAttachment?> uploadForumMedia({
    required File file,
    required String userId,
    required String postId,
  }) async {
    try {
      final String fileName = path.basename(file.path);
      final String extension = path.extension(fileName).toLowerCase();
      
      if (_isImageFile(fileName)) {
        // Subir como imagen
        final xFile = XFile(file.path);
        return await uploadImage(xFile, postId);
      } else if (_isVideoFile(fileName)) {
        // Subir como video
        final xFile = XFile(file.path);
        return await uploadVideo(xFile, postId);
      } else {
        // Subir como documento
        final bytes = await file.readAsBytes();
        final platformFile = PlatformFile(
          name: fileName,
          size: bytes.length,
          bytes: bytes,
          path: file.path,
        );
        return await uploadDocument(platformFile, postId);
      }
    } catch (e) {
      print('Error subiendo archivo multimedia: $e');
      return null;
    }
  }

  // ===== ELIMINACIÓN DE ARCHIVOS =====

  /// Eliminar archivo multimedia
  Future<void> deleteMediaFile(String fileUrl) async {
    try {
      final Reference ref = _storage.refFromURL(fileUrl);
      await ref.delete();
    } catch (e) {
      // Si el archivo no existe, no es un error crítico
      print('Error eliminando archivo: $e');
    }
  }

  /// Eliminar múltiples archivos
  Future<void> deleteMultipleFiles(List<String> fileUrls) async {
    for (final url in fileUrls) {
      await deleteMediaFile(url);
    }
  }

  // ===== MÉTODOS DE UTILIDAD =====

  /// Verificar si un archivo es una imagen
  bool _isImageFile(String filePath) {
    final extension = path.extension(filePath).toLowerCase();
    return ['.jpg', '.jpeg', '.png', '.gif', '.webp'].contains(extension);
  }

  /// Verificar si un archivo es un video
  bool _isVideoFile(String filePath) {
    final extension = path.extension(filePath).toLowerCase();
    return ['.mp4', '.avi', '.mov', '.wmv', '.flv', '.webm'].contains(extension);
  }

  /// Verificar si un archivo es una imagen (método público)
  bool isImageFile(String filePath) {
    return _isImageFile(filePath);
  }

  /// Verificar si un archivo es un video (método público)
  bool isVideoFile(String filePath) {
    return _isVideoFile(filePath);
  }

  /// Obtener la relación de aspecto de una imagen
  Future<double?> _getImageAspectRatio(XFile imageFile) async {
    try {
      // En una implementación real, usarías un package como 'image' para obtener las dimensiones
      // Por simplicidad, retornamos null por ahora
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Formatear tamaño de archivo legible
  String formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = 0;
    double size = bytes.toDouble();
    
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    
    return '${size.toStringAsFixed(1)} ${suffixes[i]}';
  }

  /// Obtener extensión de archivo desde URL
  String getFileExtension(String url) {
    try {
      final uri = Uri.parse(url);
      return path.extension(uri.path).toLowerCase();
    } catch (e) {
      return '';
    }
  }

  /// Verificar si una URL es una imagen
  bool isImageUrl(String url) {
    final extension = getFileExtension(url);
    return ['.jpg', '.jpeg', '.png', '.gif', '.webp'].contains(extension);
  }

  /// Verificar si una URL es un video
  bool isVideoUrl(String url) {
    final extension = getFileExtension(url);
    return ['.mp4', '.avi', '.mov', '.wmv', '.flv', '.webm'].contains(extension);
  }
}