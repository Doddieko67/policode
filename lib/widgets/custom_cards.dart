import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:policode/models/nota_model.dart';

/// Card para mostrar artículos del reglamento
class ArticuloCard extends StatelessWidget {
  final String numero;
  final String titulo;
  final String contenido;
  final String? categoria;
  final List<String> palabrasClave;
  final bool isGuardado;
  final VoidCallback? onTap;
  final VoidCallback? onGuardar;
  final VoidCallback? onCompartir;
  final double? relevancia; // Para búsquedas
  final bool showActions;
  final EdgeInsetsGeometry? margin;

  const ArticuloCard({
    super.key,
    required this.numero,
    required this.titulo,
    required this.contenido,
    this.categoria,
    this.palabrasClave = const [],
    this.isGuardado = false,
    this.onTap,
    this.onGuardar,
    this.onCompartir,
    this.relevancia,
    this.showActions = true,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSimpleHeader(theme),
                const SizedBox(height: 12),
                _buildContent(theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSimpleHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        numero,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.bold,
        ),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Row(
      children: [
        // Número del artículo
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            numero,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 12),

        // Categoría
        if (categoria != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              categoria!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.secondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],

        const Spacer(),

        // Indicador de relevancia
        if (relevancia != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _getRelevanciaColor(relevancia!).withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.star,
                  size: 12,
                  color: _getRelevanciaColor(relevancia!),
                ),
                const SizedBox(width: 2),
                Text(
                  '${(relevancia! * 100).toInt()}%',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: _getRelevanciaColor(relevancia!),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],

        // Indicador de guardado
        if (isGuardado)
          Icon(Icons.bookmark, color: theme.primaryColor, size: 20),
      ],
    );
  }

  Widget _buildContent(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        Text(
          contenido,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildPalabrasClave(ThemeData theme) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: palabrasClave.take(5).map((palabra) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            palabra,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActions(ThemeData theme) {
    return Row(
      children: [
        if (onTap != null)
          TextButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.visibility, size: 16),
            label: const Text('Ver completo'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),

        const Spacer(),

        if (onCompartir != null)
          IconButton(
            onPressed: onCompartir,
            icon: const Icon(Icons.share, size: 20),
            tooltip: 'Compartir',
            visualDensity: VisualDensity.compact,
          ),

        if (onGuardar != null)
          IconButton(
            onPressed: onGuardar,
            icon: Icon(
              isGuardado ? Icons.bookmark : Icons.bookmark_border,
              size: 20,
              color: isGuardado ? theme.primaryColor : null,
            ),
            tooltip: isGuardado ? 'Quitar de guardados' : 'Guardar',
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
  }

  Color _getRelevanciaColor(double relevancia) {
    if (relevancia >= 0.8) return Colors.green;
    if (relevancia >= 0.6) return Colors.orange;
    return Colors.grey;
  }

  String _truncateContent(String content, int maxLength) {
    if (content.length <= maxLength) return content;
    return '${content.substring(0, maxLength)}...';
  }
}

/// Card para mostrar notas guardadas
/// Card para mostrar notas guardadas - Versión mejorada
class NotaCard extends StatelessWidget {
  final Nota nota;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onToggleFavorita;
  final VoidCallback? onToggleArchivada;
  final bool showActions;

  const NotaCard({
    super.key,
    required this.nota,
    this.onTap,
    this.onLongPress,
    this.onEdit,
    this.onDelete,
    this.onToggleFavorita,
    this.onToggleArchivada,
    this.showActions = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: nota.esArchivada
                ? Colors.grey.withOpacity(0.1)
                : theme.colorScheme.primary.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: nota.esArchivada
            ? theme.colorScheme.surfaceVariant.withOpacity(0.5)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(20),
          splashColor: theme.colorScheme.primary.withOpacity(0.1),
          highlightColor: theme.colorScheme.primary.withOpacity(0.05),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, theme),
                const SizedBox(height: 16),
                _buildContent(theme),
                if (nota.comentarioUsuario?.isNotEmpty ?? false) ...[
                  const SizedBox(height: 16),
                  _buildComentario(theme),
                ],
                if (nota.etiquetas.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildEtiquetas(theme),
                ],
                const SizedBox(height: 16),
                _buildFooter(theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Badge del artículo más moderno
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: nota.esArchivada
                ? LinearGradient(
                    colors: [
                      theme.colorScheme.onSurfaceVariant.withOpacity(0.1),
                      theme.colorScheme.onSurfaceVariant.withOpacity(0.05),
                    ],
                  )
                : LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.primary.withOpacity(0.8),
                    ],
                  ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: nota.esArchivada
                ? null
                : [
                    BoxShadow(
                      color: theme.colorScheme.primary.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.article_outlined,
                size: 16,
                color: nota.esArchivada
                    ? theme.colorScheme.onSurfaceVariant
                    : theme.colorScheme.onPrimary,
              ),
              const SizedBox(width: 6),
              Text(
                'Art. ${nota.articuloId}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: nota.esArchivada
                      ? theme.colorScheme.onSurfaceVariant
                      : theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 12),

        // Indicadores de estado más elegantes
        Row(
          children: [
            if (nota.esFavorita)
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.amber.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.star_rounded,
                  color: Colors.amber[700],
                  size: 16,
                ),
              ),
            if (nota.esFavorita && nota.esArchivada) const SizedBox(width: 8),
            if (nota.esArchivada)
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.archive_outlined,
                  color: theme.colorScheme.onSurfaceVariant,
                  size: 16,
                ),
              ),
          ],
        ),

        const Spacer(),

        // Menú de acciones más sutil
        if (showActions)
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: _buildActionsMenu(theme),
          ),
      ],
    );
  }

  Widget _buildContent(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Título con mejor jerarquía visual
        Text(
          'Artículo ${nota.articuloId}: Reglamento sobre...', // Placeholder
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: nota.esArchivada
                ? theme.colorScheme.onSurfaceVariant
                : theme.colorScheme.onSurface,
            height: 1.3,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        // Subtítulo descriptivo
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.primary.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Text(
            'Reglamento de Policía y Buen Gobierno',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildComentario(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.format_quote_rounded,
                size: 18,
                color: theme.colorScheme.primary.withOpacity(0.7),
              ),
              const SizedBox(width: 8),
              Text(
                'Mi comentario',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            nota.comentarioUsuario!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w600, // Más peso para mejor visibilidad
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildEtiquetas(ThemeData theme) {
    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      children: nota.etiquetas.map((tag) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.secondary.withOpacity(0.1),
                theme.colorScheme.secondary.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.colorScheme.secondary.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.tag, size: 12, color: theme.colorScheme.secondary),
              const SizedBox(width: 4),
              Text(
                tag,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.secondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFooter(ThemeData theme) {
    final fechaMostrar = nota.fechaModificacion ?? nota.fechaGuardado;
    final esModificada = nota.fechaModificacion != null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: esModificada
                  ? theme.colorScheme.tertiary.withOpacity(0.2)
                  : theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              esModificada
                  ? Icons.edit_calendar_rounded
                  : Icons.calendar_today_rounded,
              size: 14,
              color: esModificada
                  ? theme.colorScheme.tertiary
                  : theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${esModificada ? "Editada" : "Guardada"} ${_formatearFecha(fechaMostrar)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          // Indicador visual adicional
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: esModificada
                  ? theme.colorScheme.tertiary
                  : theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsMenu(ThemeData theme) {
    return PopupMenuButton<String>(
      onSelected: (value) {
        if (value == 'edit' && onEdit != null) onEdit!();
        if (value == 'favorite' && onToggleFavorita != null)
          onToggleFavorita!();
        if (value == 'archive' && onToggleArchivada != null)
          onToggleArchivada!();
        if (value == 'delete' && onDelete != null) onDelete!();
      },
      icon: Icon(
        Icons.more_vert_rounded,
        color: theme.colorScheme.onSurfaceVariant,
        size: 20,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 8,
      color: theme.colorScheme.surface,
      shadowColor: theme.colorScheme.shadow.withOpacity(0.1),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'edit',
          child: _buildMenuItem(
            Icons.edit_outlined,
            'Editar',
            theme.colorScheme.primary,
            theme,
          ),
        ),
        PopupMenuItem(
          value: 'favorite',
          child: _buildMenuItem(
            nota.esFavorita ? Icons.star_border_rounded : Icons.star_rounded,
            nota.esFavorita ? 'Quitar favorita' : 'Marcar favorita',
            Colors.amber[700]!,
            theme,
          ),
        ),
        PopupMenuItem(
          value: 'archive',
          child: _buildMenuItem(
            nota.esArchivada
                ? Icons.unarchive_outlined
                : Icons.archive_outlined,
            nota.esArchivada ? 'Desarchivar' : 'Archivar',
            theme.colorScheme.onSurfaceVariant,
            theme,
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'delete',
          child: _buildMenuItem(
            Icons.delete_outline_rounded,
            'Eliminar',
            theme.colorScheme.error,
            theme,
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem(
    IconData icon,
    String text,
    Color color,
    ThemeData theme,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatearFecha(DateTime fecha) {
    final now = DateTime.now();
    final difference = now.difference(fecha);

    if (difference.inSeconds < 60) return 'hace un momento';
    if (difference.inMinutes < 60) return 'hace ${difference.inMinutes} min';
    if (difference.inHours < 24) return 'hace ${difference.inHours} h';
    if (difference.inDays == 1) return 'ayer';
    if (difference.inDays < 7) return 'hace ${difference.inDays} días';

    return DateFormat('dd MMM, yyyy').format(fecha);
  }
}

/// Card simple para información general
class InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? value;
  final Color? iconColor;
  final Color? backgroundColor;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;

  const InfoCard({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.value,
    this.iconColor,
    this.backgroundColor,
    this.onTap,
    this.margin,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: margin ?? const EdgeInsets.all(8),
      child: Card(
        elevation: 1,
        color: backgroundColor ?? theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (iconColor ?? theme.primaryColor).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: iconColor ?? theme.primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (value != null) ...[
                  Text(
                    value!,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: iconColor ?? theme.primaryColor,
                    ),
                  ),
                ],
                if (onTap != null) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
