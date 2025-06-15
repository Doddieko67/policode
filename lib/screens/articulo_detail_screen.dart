import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:policode/models/articulo_model.dart';
import 'package:policode/widgets/custom_button.dart';
import 'package:policode/widgets/custom_cards.dart';
import 'package:policode/widgets/loading_widgets.dart';
import '../services/auth_service.dart';
import '../services/reglamento_service.dart';
import '../services/notas_service.dart';

/// Pantalla de detalle completo de un artículo del reglamento
class ArticuloDetailScreen extends StatefulWidget {
  const ArticuloDetailScreen({super.key});

  @override
  State<ArticuloDetailScreen> createState() => _ArticuloDetailScreenState();
}

class _ArticuloDetailScreenState extends State<ArticuloDetailScreen> {
  final ReglamentoService _reglamentoService = ReglamentoService();
  final AuthService _authService = AuthService();
  final NotasService _notasService = NotasService();
  final ScrollController _scrollController = ScrollController();

  // Estado
  Articulo? _articulo;
  List<Articulo> _articulosRelacionados = [];
  bool _isLoading = true;
  bool _isGuardado = false;
  bool _isLoadingGuardar = false;
  String? _errorMessage;
  String? _articuloId;

  // UI
  bool _showFloatingButton = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScrollChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _obtenerArgumentos();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _obtenerArgumentos() {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    _articuloId = args?['articuloId'] ?? args?['id'];

    if (_articuloId != null) {
      _cargarArticulo();
    } else {
      setState(() {
        _errorMessage = 'No se proporcionó ID del artículo';
        _isLoading = false;
      });
    }
  }

  void _onScrollChanged() {
    final showButton = _scrollController.offset > 200;
    if (showButton != _showFloatingButton) {
      setState(() {
        _showFloatingButton = showButton;
      });
    }
  }

  Future<void> _cargarArticulo() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Cargar artículo principal
      final articulo = await _reglamentoService.obtenerArticuloPorId(
        _articuloId!,
      );

      if (articulo == null) {
        setState(() {
          _errorMessage = 'Artículo no encontrado';
          _isLoading = false;
        });
        return;
      }

      // Cargar artículos relacionados
      final relacionados = await _reglamentoService
          .obtenerArticulosRelacionados(_articuloId!, limite: 5);

      // Verificar si está guardado (solo si hay usuario autenticado)
      bool isGuardado = false;
      if (_authService.isSignedIn) {
        isGuardado = await _notasService.estaGuardado(
          _authService.currentUser!.uid,
          _articuloId!,
        );
      }

      setState(() {
        _articulo = articulo;
        _articulosRelacionados = relacionados;
        _isGuardado = isGuardado;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error cargando artículo: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: _buildAppBar(theme),
      body: _isLoading
          ? const Center(child: LoadingWidget())
          : _errorMessage != null
          ? _buildErrorState()
          : _buildContent(),
      floatingActionButton: _showFloatingButton
          ? _buildFloatingActionButton(theme)
          : null,
      bottomNavigationBar: _articulo != null ? _buildBottomBar(theme) : null,
    );
  }

  PreferredSizeWidget _buildAppBar(ThemeData theme) {
    return AppBar(
      elevation: 1,
      backgroundColor: theme.colorScheme.primary,
      foregroundColor: theme.colorScheme.onPrimary,
      title: Text(
        _articulo?.numero ?? 'Artículo',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onPrimary,
        ),
      ),
      actions: [
        if (_articulo != null) ...[
          IconButton(
            onPressed: _compartirArticulo,
            icon: const Icon(Icons.share),
            tooltip: 'Compartir',
          ),
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'copy',
                child: Row(
                  children: [
                    const Icon(Icons.copy, size: 20),
                    const SizedBox(width: 12),
                    const Text('Copiar texto'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'search_related',
                child: Row(
                  children: [
                    const Icon(Icons.search, size: 20),
                    const SizedBox(width: 12),
                    const Text('Buscar similares'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'report',
                child: Row(
                  children: [
                    const Icon(Icons.flag, size: 20),
                    const SizedBox(width: 12),
                    const Text('Reportar error'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: CustomErrorWidget.generic(
        title: 'Error cargando artículo',
        message: _errorMessage,
        onRetry: _cargarArticulo,
      ),
    );
  }

  Widget _buildContent() {
    return RefreshIndicator(
      onRefresh: _cargarArticulo,
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.only(bottom: 100), // Espacio para bottom bar
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildArticuloHeader(),
            _buildArticuloContent(),
            if (_articulo!.palabrasClave.isNotEmpty) _buildPalabrasClave(),
            // Categoría ocultada según retroalimentación
            // if (_articulo!.categoria != null) _buildCategoria(),
            _buildMetadatos(),
            if (_articulosRelacionados.isNotEmpty)
              _buildArticulosRelacionados(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildArticuloHeader() {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.primaryColor, theme.primaryColor.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.primaryColor.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Número del artículo
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _articulo!.numero,
              style: theme.textTheme.labelLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Título
          Text(
            _articulo!.titulo,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              height: 1.3,
            ),
          ),

          const SizedBox(height: 12),

          // Información adicional - Categoría ocultada según retroalimentación
          // if (_articulo!.categoria != null) ...[
          //   Icon(
          //     Icons.category,
          //     color: Colors.white.withOpacity(0.8),
          //     size: 16,
          //   ),
          //   const SizedBox(height: 4),
          //   Text(
          //     _articulo!.categoria!,
          //     style: theme.textTheme.bodySmall?.copyWith(
          //       color: Colors.white.withOpacity(0.9),
          //     ),
          //   ),
          //   const SizedBox(height: 16),
          // ],
        ],
      ),
    );
  }

  Widget _buildArticuloContent() {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.article, 
                color: theme.brightness == Brightness.dark 
                  ? theme.colorScheme.primary.withOpacity(0.9)
                  : theme.primaryColor, 
                size: 20),
              const SizedBox(width: 8),
              Text(
                'Contenido del Artículo',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.brightness == Brightness.dark 
                    ? theme.colorScheme.primary.withOpacity(0.9)
                    : theme.primaryColor,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          SelectableText(
            _articulo!.contenido,
            style: theme.textTheme.bodyLarge?.copyWith(
              height: 1.6,
              fontSize: 16,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPalabrasClave() {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.label, color: theme.colorScheme.secondary, size: 18),
              const SizedBox(width: 8),
              Text(
                'Palabras Clave',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.secondary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _articulo!.palabrasClave.map((palabra) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  palabra,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoria() {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Icon(Icons.folder, color: theme.colorScheme.tertiary, size: 18),
          const SizedBox(width: 8),
          Text(
            'Categoría: ',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _articulo!.categoria!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onTertiaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadatos() {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Información Adicional',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),

          const SizedBox(height: 12),

          if (_articulo!.fechaActualizacion != null) ...[
            Row(
              children: [
                Icon(
                  Icons.update,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  'Última actualización: ${_formatearFecha(_articulo!.fechaActualizacion!)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetadatoItem(
    IconData icon,
    String label,
    String value,
    ThemeData theme,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          '$value $label',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildArticulosRelacionados() {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.link, color: theme.primaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'Artículos Relacionados',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          SizedBox(
            height: 280,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _articulosRelacionados.length,
              itemBuilder: (context, index) {
                final articulo = _articulosRelacionados[index];
                return Container(
                  width: 300,
                  margin: const EdgeInsets.only(right: 12),
                  child: ArticuloCard(
                    numero: articulo.numero,
                    titulo: articulo.titulo,
                    contenido: articulo.contenido,
                    categoria: null, // Ocultar categoría según retroalimentación
                    palabrasClave: articulo.palabrasClave,
                    onTap: () => _navegarAArticulo(articulo.id),
                    showActions: false,
                    margin: EdgeInsets.zero,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outline.withOpacity(0.2)),
        ),
      ),
      child: Row(
        children: [
          // Botón de Chat
          // Botón de Guardar/Quitar
          Expanded(
            child: CustomButton(
              text: _isGuardado ? 'Guardado' : 'Guardar',
              icon: _isGuardado ? Icons.bookmark : Icons.bookmark_border,
              onPressed: _isLoadingGuardar ? null : _toggleGuardarArticulo,
              isLoading: _isLoadingGuardar,
              type: _isGuardado ? ButtonType.success : ButtonType.primary,
              size: ButtonSize.large,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButton(ThemeData theme) {
    return CustomFloatingButton(
      icon: Icons.keyboard_arrow_up,
      onPressed: _scrollToTop,
      tooltip: 'Ir al inicio',
      backgroundColor: theme.primaryColor.withOpacity(0.9),
    );
  }

  // Métodos de utilidad
  String _formatearFecha(DateTime fecha) {
    return '${fecha.day}/${fecha.month}/${fecha.year}';
  }

  // Métodos de acción
  void _navegarAArticulo(String articuloId) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const ArticuloDetailScreen(),
        settings: RouteSettings(arguments: {'articuloId': articuloId}),
      ),
    );
  }

  void _compartirArticulo() {
    final texto =
        '''
${_articulo!.numero}: ${_articulo!.titulo}

${_articulo!.contenido}

Compartido desde PoliCode - Asistente del Reglamento
''';

    // En una app real, usarías el plugin share_plus
    Clipboard.setData(ClipboardData(text: texto));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Artículo copiado al portapapeles'),
        backgroundColor: Theme.of(context).primaryColor,
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
        ),
      ),
    );
  }

  void _preguntarSobreArticulo() {
    Navigator.pushNamed(
      context,
      '/chat',
      arguments: {
        'preguntaInicial':
            'Tengo una pregunta sobre el ${_articulo!.numero}: ${_articulo!.titulo}',
      },
    );
  }

  Future<void> _toggleGuardarArticulo() async {
    if (!_authService.isSignedIn) {
      _mostrarDialogoLogin();
      return;
    }

    setState(() {
      _isLoadingGuardar = true;
    });

    try {
      final userId = _authService.currentUser!.uid;

      if (_isGuardado) {
        // Quitar de guardados
        final nota = await _notasService.getNotaPorArticulo(
          userId,
          _articuloId!,
        );
        if (nota.success && nota.nota != null) {
          await _notasService.eliminarNota(userId, nota.nota!.id);
        }
      } else {
        // Guardar artículo
        await _notasService.guardarArticulo(userId, _articuloId!);
      }

      setState(() {
        _isGuardado = !_isGuardado;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isGuardado ? 'Artículo guardado' : 'Artículo removido',
          ),
          backgroundColor: Theme.of(context).primaryColor,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        _isLoadingGuardar = false;
      });
    }
  }

  void _mostrarDialogoLogin() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Iniciar Sesión'),
        content: const Text(
          'Para guardar artículos necesitas tener una cuenta. ¿Quieres iniciar sesión?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          CustomButton.primary(
            text: 'Iniciar Sesión',
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/auth');
            },
            size: ButtonSize.small,
          ),
        ],
      ),
    );
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'copy':
        Clipboard.setData(ClipboardData(text: _articulo!.contenido));
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Contenido copiado')));
        break;
      case 'search_related':
        Navigator.pushNamed(
          context,
          '/search',
          arguments: {'query': _articulo!.titulo},
        );
        break;
      case 'report':
        _mostrarDialogoReporte();
        break;
    }
  }

  void _mostrarDialogoReporte() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reportar Error'),
        content: const Text(
          '¿Has encontrado un error en este artículo? Nos ayudas a mejorarlo reportándolo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          CustomButton.primary(
            text: 'Reportar',
            onPressed: () {
              Navigator.pop(context);
              // Implementar reporte
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Reporte enviado. ¡Gracias!')),
              );
            },
            size: ButtonSize.small,
          ),
        ],
      ),
    );
  }
}
