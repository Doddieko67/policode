import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:policode/models/forum_model.dart';
import 'package:policode/services/media_service.dart';
import 'package:url_launcher/url_launcher.dart';

/// Widget para mostrar una galería de imágenes
class ImageGallery extends StatefulWidget {
  final List<MediaAttachment> images;
  final int initialIndex;

  const ImageGallery({
    super.key,
    required this.images,
    this.initialIndex = 0,
  });

  @override
  State<ImageGallery> createState() => _ImageGalleryState();
}

class _ImageGalleryState extends State<ImageGallery> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 250,
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.images.length,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
            },
            itemBuilder: (context, index) {
              final image = widget.images[index];
              return GestureDetector(
                onTap: () => _showFullscreenImage(context, index),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: image.url,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[300],
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[300],
                        child: const Icon(Icons.error, color: Colors.red),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (widget.images.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ...List.generate(widget.images.length, (index) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentIndex == index
                        ? Theme.of(context).primaryColor
                        : Colors.grey[400],
                  ),
                );
              }),
              const SizedBox(width: 8),
              Text(
                '${_currentIndex + 1}/${widget.images.length}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ],
    );
  }

  void _showFullscreenImage(BuildContext context, int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullscreenImageGallery(
          images: widget.images,
          initialIndex: initialIndex,
        ),
      ),
    );
  }
}

/// Galería de imágenes en pantalla completa
class FullscreenImageGallery extends StatefulWidget {
  final List<MediaAttachment> images;
  final int initialIndex;

  const FullscreenImageGallery({
    super.key,
    required this.images,
    this.initialIndex = 0,
  });

  @override
  State<FullscreenImageGallery> createState() => _FullscreenImageGalleryState();
}

class _FullscreenImageGalleryState extends State<FullscreenImageGallery> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_currentIndex + 1} de ${widget.images.length}'),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.images.length,
        onPageChanged: (index) {
          setState(() => _currentIndex = index);
        },
        itemBuilder: (context, index) {
          final image = widget.images[index];
          return InteractiveViewer(
            child: Center(
              child: CachedNetworkImage(
                imageUrl: image.url,
                fit: BoxFit.contain,
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
                errorWidget: (context, url, error) => const Center(
                  child: Icon(Icons.error, color: Colors.white, size: 48),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Widget para mostrar un video
class VideoPlayerWidget extends StatefulWidget {
  final MediaAttachment video;
  final bool autoPlay;

  const VideoPlayerWidget({
    super.key,
    required this.video,
    this.autoPlay = false,
  });

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _initializeVideo() async {
    try {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.video.url));
      await _controller.initialize();
      
      if (mounted) {
        setState(() => _isInitialized = true);
        
        if (widget.autoPlay) {
          _controller.play();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _hasError = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error, color: Colors.red, size: 48),
              SizedBox(height: 8),
              Text('Error cargando video'),
            ],
          ),
        ),
      );
    }

    if (!_isInitialized) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        aspectRatio: _controller.value.aspectRatio,
        child: Stack(
          alignment: Alignment.center,
          children: [
            VideoPlayer(_controller),
            _VideoControls(controller: _controller),
          ],
        ),
      ),
    );
  }
}

/// Controles para el reproductor de video
class _VideoControls extends StatefulWidget {
  final VideoPlayerController controller;

  const _VideoControls({required this.controller});

  @override
  State<_VideoControls> createState() => _VideoControlsState();
}

class _VideoControlsState extends State<_VideoControls> {
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_updateState);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_updateState);
    super.dispose();
  }

  void _updateState() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() => _showControls = !_showControls);
      },
      child: Container(
        color: Colors.transparent,
        child: AnimatedOpacity(
          opacity: _showControls ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.3),
                  Colors.transparent,
                  Colors.black.withOpacity(0.3),
                ],
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top controls
                const SizedBox(height: 8),
                
                // Center play/pause button
                Expanded(
                  child: Center(
                    child: IconButton(
                      onPressed: () {
                        if (widget.controller.value.isPlaying) {
                          widget.controller.pause();
                        } else {
                          widget.controller.play();
                        }
                      },
                      icon: Icon(
                        widget.controller.value.isPlaying
                            ? Icons.pause_circle_outline
                            : Icons.play_circle_outline,
                        size: 64,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                
                // Bottom progress bar
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: VideoProgressIndicator(
                    widget.controller,
                    allowScrubbing: true,
                    colors: VideoProgressColors(
                      playedColor: Theme.of(context).primaryColor,
                      backgroundColor: Colors.white.withOpacity(0.3),
                      bufferedColor: Colors.white.withOpacity(0.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Widget para mostrar archivos adjuntos
class AttachmentsList extends StatelessWidget {
  final List<MediaAttachment> attachments;

  const AttachmentsList({
    super.key,
    required this.attachments,
  });

  @override
  Widget build(BuildContext context) {
    if (attachments.isEmpty) return const SizedBox();

    final images = attachments.where((a) => a.type == MediaType.image).toList();
    final videos = attachments.where((a) => a.type == MediaType.video).toList();
    final documents = attachments.where((a) => a.type == MediaType.document).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Imágenes
        if (images.isNotEmpty) ...[
          ImageGallery(images: images),
          const SizedBox(height: 12),
        ],
        
        // Videos
        ...videos.map((video) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: VideoPlayerWidget(video: video),
            )),
        
        // Documentos
        if (documents.isNotEmpty) ...[
          ...documents.map((doc) => _DocumentTile(document: doc)),
        ],
      ],
    );
  }
}

/// Widget para mostrar un documento
class _DocumentTile extends StatelessWidget {
  final MediaAttachment document;

  const _DocumentTile({required this.document});

  @override
  Widget build(BuildContext context) {
    final mediaService = MediaService();
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: _getDocumentIcon(),
        title: Text(
          document.fileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(mediaService.formatFileSize(document.fileSize)),
        trailing: IconButton(
          icon: const Icon(Icons.download),
          onPressed: () => _downloadDocument(context),
        ),
        onTap: () => _downloadDocument(context),
      ),
    );
  }

  Widget _getDocumentIcon() {
    final extension = MediaService().getFileExtension(document.url);
    
    switch (extension) {
      case '.pdf':
        return const Icon(Icons.picture_as_pdf, color: Colors.red);
      case '.doc':
      case '.docx':
        return const Icon(Icons.description, color: Colors.blue);
      case '.xls':
      case '.xlsx':
        return const Icon(Icons.table_chart, color: Colors.green);
      case '.ppt':
      case '.pptx':
        return const Icon(Icons.slideshow, color: Colors.orange);
      default:
        return const Icon(Icons.attach_file);
    }
  }

  Future<void> _downloadDocument(BuildContext context) async {
    try {
      final Uri url = Uri.parse(document.url);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        throw 'No se puede abrir el archivo';
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error abriendo archivo: $e')),
        );
      }
    }
  }
}

/// Widget para mostrar una vista previa compacta de archivos multimedia
class MediaPreview extends StatelessWidget {
  final List<MediaAttachment> attachments;
  final int maxItems;

  const MediaPreview({
    super.key,
    required this.attachments,
    this.maxItems = 3,
  });

  @override
  Widget build(BuildContext context) {
    if (attachments.isEmpty) return const SizedBox();

    final images = attachments.where((a) => a.type == MediaType.image).toList();
    final videos = attachments.where((a) => a.type == MediaType.video).toList();
    final documents = attachments.where((a) => a.type == MediaType.document).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Imágenes en miniatura
        if (images.isNotEmpty) ...[
          SizedBox(
            height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: images.length.clamp(0, maxItems),
              itemBuilder: (context, index) {
                final image = images[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: GestureDetector(
                    onTap: () => _showFullGallery(context, images, index),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: image.url,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              width: 60,
                              height: 60,
                              color: Colors.grey[300],
                              child: const Icon(Icons.image),
                            ),
                          ),
                        ),
                        if (index == maxItems - 1 && images.length > maxItems)
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                '+${images.length - maxItems + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
        
        // Indicadores de videos y documentos
        if (videos.isNotEmpty || documents.isNotEmpty)
          Wrap(
            spacing: 8,
            children: [
              if (videos.isNotEmpty)
                Chip(
                  avatar: const Icon(Icons.videocam, size: 16),
                  label: Text('${videos.length} video${videos.length > 1 ? 's' : ''}'),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              if (documents.isNotEmpty)
                Chip(
                  avatar: const Icon(Icons.attach_file, size: 16),
                  label: Text('${documents.length} archivo${documents.length > 1 ? 's' : ''}'),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
            ],
          ),
      ],
    );
  }

  void _showFullGallery(BuildContext context, List<MediaAttachment> images, int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullscreenImageGallery(
          images: images,
          initialIndex: index,
        ),
      ),
    );
  }
}