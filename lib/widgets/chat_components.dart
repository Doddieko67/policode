// ese es chatbot_components.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:policode/widgets/related_posts_widget.dart';

/// Burbuja de mensaje del chat
class ChatBubble extends StatelessWidget {
  final String message;
  final bool isUser;
  final DateTime timestamp;
  final bool isLoading;
  final bool hasError;
  final List<String>? articulosRelacionados;
  final List<String>? postsRelacionados;
  final List<String>? sugerencias;
  final VoidCallback? onRetry;
  final Function(String)? onArticuloTap;
  final Function(String)? onPostTap;
  final Function(String)? onSugerenciaTap;
  final EdgeInsetsGeometry? margin;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isUser,
    required this.timestamp,
    this.isLoading = false,
    this.hasError = false,
    this.articulosRelacionados,
    this.postsRelacionados,
    this.sugerencias,
    this.onRetry,
    this.onArticuloTap,
    this.onPostTap,
    this.onSugerenciaTap,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[_buildAvatar(theme), const SizedBox(width: 8)],
          Flexible(
            child: Column(
              crossAxisAlignment: isUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                _buildMessageBubble(context, theme),
                if (articulosRelacionados != null &&
                    articulosRelacionados!.isNotEmpty)
                  _buildArticulosRelacionados(theme),
                if (postsRelacionados != null &&
                    postsRelacionados!.isNotEmpty)
                  RelatedPostsWidget(postIds: postsRelacionados!),
                if (sugerencias != null && sugerencias!.isNotEmpty)
                  _buildSugerencias(theme),
                const SizedBox(height: 4),
                _buildTimestamp(theme),
              ],
            ),
          ),
          if (isUser) ...[const SizedBox(width: 8), _buildAvatar(theme)],
        ],
      ),
    );
  }

  Widget _buildAvatar(ThemeData theme) {
    if (isUser) {
      // El avatar del usuario no cambia
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: theme.primaryColor,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.person, color: Colors.white, size: 18),
      );
    } else {
      // El avatar del bot ahora usa tu logo
      return CircleAvatar(
        radius: 16,
        backgroundColor: theme.colorScheme.secondary.withOpacity(0.1),
        backgroundImage: const AssetImage('assets/images/logo.png'),
      );
    }
  }

  Widget _buildMessageBubble(BuildContext context, ThemeData theme) {
    return GestureDetector(
      onLongPress: () => _showMessageOptions(context, theme),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _getBubbleColor(theme),
          borderRadius: _getBorderRadius(),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isLoading)
              _buildLoadingIndicator(theme)
            else if (hasError)
              _buildErrorMessage(theme)
            else
              _buildMessageContent(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageContent(ThemeData theme) {
    // Detectar si el mensaje tiene formato markdown básico
    final hasMarkdown =
        message.contains('**') ||
        message.contains('*') ||
        message.contains('•') ||
        message.contains('\n#');

    if (hasMarkdown) {
      return _buildFormattedMessage(theme);
    }

    return SelectableText(
      message,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: _getTextColor(theme),
        height: 1.4,
      ),
    );
  }

  Widget _buildFormattedMessage(ThemeData theme) {
    // Simple markdown parsing para **bold** y *italic*
    final textColor = _getTextColor(theme);
    final spans = <TextSpan>[];
    final regex = RegExp(r'\*\*(.*?)\*\*|\*(.*?)\*|([^*]+)');
    final matches = regex.allMatches(message);

    for (final match in matches) {
      if (match.group(1) != null) {
        // **Bold**
        spans.add(
          TextSpan(
            text: match.group(1),
            style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
          ),
        );
      } else if (match.group(2) != null) {
        // *Italic*
        spans.add(
          TextSpan(
            text: match.group(2),
            style: TextStyle(fontStyle: FontStyle.italic, color: textColor),
          ),
        );
      } else if (match.group(3) != null) {
        // Regular text
        spans.add(
          TextSpan(
            text: match.group(3),
            style: TextStyle(color: textColor),
          ),
        );
      }
    }

    return SelectableText.rich(
      TextSpan(children: spans),
      style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
    );
  }

  Widget _buildLoadingIndicator(ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(_getTextColor(theme)),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Escribiendo...',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: _getTextColor(theme),
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorMessage(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.error_outline, color: theme.colorScheme.error, size: 16),
            const SizedBox(width: 8),
            Text(
              'Error al enviar mensaje',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (onRetry != null)
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Reintentar'),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
          ),
      ],
    );
  }

  Widget _buildArticulosRelacionados(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.article, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                'Artículos relacionados:',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: articulosRelacionados!.take(3).map((articulo) {
              return GestureDetector(
                onTap: () => onArticuloTap?.call(articulo),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: theme.colorScheme.primary.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    'Art. $articulo',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }


  Widget _buildSugerencias(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.secondary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                size: 16,
                color: theme.colorScheme.secondary,
              ),
              const SizedBox(width: 6),
              Text(
                'Sugerencias:',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.secondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: sugerencias!.take(3).map((sugerencia) {
              return GestureDetector(
                onTap: () => onSugerenciaTap?.call(sugerencia),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: theme.colorScheme.secondary.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    sugerencia,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.secondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTimestamp(ThemeData theme) {
    return Padding(
      padding: EdgeInsets.only(left: isUser ? 0 : 8, right: isUser ? 8 : 0),
      child: Text(
        _formatTimestamp(timestamp),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Color _getBubbleColor(ThemeData theme) {
    if (hasError) {
      return theme.colorScheme.errorContainer;
    }

    return isUser ? theme.primaryColor : theme.colorScheme.surfaceContainer;
  }

  Color _getTextColor(ThemeData theme) {
    if (hasError) {
      return theme.colorScheme.onErrorContainer;
    }

    return isUser ? Colors.white : theme.colorScheme.onSurface;
  }

  BorderRadius _getBorderRadius() {
    if (isUser) {
      return const BorderRadius.only(
        topLeft: Radius.circular(16),
        topRight: Radius.circular(4),
        bottomLeft: Radius.circular(16),
        bottomRight: Radius.circular(16),
      );
    } else {
      return const BorderRadius.only(
        topLeft: Radius.circular(4),
        topRight: Radius.circular(16),
        bottomLeft: Radius.circular(16),
        bottomRight: Radius.circular(16),
      );
    }
  }

  void _showMessageOptions(BuildContext context, ThemeData theme) {
    // Implementar opciones como copiar mensaje
    if (!isLoading && !hasError) {
      Clipboard.setData(ClipboardData(text: message));
      // Mostrar snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Mensaje copiado'),
          duration: const Duration(seconds: 2),
          backgroundColor: theme.primaryColor,
        ),
      );
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Ahora';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h';
    } else {
      return '${timestamp.day}/${timestamp.month}';
    }
  }
}

/// Indicador de typing/escribiendo
class TypingIndicator extends StatefulWidget {
  final String? userName;
  final EdgeInsetsGeometry? margin;

  const TypingIndicator({super.key, this.userName, this.margin});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _animations = List.generate(3, (index) {
      return Tween<double>(begin: 0.4, end: 1.0).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(
            index * 0.2,
            (index * 0.2) + 0.4,
            curve: Curves.easeInOut,
          ),
        ),
      );
    });

    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin:
          widget.margin ??
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: theme.colorScheme.secondary.withOpacity(0.1),
            backgroundImage: const AssetImage('assets/images/logo.png'),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainer,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return Row(
                      children: List.generate(3, (index) {
                        return Opacity(
                          opacity: _animations[index].value,
                          child: Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.onSurfaceVariant,
                              shape: BoxShape.circle,
                            ),
                          ),
                        );
                      }),
                    );
                  },
                ),
                const SizedBox(width: 8),
                Text(
                  widget.userName != null
                      ? '${widget.userName} está escribiendo...'
                      : 'Escribiendo...',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Input de chat con funcionalidades avanzadas
class ChatInput extends StatefulWidget {
  final TextEditingController? controller;
  final Function(String)? onSend;
  final Function(String)? onChanged;
  final VoidCallback? onMicTap;
  final bool isEnabled;
  final bool isLoading;
  final String? hint;
  final int maxLines;
  final List<String>? suggestions;
  final Function(String)? onSuggestionTap;

  const ChatInput({
    super.key,
    this.controller,
    this.onSend,
    this.onChanged,
    this.onMicTap,
    this.isEnabled = true,
    this.isLoading = false,
    this.hint,
    this.maxLines = 4,
    this.suggestions,
    this.onSuggestionTap,
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  late TextEditingController _controller;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = _controller.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() {
        _hasText = hasText;
      });
    }
    widget.onChanged?.call(_controller.text);
  }

  void _onSendPressed() {
    if (_hasText && !widget.isLoading) {
      final text = _controller.text.trim();
      widget.onSend?.call(text);
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        if (widget.suggestions != null && widget.suggestions!.isNotEmpty)
          _buildSuggestions(theme),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
              top: BorderSide(
                color: theme.colorScheme.outline.withOpacity(0.2),
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: TextField(
                    controller: _controller,
                    enabled: widget.isEnabled && !widget.isLoading,
                    maxLines: widget.maxLines,
                    minLines: 1,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      hintText: widget.hint ?? 'Escribe tu pregunta...',
                      hintStyle: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    style: theme.textTheme.bodyMedium,
                    onSubmitted: (_) {
                      if (_hasText) _onSendPressed();
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (widget.isLoading)
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainer,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else if (_hasText)
                GestureDetector(
                  onTap: _onSendPressed,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: theme.primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.send,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSuggestions(ThemeData theme) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: widget.suggestions!.length,
        itemBuilder: (context, index) {
          final suggestion = widget.suggestions![index];
          return Container(
            margin: const EdgeInsets.only(right: 8),
            child: ActionChip(
              label: Text(suggestion),
              onPressed: () => widget.onSuggestionTap?.call(suggestion),
              backgroundColor: theme.colorScheme.primaryContainer,
              labelStyle: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          );
        },
      ),
    );
  }
}
