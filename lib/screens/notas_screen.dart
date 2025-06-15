import 'package:flutter/material.dart';
import 'package:policode/models/nota_model.dart'; // Asegúrate de que la ruta sea correcta
import 'package:policode/widgets/custom_button.dart';
import 'package:policode/widgets/custom_cards.dart';
import 'package:policode/widgets/custom_input.dart';
import 'package:policode/widgets/loading_widgets.dart';
import '../services/auth_service.dart';
import '../services/notas_service.dart';
// Quitado reglamento_service porque no se usa directamente en esta pantalla
// import '../services/reglamento_service.dart';

// Los enums ya están definidos en tu nota_model.dart, puedes borrarlos de aquí si quieres
// o asegurarte de que coincidan. Es mejor tenerlos en un solo lugar.

/// Pantalla para gestionar notas guardadas
class NotasScreen extends StatefulWidget {
  const NotasScreen({super.key});

  @override
  State<NotasScreen> createState() => _NotasScreenState();
}

class _NotasScreenState extends State<NotasScreen>
    with TickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final NotasService _notasService = NotasService();

  // Controllers
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late TabController _tabController;

  // Estado de UI y Filtros
  List<String> _etiquetasDisponibles = [];
  Map<String, int> _estadisticas = {};

  FiltroCategoriaNotas _filtroActual = FiltroCategoriaNotas.todas;
  TipoOrdenNota _ordenActual = TipoOrdenNota.fechaGuardado;
  bool _ordenAscendente = false;
  String _busquedaTexto = '';
  String? _etiquetaSeleccionada;

  bool _isSelectionMode = false;
  final Set<String> _notasSeleccionadas =
      {}; // Usamos el ID de la nota (String)

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);

    // Si el usuario no está logueado, redirigir.
    // El StreamBuilder manejará el caso de que el UID sea nulo.
    if (!_authService.isSignedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, '/auth');
      });
    } else {
      // Cargar metadatos como etiquetas y estadísticas que no vienen del stream principal
      _cargarMetadatos();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) return;

    final filtros = [
      FiltroCategoriaNotas.todas,
      FiltroCategoriaNotas.favoritas,
      FiltroCategoriaNotas.archivadas,
      FiltroCategoriaNotas.recientes,
    ];

    setState(() {
      _filtroActual = filtros[_tabController.index];
      _etiquetaSeleccionada = null;
      // No es necesario llamar a _aplicarFiltros aquí, el build lo hará.
    });
  }

  // Carga datos que no son parte del stream de notas (etiquetas, estadísticas)
  Future<void> _cargarMetadatos() async {
    if (!_authService.isSignedIn) return;
    final userId = _authService.currentUser!.uid;

    try {
      final etiquetas = await _notasService.getEtiquetasDelUsuario(userId);
      final estadisticas = await _notasService.getEstadisticas(userId);
      if (mounted) {
        setState(() {
          _etiquetasDisponibles = etiquetas;
          _estadisticas = estadisticas;
        });
      }
    } catch (e) {
      // Manejar error si es necesario, ej. con un SnackBar
      print("Error cargando metadatos: $e");
    }
  }

  List<Nota> _aplicarFiltrosYOrden(List<Nota> todasLasNotas) {
    var notasFiltradas = todasLasNotas;

    // Filtrar por categoría (Usando las extensiones del modelo)
    switch (_filtroActual) {
      case FiltroCategoriaNotas.favoritas:
        notasFiltradas = notasFiltradas.favoritas;
        break;
      case FiltroCategoriaNotas.archivadas:
        notasFiltradas = notasFiltradas.archivadas;
        break;
      case FiltroCategoriaNotas.recientes:
        // El modelo define recientes como último mes, ajustamos si es necesario
        // O creamos una nueva extension para "últimos 7 días"
        final hace7Dias = DateTime.now().subtract(const Duration(days: 7));
        notasFiltradas = notasFiltradas
            .where((n) => n.fechaGuardado.isAfter(hace7Dias))
            .toList();
        break;
      case FiltroCategoriaNotas.conComentarios:
        notasFiltradas = notasFiltradas
            .where((n) => n.comentarioUsuario?.isNotEmpty ?? false)
            .toList();
        break;
      case FiltroCategoriaNotas.conEtiquetas:
        notasFiltradas = notasFiltradas
            .where((n) => n.etiquetas.isNotEmpty)
            .toList();
        break;
      case FiltroCategoriaNotas.todas:
        // Por defecto mostramos las no archivadas
        notasFiltradas = notasFiltradas.activas;
        break;
    }

    // Filtrar por etiqueta específica
    if (_etiquetaSeleccionada != null) {
      notasFiltradas = notasFiltradas.conEtiqueta(_etiquetaSeleccionada!);
    }

    // Filtrar por búsqueda de texto
    if (_busquedaTexto.isNotEmpty) {
      // Usamos el textoCompleto del modelo para la búsqueda
      notasFiltradas = notasFiltradas.where((n) {
        final busqueda = _busquedaTexto.toLowerCase();
        final tituloArticulo = n.articuloId
            .toLowerCase(); // Suponemos que tienes acceso al título
        final contenidoNota = n.textoCompleto;
        return tituloArticulo.contains(busqueda) ||
            contenidoNota.contains(busqueda);
      }).toList();
    }

    // Ordenar (Usando la extensión del modelo)
    // Nota: El enum de orden en tu modelo es diferente, lo adaptamos.
    TipoOrdenNota? tipoOrden;
    switch (_ordenActual) {
      case TipoOrdenNota.fechaGuardado:
        tipoOrden = TipoOrdenNota.fechaGuardado;
        break;
      case TipoOrdenNota.fechaModificacion:
        tipoOrden = TipoOrdenNota.fechaModificacion;
        break;
      case TipoOrdenNota.alfabetico:
        // No está en el enum del modelo, lo implementamos manualmente
        notasFiltradas.sort((a, b) => a.articuloId.compareTo(b.articuloId));
        return _ordenAscendente
            ? notasFiltradas
            : notasFiltradas.reversed.toList();
      case TipoOrdenNota.prioridad:
        // Implementación de relevancia (favoritas primero)
        notasFiltradas.sort((a, b) {
          if (a.esFavorita != b.esFavorita) {
            return a.esFavorita ? -1 : 1;
          }
          return b.fechaGuardado.compareTo(
            a.fechaGuardado,
          ); // Más recientes primero
        });
        return _ordenAscendente
            ? notasFiltradas.reversed.toList()
            : notasFiltradas;
    }

    return notasFiltradas.ordenarPor(tipoOrden, ascendente: _ordenAscendente);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userId = _authService.currentUser?.uid;

    return Scaffold(
      // MEJORA: El fondo de la pantalla ahora usa el color de fondo del tema
      // para que las tarjetas blancas resalten más.
      backgroundColor: theme.colorScheme.background,
      appBar: _buildAppBar(theme),
      body: userId == null
          ? _buildErrorState(
              'Usuario no autenticado.',
            ) // Mostrar error si no hay usuario
          : StreamBuilder<List<Nota>>(
              stream: _notasService.getNotasStream(userId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: LoadingWidget());
                }
                if (snapshot.hasError) {
                  return _buildErrorState(
                    'Error cargando notas: ${snapshot.error}',
                  );
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return EmptyStateWidget.noNotes(
                    onCreateNote: () => Navigator.pushNamed(context, '/chat'),
                  );
                }

                final todasLasNotas = snapshot.data!;
                final notasFiltradas = _aplicarFiltrosYOrden(todasLasNotas);

                return _buildContent(notasFiltradas);
              },
            ),
      floatingActionButton: _buildFAB(theme),
    );
  }

  PreferredSizeWidget _buildAppBar(ThemeData theme) {
    // CAMBIO: Se usa colorScheme.surface para el fondo del AppBar, que es blanco.
    // El texto del título y los iconos heredarán su color del `appBarTheme`
    // que debería ser `onSurface` (negro) si el fondo es blanco.
    // Si tu AppBar sigue teniendo texto blanco, asegúrate que en tu main.dart
    // el AppBarTheme no fuerce un color de texto blanco sobre un fondo blanco.
    // La forma correcta es definirlo en el tema general.
    return AppBar(
      title: _isSelectionMode
          ? Text('${_notasSeleccionadas.length} seleccionadas')
          : const Text('Mis Notas'),
      leading: _isSelectionMode
          ? IconButton(
              onPressed: _cancelarSeleccion,
              icon: const Icon(Icons.close),
            )
          : null,
      actions: _isSelectionMode
          ? _buildSelectionActions(theme)
          : _buildNormalActions(theme),
      bottom: _isSelectionMode
          ? null
          : TabBar(
              controller: _tabController,
              labelColor: theme.colorScheme.onSurface,
              unselectedLabelColor: theme.colorScheme.onSurface.withOpacity(0.6),
              tabs: const [
                Tab(text: 'Todas'),
                Tab(text: 'Favoritas'),
                Tab(text: 'Archivadas'),
                Tab(text: 'Recientes'),
              ],
            ),
    );
  }

  List<Widget> _buildNormalActions(ThemeData theme) {
    return [];
  }

  List<Widget> _buildSelectionActions(ThemeData theme) {
    // ... (Sin cambios)
    return [
      IconButton(
        onPressed: _notasSeleccionadas.isEmpty ? null : _marcarFavoritas,
        icon: const Icon(Icons.star),
        tooltip: 'Marcar favoritas',
      ),
      IconButton(
        onPressed: _notasSeleccionadas.isEmpty ? null : _archivarSeleccionadas,
        icon: const Icon(Icons.archive),
        tooltip: 'Archivar',
      ),
      IconButton(
        onPressed: _notasSeleccionadas.isEmpty ? null : _eliminarSeleccionadas,
        icon: Icon(Icons.delete, color: theme.colorScheme.error),
        tooltip: 'Eliminar',
      ),
    ];
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: CustomErrorWidget.generic(
        title: 'Error',
        message: message,
        onRetry: _cargarMetadatos, // reintentar carga de metadatos
      ),
    );
  }

  Widget _buildContent(List<Nota> notasFiltradas) {
    return Column(
      children: [
        _buildSearchBar(),
        if (_etiquetaSeleccionada != null) _buildEtiquetaFilter(),
        _buildEstadisticas(notasFiltradas.length),
        Expanded(
          child: notasFiltradas.isEmpty
              ? _buildEmptyState()
              : _buildNotasList(notasFiltradas),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    // MEJORA: Añadimos un fondo al buscador para que se separe visualmente
    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: SearchInput(
        controller: _searchController,
        hint: 'Buscar en tus notas...',
        onChanged: (value) {
          setState(() {
            _busquedaTexto = value;
          });
        },
        suggestions: _etiquetasDisponibles,
        onSuggestionTap: (etiqueta) {
          setState(() {
            _etiquetaSeleccionada = etiqueta;
          });
        },
      ),
    );
  }

  Widget _buildEtiquetaFilter() {
    // ... (Sin cambios)
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Chip(
            label: Text(_etiquetaSeleccionada!),
            deleteIcon: const Icon(Icons.close, size: 18),
            onDeleted: () {
              setState(() {
                _etiquetaSeleccionada = null;
              });
            },
            backgroundColor: theme.primaryColor.withOpacity(0.1),
            labelStyle: TextStyle(color: theme.primaryColor),
          ),
        ],
      ),
    );
  }

  Widget _buildEstadisticas(int notasMostradas) {
    if (_estadisticas.isEmpty) return const SizedBox();
    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: [
          Text(
            '$notasMostradas nota${notasMostradas != 1 ? 's' : ''}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          if (_estadisticas['total'] != null)
            Text(
              'Total: ${_estadisticas['total']}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    // ... (Sin cambios significativos, puedes adaptarlo a tus widgets)
    return const Center(
      child: Text("No hay notas que coincidan con tu filtro."),
    );
  }

  // =======================================================================
  // ====================== MEJORA PRINCIPAL AQUÍ ==========================
  // =======================================================================
  Widget _buildNotasList(List<Nota> notasFiltradas) {
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: _cargarMetadatos,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.only(top: 8, bottom: 80),
        itemCount: notasFiltradas.length,
        itemBuilder: (context, index) {
          final nota = notasFiltradas[index];
          final isSelected = _notasSeleccionadas.contains(nota.id);

          final cardColor = isSelected
              ? theme.colorScheme.tertiary.withOpacity(0.5)
              : theme.cardTheme.color;
          final cardBorder = isSelected
              ? BorderSide(color: theme.colorScheme.primary, width: 2)
              : BorderSide(color: theme.dividerColor, width: 1);

          // Ahora el código es mucho más simple.
          return Card(
            elevation: isSelected ? 4 : 1,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: cardBorder,
            ),
            clipBehavior: Clip
                .antiAlias, // Importante para que el InkWell respete el borde
            child: NotaCard(
              nota: nota,
              onTap: _isSelectionMode
                  ? () => _toggleSelection(nota.id)
                  : () => _verDetalleNota(nota),
              onLongPress: () => _toggleSelection(nota.id),
              onEdit: () => _editarNota(nota),
              onDelete: () => _eliminarNota(nota.id),
              onToggleFavorita: () => _toggleFavorita(nota.id),
              onToggleArchivada: () => _toggleArchivada(nota.id),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFAB(ThemeData theme) {
    // ... (Sin cambios)
    return CustomFloatingButton(
      icon: Icons.chat,
      onPressed: () => Navigator.pushNamed(context, '/chat'),
      tooltip: 'Nuevo Chat',
      backgroundColor: theme.primaryColor,
    );
  }

  // --- MÉTODOS DE ACCIÓN (AHORA USAN EL SERVICIO) ---

  void _verDetalleNota(Nota nota) {
    Navigator.pushNamed(
      context,
      '/articulo',
      arguments: {'articuloId': nota.articuloId},
    );
  }

  void _editarNota(Nota nota) {
    // ... (El dialog puede funcionar igual, pero al guardar llama al servicio)
    showDialog(
      context: context,
      builder: (context) => _EditNotaDialog(
        nota: nota, // Pasamos el objeto Nota
        etiquetasDisponibles: _etiquetasDisponibles,
        onSave: (comentario, etiquetas) async {
          final userId = _authService.currentUser!.uid;
          final notaActualizada = nota.copyWith(
            comentarioUsuario: comentario,
            etiquetas: etiquetas,
          );
          await _notasService.actualizarNota(userId, notaActualizada);
          // No es necesario recargar, el stream lo hará
        },
      ),
    );
  }

  void _eliminarNota(String notaId) {
    // ... (La lógica del dialog es la misma, la acción cambia)
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Nota'),
        content: const Text('¿Estás seguro de que quieres eliminar esta nota?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          CustomButton.danger(
            text: 'Eliminar',
            onPressed: () async {
              Navigator.pop(context);
              final userId = _authService.currentUser!.uid;
              await _notasService.eliminarNota(userId, notaId);
              // No es necesario recargar, el stream lo hará
            },
            size: ButtonSize.small,
          ),
        ],
      ),
    );
  }

  Future<void> _toggleFavorita(String notaId) async {
    final userId = _authService.currentUser!.uid;
    await _notasService.alternarFavorita(userId, notaId);
  }

  Future<void> _toggleArchivada(String notaId) async {
    final userId = _authService.currentUser!.uid;
    await _notasService.alternarArchivada(userId, notaId);
  }

  void _toggleSelection(String notaId) {
    setState(() {
      if (_notasSeleccionadas.contains(notaId)) {
        _notasSeleccionadas.remove(notaId);
        if (_notasSeleccionadas.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _notasSeleccionadas.add(notaId);
        _isSelectionMode = true;
      }
    });
  }

  void _cancelarSeleccion() {
    setState(() {
      _isSelectionMode = false;
      _notasSeleccionadas.clear();
    });
  }

  Future<void> _marcarFavoritas() async {
    final userId = _authService.currentUser!.uid;
    // Podrías usar un Future.wait para eficiencia
    for (final notaId in _notasSeleccionadas) {
      await _notasService.alternarFavorita(
        userId,
        notaId,
      ); // Asume que la nota no es favorita
    }
    _cancelarSeleccion();
  }

  Future<void> _archivarSeleccionadas() async {
    final userId = _authService.currentUser!.uid;
    for (final notaId in _notasSeleccionadas) {
      await _notasService.alternarArchivada(
        userId,
        notaId,
      ); // Asume que la nota no está archivada
    }
    _cancelarSeleccion();
  }

  void _eliminarSeleccionadas() {
    // ... (Similar a eliminar una nota, pero en un bucle)
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Eliminar ${_notasSeleccionadas.length} notas'),
        content: const Text('¿Estás seguro? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          CustomButton.danger(
            text: 'Eliminar',
            onPressed: () async {
              Navigator.pop(context);
              final userId = _authService.currentUser!.uid;
              // Aquí un batch write de Firestore sería ideal, pero por ahora en bucle funciona
              for (final notaId in _notasSeleccionadas) {
                await _notasService.eliminarNota(userId, notaId);
              }
              _cancelarSeleccion();
            },
            size: ButtonSize.small,
          ),
        ],
      ),
    );
  }

  void _mostrarFiltros() {
    /* ... */
  }
  void _mostrarOrdenamiento() {
    /* ... */
  }
  void _handleMenuAction(String action) {
    /* ... */
  }
}

/// Dialog para editar nota (ahora recibe un objeto Nota)
class _EditNotaDialog extends StatefulWidget {
  final Nota nota;
  final List<String> etiquetasDisponibles;
  final Function(String?, List<String>) onSave;

  const _EditNotaDialog({
    required this.nota,
    required this.etiquetasDisponibles,
    required this.onSave,
  });

  @override
  State<_EditNotaDialog> createState() => _EditNotaDialogState();
}

class _EditNotaDialogState extends State<_EditNotaDialog> {
  late TextEditingController _comentarioController;
  late List<String> _etiquetasSeleccionadas;

  @override
  void initState() {
    super.initState();
    _comentarioController = TextEditingController(
      text: widget.nota.comentarioUsuario ?? '',
    );
    _etiquetasSeleccionadas = List<String>.from(widget.nota.etiquetas);
  }

  @override
  Widget build(BuildContext context) {
    // ... (El build del dialog no cambia)
    return AlertDialog(
      title: Text('Editar: ${widget.nota.articuloId}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomInput.multiline(
              label: 'Comentario',
              controller: _comentarioController,
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            // TODO: Implementar un widget selector de etiquetas aquí
            Text('Etiquetas: ${_etiquetasSeleccionadas.join(', ')}'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        CustomButton.primary(
          text: 'Guardar',
          onPressed: () {
            widget.onSave(
              _comentarioController.text.trim().isEmpty
                  ? null
                  : _comentarioController.text.trim(),
              _etiquetasSeleccionadas,
            );
            Navigator.pop(context);
          },
          size: ButtonSize.small,
        ),
      ],
    );
  }
}
