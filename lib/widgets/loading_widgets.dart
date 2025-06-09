import 'package:flutter/material.dart';

/// Tipos de loading disponibles
enum LoadingType {
  circular, // Circular progress indicator
  linear, // Linear progress indicator
  dots, // Three bouncing dots
  pulse, // Pulsing circle
  skeleton, // Skeleton loading (shimmer)
}

/// Widget de loading personalizado
class LoadingWidget extends StatefulWidget {
  final LoadingType type;
  final String? message;
  final Color? color;
  final double size;
  final bool showMessage;
  final EdgeInsetsGeometry? padding;

  const LoadingWidget({
    super.key,
    this.type = LoadingType.circular,
    this.message,
    this.color,
    this.size = 40,
    this.showMessage = true,
    this.padding,
  });

  // Factory constructors para casos comunes
  factory LoadingWidget.circular({
    String? message,
    Color? color,
    double size = 40,
  }) {
    return LoadingWidget(
      type: LoadingType.circular,
      message: message,
      color: color,
      size: size,
    );
  }

  factory LoadingWidget.dots({
    String? message,
    Color? color,
    double size = 40,
  }) {
    return LoadingWidget(
      type: LoadingType.dots,
      message: message,
      color: color,
      size: size,
    );
  }

  factory LoadingWidget.pulse({
    String? message,
    Color? color,
    double size = 40,
  }) {
    return LoadingWidget(
      type: LoadingType.pulse,
      message: message,
      color: color,
      size: size,
    );
  }

  @override
  State<LoadingWidget> createState() => _LoadingWidgetState();
}

class _LoadingWidgetState extends State<LoadingWidget>
    with TickerProviderStateMixin {
  late AnimationController _dotsController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  void _initAnimations() {
    _dotsController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.type == LoadingType.dots) {
      _dotsController.repeat();
    }

    if (widget.type == LoadingType.pulse) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _dotsController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = widget.color ?? theme.primaryColor;
    final message = widget.message ?? 'Cargando...';

    return Container(
      padding: widget.padding ?? const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildLoadingIndicator(color),
          if (widget.showMessage && message.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator(Color color) {
    switch (widget.type) {
      case LoadingType.circular:
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(color),
            strokeWidth: 3,
          ),
        );

      case LoadingType.linear:
        return SizedBox(
          width: widget.size * 2,
          child: LinearProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(color),
            backgroundColor: color.withOpacity(0.2),
          ),
        );

      case LoadingType.dots:
        return _buildDotsIndicator(color);

      case LoadingType.pulse:
        return _buildPulseIndicator(color);

      case LoadingType.skeleton:
        return _buildSkeletonIndicator();
    }
  }

  Widget _buildDotsIndicator(Color color) {
    return SizedBox(
      width: widget.size,
      height: widget.size * 0.3,
      child: AnimatedBuilder(
        animation: _dotsController,
        builder: (context, child) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(3, (index) {
              final delay = index * 0.2;
              final animationValue = (_dotsController.value - delay).clamp(
                0.0,
                1.0,
              );
              final scale = Curves.elasticOut.transform(animationValue);

              return Transform.scale(
                scale: scale,
                child: Container(
                  width: widget.size * 0.2,
                  height: widget.size * 0.2,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }

  Widget _buildPulseIndicator(Color color) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: color.withOpacity(0.7),
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }

  Widget _buildSkeletonIndicator() {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}

/// Widget de error personalizado
class CustomErrorWidget extends StatelessWidget {
  final String title;
  final String? message;
  final IconData? icon;
  final VoidCallback? onRetry;
  final String? retryText;
  final bool showIcon;
  final EdgeInsetsGeometry? padding;

  const CustomErrorWidget({
    super.key,
    required this.title,
    this.message,
    this.icon,
    this.onRetry,
    this.retryText,
    this.showIcon = true,
    this.padding,
  });

  // Factory constructors para casos comunes
  factory CustomErrorWidget.network({
    VoidCallback? onRetry,
    String? retryText,
  }) {
    return CustomErrorWidget(
      title: 'Sin conexión',
      message: 'Verifica tu conexión a internet e intenta de nuevo',
      icon: Icons.wifi_off,
      onRetry: onRetry,
      retryText: retryText ?? 'Reintentar',
    );
  }

  factory CustomErrorWidget.server({VoidCallback? onRetry, String? retryText}) {
    return CustomErrorWidget(
      title: 'Error del servidor',
      message: 'Algo salió mal. Por favor intenta más tarde',
      icon: Icons.error_outline,
      onRetry: onRetry,
      retryText: retryText ?? 'Reintentar',
    );
  }

  factory CustomErrorWidget.notFound({String? customMessage}) {
    return CustomErrorWidget(
      title: 'No se encontró información',
      message: customMessage ?? 'No hay resultados para mostrar',
      icon: Icons.search_off,
      showIcon: true,
    );
  }

  factory CustomErrorWidget.generic({
    String? title,
    String? message,
    VoidCallback? onRetry,
  }) {
    return CustomErrorWidget(
      title: title ?? 'Algo salió mal',
      message: message ?? 'Ocurrió un error inesperado',
      icon: Icons.error_outline,
      onRetry: onRetry,
      retryText: 'Reintentar',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: padding ?? const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon && icon != null) ...[
            Icon(
              icon,
              size: 64,
              color: theme.colorScheme.error.withOpacity(0.7),
            ),
            const SizedBox(height: 16),
          ],
          Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: Colors.amberAccent,
            ),
            textAlign: TextAlign.center,
          ),
          if (message != null) ...[
            const SizedBox(height: 8),
            Text(
              message!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
          if (onRetry != null) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(retryText ?? 'Reintentar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Widget de estado vacío
class EmptyStateWidget extends StatelessWidget {
  final String title;
  final String? message;
  final IconData? icon;
  final VoidCallback? onAction;
  final String? actionText;
  final Widget? customIllustration;
  final EdgeInsetsGeometry? padding;

  const EmptyStateWidget({
    super.key,
    required this.title,
    this.message,
    this.icon,
    this.onAction,
    this.actionText,
    this.customIllustration,
    this.padding,
  });

  // Factory constructors para casos comunes
  factory EmptyStateWidget.noNotes({VoidCallback? onCreateNote}) {
    return EmptyStateWidget(
      title: 'No tienes notas guardadas',
      message:
          'Guarda artículos importantes del reglamento para acceder rápidamente a ellos',
      icon: Icons.bookmark_border,
      onAction: onCreateNote,
      actionText: 'Explorar reglamento',
    );
  }

  factory EmptyStateWidget.noSearchResults({String? query}) {
    return EmptyStateWidget(
      title: 'No se encontraron resultados',
      message: query != null
          ? 'No hay artículos que coincidan con "$query"'
          : 'Intenta con otras palabras clave',
      icon: Icons.search_off,
    );
  }

  factory EmptyStateWidget.noChatHistory() {
    return const EmptyStateWidget(
      title: '¡Hola! ¿En qué puedo ayudarte?',
      message: 'Pregúntame cualquier cosa sobre el reglamento de PoliCode',
      icon: Icons.chat_bubble_outline,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: padding ?? const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (customIllustration != null) ...[
            customIllustration!,
            const SizedBox(height: 24),
          ] else if (icon != null) ...[
            Icon(
              icon,
              size: 80,
              color: theme.colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 24),
          ],
          Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          if (message != null) ...[
            const SizedBox(height: 12),
            Text(
              message!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
          if (onAction != null && actionText != null) ...[
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(actionText!),
            ),
          ],
        ],
      ),
    );
  }
}

/// Overlay de loading para pantalla completa
class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;
  final String? message;
  final Color? overlayColor;

  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.message,
    this.overlayColor,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: overlayColor ?? Colors.black.withOpacity(0.5),
            child: Center(
              child: LoadingWidget.circular(
                message: message,
                color: Colors.white,
              ),
            ),
          ),
      ],
    );
  }
}

/// Skeleton loader para listas
class SkeletonLoader extends StatefulWidget {
  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;

  const SkeletonLoader({
    super.key,
    this.itemCount = 3,
    required this.itemBuilder,
  });

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0.3,
      end: 0.7,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ListView.builder(
          itemCount: widget.itemCount,
          itemBuilder: (context, index) {
            return Opacity(
              opacity: _animation.value,
              child: widget.itemBuilder(context, index),
            );
          },
        );
      },
    );
  }
}
