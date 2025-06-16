import 'package:flutter/material.dart';
import 'package:policode/models/nota_model.dart'; // <<< 1. IMPORTAR MODELO
import 'package:policode/services/auth_service.dart';
import 'package:policode/services/admin_service.dart';
import 'package:policode/widgets/custom_button.dart';
import 'package:policode/widgets/custom_cards.dart';
// import 'package:policode/widgets/custom_cards.dart'; // Ya no se necesita si NotaCard está separada
import 'package:policode/widgets/loading_widgets.dart';
// import '../services/auth_service.dart';
import '../services/reglamento_service.dart';
import '../services/notas_service.dart';
import '../services/forum_service.dart';
import '../services/notification_service.dart';

/// Pantalla principal de la aplicación
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  final AdminService _adminService = AdminService();
  final ReglamentoService _reglamentoService = ReglamentoService();
  final NotasService _notasService = NotasService();
  final ForumService _forumService = ForumService();
  final NotificationService _notificationService = NotificationService();

  bool _isLoading = true;
  bool _isAdmin = false;
  Map<String, dynamic>? _estadisticas;
  Map<String, int>? _statsNotas;
  Map<String, int>? _statsForum;
  String? _errorMessage;

  // <<< 3. DECLARAR LA VARIABLE DE ESTADO PARA LAS NOTAS RECIENTES
  List<Nota> _notasRecientes = [];

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    // Si la pantalla ya no existe, no hacemos nada.
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Cargar reglamento si no está cargado
      if (!_reglamentoService.isLoaded) {
        await _reglamentoService.cargarReglamento();
      }

      // Obtener estadísticas del reglamento
      final articulos = await _reglamentoService.articulos;
      _estadisticas = ReglamentoUtils.generarEstadisticas(articulos);

      // <<< 4. MODIFICAR LA LÓGICA PARA CARGAR NOTAS RECIENTES
      if (_authService.isSignedIn) {
        final userId = _authService.currentUser!.uid;

        // Verificar si es admin
        _isAdmin = await _adminService.isCurrentUserAdmin();

        // Usamos Future.wait para ejecutar ambas llamadas en paralelo y ser más eficientes
        final results = await Future.wait([
          _notasService.getEstadisticas(userId),
          _notasService.getNotasRecientes(userId, limit: 3), // Pide 3 notas
          _forumService.getForumStats(), // Agregar estadísticas del foro
        ]);

        // Asignamos los resultados a nuestras variables de estado
        _statsNotas = results[0] as Map<String, int>;
        _notasRecientes = results[1] as List<Nota>;
        _statsForum = results[2] as Map<String, int>;
      } else {
        // Si el usuario no está logueado, nos aseguramos de que la lista esté vacía
        _notasRecientes = [];
        _statsNotas = null;
        // Cargar estadísticas del foro aunque no esté logueado
        _statsForum = await _forumService.getForumStats();
      }

      // Solo actualizamos el estado si el widget todavía está en el árbol.
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error cargando datos: $e';
        });
      }
    }
  }

  // <<< 5. ASEGÚRATE DE TENER ESTE MÉTODO EN `notas_service.dart`
  // En `lib/services/notas_service.dart`:
  /*
  Future<List<Nota>> getNotasRecientes(String userId, {int limit = 3}) async {
    final snapshot = await _db
        .collection('users')
        .doc(userId)
        .collection('notas')
        .where('esArchivada', isEqualTo: false) // Opcional: no mostrar archivadas
        .orderBy('fechaGuardado', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs.map((doc) => Nota.fromFirestore(doc.data())).toList();
  }
  */

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
      floatingActionButton: _buildFAB(theme),
    );
  }

  PreferredSizeWidget _buildAppBar(ThemeData theme) {
    // ... (sin cambios)
    final user = _authService.currentUser;

    return AppBar(
      elevation: 0,
      backgroundColor: theme.colorScheme.surface,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            user != null ? '¡Hola, ${user.nombre ?? "Usuario"}!' : '¡Hola!',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          Text(
            'Bienvenido a PoliCode',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ),
      actions: [
        // Botón de notificaciones
        if (user != null)
          StreamBuilder<int>(
            stream: _notificationService.getUnreadCount(),
            builder: (context, snapshot) {
              final unreadCount = snapshot.data ?? 0;
              
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined),
                    onPressed: () {
                      Navigator.pushNamed(context, '/notifications');
                    },
                    tooltip: 'Avisos',
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          unreadCount > 99 ? '99+' : unreadCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        
        if (user != null)
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            icon: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  user.iniciales,
                  style: TextStyle(
                    color: theme.primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(
                      Icons.logout,
                      size: 20,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Cerrar Sesión',
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ],
                ),
              ),
            ],
          )
        else
          IconButton(
            onPressed: () => Navigator.pushNamed(context, '/auth'),
            icon: const Icon(Icons.login),
            tooltip: 'Iniciar Sesión',
          ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildErrorState() {
    // ... (sin cambios)
    return Center(
      child: CustomErrorWidget.generic(
        title: 'Error cargando datos',
        message: _errorMessage,
        onRetry: _cargarDatos,
      ),
    );
  }

  Widget _buildContent() {
    return RefreshIndicator(
      onRefresh: _cargarDatos,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeCard(),
            const SizedBox(height: 24),
            _buildStatsSection(),
            const SizedBox(height: 24),
            // <<< 6. MODIFICACIÓN PARA MOSTRAR LA SECCIÓN SÓLO SI HAY NOTAS
            if (_authService.isSignedIn && _notasRecientes.isNotEmpty) ...[
              _buildRecentNotesSection(),
              const SizedBox(height: 20),
            ]
            // Opcional: Si quieres mostrar un mensaje si no hay notas
            else if (_authService.isSignedIn)
              _buildNoRecentNotes(),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    // ... (sin cambios)
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
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
          Row(
            children: [
              Container(
                width: 75,
                height: 75,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const CircleAvatar(
                  backgroundColor: Colors.white,
                  radius: 18,
                  backgroundImage: AssetImage('assets/images/logo.png'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Asistente del Reglamento',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Pregúntame cualquier cosa sobre el reglamento estudiantil. Estoy aquí para ayudarte a encontrar la información que necesitas.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withOpacity(0.9),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: CustomButton(
                  text: 'Preguntar',
                  onPressed: () => Navigator.pushNamed(context, '/chat'),
                  type: ButtonType.secondary,
                  customColor: Colors.white,
                  icon: Icons.chat_bubble_outline,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CustomButton(
                  text: 'Ver Foro',
                  onPressed: () => Navigator.pushNamed(context, '/forum'),
                  type: ButtonType.secondary,
                  customColor: Colors.white,
                  icon: Icons.forum,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: CustomButton(
                  text: 'Mis posts',
                  onPressed: () => Navigator.pushNamed(context, '/mis-posts'),
                  type: ButtonType.secondary,
                  customColor: Colors.white,
                  icon: Icons.person_outline,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CustomButton(
                  text: 'Avisos',
                  onPressed: () => Navigator.pushNamed(context, '/notifications'),
                  type: ButtonType.secondary,
                  customColor: Colors.white,
                  icon: Icons.notifications_outlined,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: CustomButton(
                  text: 'Notas',
                  onPressed: () => Navigator.pushNamed(context, '/notas'),
                  type: ButtonType.secondary,
                  customColor: Colors.white,
                  icon: Icons.note,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: CustomButton(
                  text: 'Normativa',
                  onPressed: () => Navigator.pushNamed(context, '/reglamentos'),
                  type: ButtonType.secondary,
                  customColor: Colors.white,
                  icon: Icons.gavel,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              if (_isAdmin) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: CustomButton(
                    text: 'Admin',
                    onPressed: () => Navigator.pushNamed(context, '/admin'),
                    type: ButtonType.secondary,
                    customColor: Colors.orange[50],
                    icon: Icons.admin_panel_settings,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    if (_estadisticas == null || _statsForum == null) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Estadísticas',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Total Artículos',
                '${_estadisticas!['total_articulos']}',
                Icons.article,
                Colors.blue,
              ),
            ),
            Expanded(
              child: _buildStatCard(
                'Posts del Foro',
                '${_statsForum!['totalPosts'] ?? 0}',
                Icons.forum,
                Colors.green,
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Respuestas',
                '${_statsForum!['totalReplies'] ?? 0}',
                Icons.chat_bubble_outline,
                Colors.orange,
              ),
            ),
            Expanded(
              child: _buildStatCard(
                'Total Temas',
                '${_statsForum!['totalTopics'] ?? 0}',
                Icons.topic,
                Colors.purple,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    // ... (sin cambios)
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.all(4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // <<< 7. WIDGET DE NOTAS RECIENTES (EL QUE TENÍAS)
  Widget _buildRecentNotesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Notas Recientes',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/notas').then((_) {
                _cargarDatos();
              }),
              child: const Text('Ver todas'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ListView.separated(
          itemCount: _notasRecientes.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final nota = _notasRecientes[index];
            return Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: Theme.of(context).dividerColor,
                  width: 0.5,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: NotaCard(
                nota: nota,
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    '/articulo',
                    arguments: {'articuloId': nota.articuloId},
                  ).then((_) => _cargarDatos());
                },
                showActions: false,
              ),
            );
          },
        ),
      ],
    );
  }

  // <<< 8. WIDGET OPCIONAL PARA CUANDO NO HAY NOTAS
  Widget _buildNoRecentNotes() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            Icons.note_add_outlined,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Aún no tienes notas. ¡Empieza a guardar artículos para verlos aquí!',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFAB(ThemeData theme) {
    // ... (sin cambios)
    return CustomFloatingButton(
      icon: Icons.chat,
      onPressed: () => Navigator.pushNamed(context, '/chat'),
      tooltip: 'Abrir Chat',
      backgroundColor: theme.primaryColor,
    );
  }

  void _handleMenuAction(String action) {
    // ... (sin cambios)
    switch (action) {
      case 'profile':
        Navigator.pushNamed(context, '/profile');
        break;
      case 'settings':
        Navigator.pushNamed(context, '/settings');
        break;
      case 'logout':
        _showLogoutDialog();
        break;
    }
  }

  void _showLogoutDialog() {
    // ... (sin cambios)
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Estás seguro de que quieres cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          CustomButton.danger(
            text: 'Cerrar Sesión',
            onPressed: () async {
              Navigator.pop(context); // Cierra el diálogo
              await _authService
                  .signOut(); // <--- ESTO LLAMA AL MÉTODO CON LA LÓGICA DE GOOGLE
              if (mounted) {
                Navigator.pushReplacementNamed(context, '/auth');
              }
            },
            size: ButtonSize.small,
          ),
        ],
      ),
    );
  }
}
