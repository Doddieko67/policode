import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:policode/models/user_model.dart';
import 'package:policode/services/admin_service.dart';
import 'package:policode/widgets/loading_widgets.dart';
import 'package:policode/widgets/admin_guard.dart';
import 'package:intl/intl.dart';

class UsersManagementScreen extends StatefulWidget {
  const UsersManagementScreen({super.key});

  @override
  State<UsersManagementScreen> createState() => _UsersManagementScreenState();
}

class _UsersManagementScreenState extends State<UsersManagementScreen>
    with SingleTickerProviderStateMixin {
  final AdminService _adminService = AdminService();
  final TextEditingController _searchController = TextEditingController();
  
  late TabController _tabController;
  String _searchQuery = '';
  UserStatus? _filterStatus;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AdminGuard(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Gestión de Usuarios'),
          centerTitle: true,
          elevation: 2,
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onPrimary,
          bottom: TabBar(
            controller: _tabController,
            onTap: (index) {
              setState(() {
                switch (index) {
                  case 0:
                    _filterStatus = null;
                    break;
                  case 1:
                    _filterStatus = UserStatus.active;
                    break;
                  case 2:
                    _filterStatus = UserStatus.suspended;
                    break;
                  case 3:
                    _filterStatus = UserStatus.banned;
                    break;
                }
              });
            },
            indicatorColor: theme.colorScheme.onPrimary,
            labelColor: theme.colorScheme.onPrimary,
            unselectedLabelColor: theme.colorScheme.onPrimary.withOpacity(0.7),
            tabs: const [
              Tab(text: 'Todos'),
              Tab(text: 'Activos'),
              Tab(text: 'Suspendidos'),
              Tab(text: 'Baneados'),
            ],
          ),
        ),
        body: Column(
          children: [
            _buildSearchBar(),
            Expanded(
              child: _buildUsersList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Buscar usuarios por email o nombre...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _searchQuery = '';
                    });
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value.toLowerCase();
          });
        },
      ),
    );
  }

  Widget _buildUsersList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getUsersStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingWidget();
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }

        final users = snapshot.data?.docs ?? [];
        final filteredUsers = _filterUsers(users);

        if (filteredUsers.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No se encontraron usuarios'),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredUsers.length,
          itemBuilder: (context, index) {
            final userDoc = filteredUsers[index];
            final userData = UserModel.fromFirestore(userDoc);
            return _buildUserCard(userData);
          },
        );
      },
    );
  }

  Stream<QuerySnapshot> _getUsersStream() {
    Query query = FirebaseFirestore.instance.collection('users');
    
    if (_filterStatus != null) {
      query = query.where('status', isEqualTo: _filterStatus!.name);
    }
    
    return query.orderBy('createdAt', descending: true).snapshots();
  }

  List<QueryDocumentSnapshot> _filterUsers(List<QueryDocumentSnapshot> users) {
    if (_searchQuery.isEmpty) return users;
    
    return users.where((userDoc) {
      final data = userDoc.data() as Map<String, dynamic>;
      final email = (data['email'] ?? '').toString().toLowerCase();
      final displayName = (data['displayName'] ?? '').toString().toLowerCase();
      
      return email.contains(_searchQuery) || displayName.contains(_searchQuery);
    }).toList();
  }

  Widget _buildUserCard(UserModel user) {
    final theme = Theme.of(context);
    
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _showUserDetails(user),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                    child: Text(
                      user.displayName?.isNotEmpty == true
                          ? user.displayName![0].toUpperCase()
                          : user.email[0].toUpperCase(),
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.displayName ?? 'Sin nombre',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user.email,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildStatusChip(user.status),
                      if (user.role == UserRole.admin) ...[
                        const SizedBox(height: 4),
                        _buildRoleChip(),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Registro: ${DateFormat('dd/MM/yyyy').format(user.createdAt)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.flag_outlined,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Reportes: ${user.reportCount}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: user.reportCount > 0 ? Colors.orange : theme.colorScheme.onSurfaceVariant,
                      fontWeight: user.reportCount > 0 ? FontWeight.w600 : null,
                    ),
                  ),
                ],
              ),
              if (user.isSuspended && user.suspendedUntil != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.schedule, size: 16, color: Colors.orange),
                      const SizedBox(width: 4),
                      Text(
                        'Suspendido hasta: ${DateFormat('dd/MM/yyyy HH:mm').format(user.suspendedUntil!)}',
                        style: const TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(UserStatus status) {
    Color color;
    String label;
    
    switch (status) {
      case UserStatus.active:
        color = Colors.green;
        label = 'ACTIVO';
        break;
      case UserStatus.suspended:
        color = Colors.orange;
        label = 'SUSPENDIDO';
        break;
      case UserStatus.banned:
        color = Colors.red;
        label = 'BANEADO';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildRoleChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple),
      ),
      child: const Text(
        'ADMIN',
        style: TextStyle(
          color: Colors.purple,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showUserDetails(UserModel user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) {
          return UserDetailSheet(
            user: user,
            adminService: _adminService,
            scrollController: scrollController,
          );
        },
      ),
    );
  }
}

class UserDetailSheet extends StatefulWidget {
  final UserModel user;
  final AdminService adminService;
  final ScrollController scrollController;

  const UserDetailSheet({
    super.key,
    required this.user,
    required this.adminService,
    required this.scrollController,
  });

  @override
  State<UserDetailSheet> createState() => _UserDetailSheetState();
}

class _UserDetailSheetState extends State<UserDetailSheet> {
  late UserModel _currentUser;
  String? _currentAdminId;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
    _loadCurrentAdminId();
  }

  Future<void> _loadCurrentAdminId() async {
    try {
      final adminId = await _getCurrentAdminId();
      if (mounted) {
        setState(() {
          _currentAdminId = adminId;
        });
      }
    } catch (e) {
      // Error silencioso
    }
  }

  Future<String?> _getCurrentAdminId() async {
    // Acceder al FirebaseAuth directamente
    return FirebaseAuth.instance.currentUser?.uid;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Detalles del Usuario',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView(
              controller: widget.scrollController,
              children: [
                _buildUserInfo(),
                const SizedBox(height: 20),
                _buildUserStats(),
                const SizedBox(height: 20),
                if (_currentAdminId != null && _currentUser.uid != _currentAdminId)
                  _buildActions(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserInfo() {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                  child: Text(
                    _currentUser.displayName?.isNotEmpty == true
                        ? _currentUser.displayName![0].toUpperCase()
                        : _currentUser.email[0].toUpperCase(),
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentUser.displayName ?? 'Sin nombre',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _currentUser.email,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildStatusChip(_currentUser.status),
                          if (_currentUser.role == UserRole.admin) ...[
                            const SizedBox(width: 8),
                            _buildRoleChip(),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow('UID', _currentUser.uid),
            _buildInfoRow(
              'Fecha de registro',
              DateFormat('dd/MM/yyyy HH:mm').format(_currentUser.createdAt),
            ),
            if (_currentUser.suspendedUntil != null)
              _buildInfoRow(
                'Suspendido hasta',
                DateFormat('dd/MM/yyyy HH:mm').format(_currentUser.suspendedUntil!),
              ),
            if (_currentUser.suspensionReason != null)
              _buildInfoRow('Razón suspensión', _currentUser.suspensionReason!),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _buildUserStats() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Estadísticas',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Reportes',
                    _currentUser.reportCount.toString(),
                    Icons.flag,
                    _currentUser.reportCount > 0 ? Colors.orange : Colors.grey,
                  ),
                ),
                Expanded(
                  child: FutureBuilder<Map<String, int>>(
                    future: _getUserPosts(),
                    builder: (context, snapshot) {
                      final posts = snapshot.data?['posts'] ?? 0;
                      return _buildStatItem(
                        'Posts',
                        posts.toString(),
                        Icons.article,
                        Colors.blue,
                      );
                    },
                  ),
                ),
                Expanded(
                  child: FutureBuilder<Map<String, int>>(
                    future: _getUserPosts(),
                    builder: (context, snapshot) {
                      final replies = snapshot.data?['replies'] ?? 0;
                      return _buildStatItem(
                        'Respuestas',
                        replies.toString(),
                        Icons.comment,
                        Colors.green,
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Future<Map<String, int>> _getUserPosts() async {
    try {
      final postsQuery = await FirebaseFirestore.instance
          .collection('forum_posts')
          .where('autorId', isEqualTo: _currentUser.uid)
          .count()
          .get();

      final repliesQuery = await FirebaseFirestore.instance
          .collection('forum_replies')
          .where('autorId', isEqualTo: _currentUser.uid)
          .count()
          .get();

      return {
        'posts': postsQuery.count ?? 0,
        'replies': repliesQuery.count ?? 0,
      };
    } catch (e) {
      return {'posts': 0, 'replies': 0};
    }
  }

  Widget _buildActions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Acciones de Moderación',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (_currentUser.status == UserStatus.active) ...[
              _buildActionButton(
                'Suspender 24 horas',
                Icons.schedule,
                Colors.orange,
                () => _suspendUser(const Duration(hours: 24)),
              ),
              const SizedBox(height: 8),
              _buildActionButton(
                'Suspender 7 días',
                Icons.calendar_today,
                Colors.orange,
                () => _suspendUser(const Duration(days: 7)),
              ),
              const SizedBox(height: 8),
              _buildActionButton(
                'Suspender 30 días',
                Icons.date_range,
                Colors.orange,
                () => _suspendUser(const Duration(days: 30)),
              ),
              const SizedBox(height: 8),
              _buildActionButton(
                'Banear permanentemente',
                Icons.block,
                Colors.red,
                () => _banUser(),
              ),
            ] else if (_currentUser.status == UserStatus.suspended) ...[
              _buildActionButton(
                'Reactivar usuario',
                Icons.check_circle,
                Colors.green,
                () => _reactivateUser(),
              ),
              const SizedBox(height: 8),
              _buildActionButton(
                'Banear permanentemente',
                Icons.block,
                Colors.red,
                () => _banUser(),
              ),
            ] else if (_currentUser.status == UserStatus.banned) ...[
              _buildActionButton(
                'Reactivar usuario',
                Icons.check_circle,
                Colors.green,
                () => _reactivateUser(),
              ),
            ],
            if (_currentUser.role == UserRole.user) ...[
              const SizedBox(height: 8),
              _buildActionButton(
                'Hacer administrador',
                Icons.admin_panel_settings,
                Colors.purple,
                () => _makeAdmin(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    String text,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: color),
        label: Text(text, style: TextStyle(color: color)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  void _suspendUser(Duration duration) {
    _showConfirmationDialog(
      'Suspender Usuario',
      '¿Estás seguro de que quieres suspender a este usuario por ${duration.inDays > 0 ? '${duration.inDays} días' : '${duration.inHours} horas'}?',
      () async {
        try {
          await widget.adminService.suspendUser(
            _currentUser.uid,
            duration,
            'Suspendido desde panel de administración',
          );
          
          // Actualizar estado local
          final updatedUser = await widget.adminService.getUserById(_currentUser.uid);
          if (updatedUser != null && mounted) {
            setState(() {
              _currentUser = updatedUser;
            });
          }
          
          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Usuario suspendido exitosamente')),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error suspendiendo usuario: $e')),
            );
          }
        }
      },
    );
  }

  void _banUser() {
    _showConfirmationDialog(
      'Banear Usuario',
      '¿Estás seguro de que quieres banear permanentemente a este usuario? Esta acción es irreversible.',
      () async {
        try {
          await widget.adminService.banUser(
            _currentUser.uid,
            'Baneado desde panel de administración',
          );
          
          // Actualizar estado local
          final updatedUser = await widget.adminService.getUserById(_currentUser.uid);
          if (updatedUser != null && mounted) {
            setState(() {
              _currentUser = updatedUser;
            });
          }
          
          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Usuario baneado exitosamente')),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error baneando usuario: $e')),
            );
          }
        }
      },
    );
  }

  void _reactivateUser() {
    _showConfirmationDialog(
      'Reactivar Usuario',
      '¿Estás seguro de que quieres reactivar a este usuario?',
      () async {
        try {
          await widget.adminService.reactivateUser(_currentUser.uid);
          
          // Actualizar estado local
          final updatedUser = await widget.adminService.getUserById(_currentUser.uid);
          if (updatedUser != null && mounted) {
            setState(() {
              _currentUser = updatedUser;
            });
          }
          
          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Usuario reactivado exitosamente')),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error reactivando usuario: $e')),
            );
          }
        }
      },
    );
  }

  void _makeAdmin() {
    _showConfirmationDialog(
      'Hacer Administrador',
      '¿Estás seguro de que quieres dar permisos de administrador a este usuario?',
      () async {
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(_currentUser.uid)
              .update({'role': 'admin'});
          
          // Actualizar estado local
          final updatedUser = await widget.adminService.getUserById(_currentUser.uid);
          if (updatedUser != null && mounted) {
            setState(() {
              _currentUser = updatedUser;
            });
          }
          
          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Usuario promovido a administrador')),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error promoviendo usuario: $e')),
            );
          }
        }
      },
    );
  }

  void _showConfirmationDialog(String title, String message, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(UserStatus status) {
    Color color;
    String label;
    
    switch (status) {
      case UserStatus.active:
        color = Colors.green;
        label = 'ACTIVO';
        break;
      case UserStatus.suspended:
        color = Colors.orange;
        label = 'SUSPENDIDO';
        break;
      case UserStatus.banned:
        color = Colors.red;
        label = 'BANEADO';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildRoleChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple),
      ),
      child: const Text(
        'ADMIN',
        style: TextStyle(
          color: Colors.purple,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}