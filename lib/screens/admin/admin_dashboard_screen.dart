import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:policode/services/admin_service.dart';
import 'package:policode/widgets/loading_widgets.dart';
import 'package:policode/widgets/admin_guard.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final AdminService _adminService = AdminService();
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final stats = await _adminService.getSystemStats();
      if (mounted) {
        setState(() {
          _stats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AdminGuard(
      child: Scaffold(
      appBar: AppBar(
        title: const Text('Panel de Administración'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const LoadingWidget()
          : RefreshIndicator(
              onRefresh: _loadStats,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Resumen del Sistema',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildStatsGrid(theme),
                    const SizedBox(height: 32),
                    Text(
                      'Acciones Rápidas',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildQuickActions(context, theme),
                  ],
                ),
              ),
            ),
      ),
    );
  }

  Widget _buildStatsGrid(ThemeData theme) {
    return MasonryGridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      itemCount: 8,
      itemBuilder: (context, index) {
        switch (index) {
          case 0:
            return _buildStatCard(
              theme: theme,
              title: 'Usuarios Activos',
              value: _stats['activeUsers']?.toString() ?? '0',
              icon: Icons.people,
              color: Colors.blue,
            );
          case 1:
            return _buildStatCard(
              theme: theme,
              title: 'Posts Totales',
              value: _stats['totalPosts']?.toString() ?? '0',
              icon: Icons.article,
              color: Colors.green,
            );
          case 2:
            return _buildStatCard(
              theme: theme,
              title: 'Reportes Pendientes',
              value: _stats['pendingReports']?.toString() ?? '0',
              icon: Icons.flag,
              color: Colors.orange,
              highlight: (_stats['pendingReports'] ?? 0) > 0,
            );
          case 3:
            return _buildStatCard(
              theme: theme,
              title: 'Usuarios Suspendidos',
              value: _stats['suspendedUsers']?.toString() ?? '0',
              icon: Icons.block,
              color: Colors.red,
              highlight: (_stats['suspendedUsers'] ?? 0) > 0,
            );
          case 4:
            return _buildStatCard(
              theme: theme,
              title: 'Respuestas',
              value: _stats['totalReplies']?.toString() ?? '0',
              icon: Icons.comment,
              color: Colors.teal,
            );
          case 5:
            return _buildStatCard(
              theme: theme,
              title: 'Posts Recientes',
              value: _stats['recentPosts']?.toString() ?? '0',
              icon: Icons.trending_up,
              color: Colors.purple,
            );
          case 6:
            return _buildStatCard(
              theme: theme,
              title: 'Reglamentos',
              value: _stats['activeRegulations']?.toString() ?? '0',
              icon: Icons.gavel,
              color: Colors.indigo,
            );
          case 7:
            return _buildStatCard(
              theme: theme,
              title: 'Usuarios Baneados',
              value: _stats['bannedUsers']?.toString() ?? '0',
              icon: Icons.dangerous,
              color: Colors.red[800]!,
              highlight: (_stats['bannedUsers'] ?? 0) > 0,
            );
          default:
            return const SizedBox();
        }
      },
    );
  }

  Widget _buildStatCard({
    required ThemeData theme,
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    bool highlight = false,
  }) {
    return Card(
      elevation: highlight ? 6 : 3,
      color: highlight ? color.withOpacity(0.1) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: highlight
            ? BorderSide(color: color, width: 2)
            : BorderSide.none,
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 32,
                color: color,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: highlight ? color : theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (highlight) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Requiere atención',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, ThemeData theme) {
    return Column(
      children: [
        _buildActionTile(
          context: context,
          theme: theme,
          icon: Icons.flag_outlined,
          title: 'Gestionar Reportes',
          subtitle: _stats['pendingReports'] != null && _stats['pendingReports'] > 0
              ? '${_stats['pendingReports']} reportes pendientes'
              : 'Ver todos los reportes',
          color: Colors.orange,
          onTap: () {
            Navigator.pushNamed(context, '/admin/reports');
          },
        ),
        const SizedBox(height: 12),
        _buildActionTile(
          context: context,
          theme: theme,
          icon: Icons.gavel,
          title: 'Gestionar Reglamentos',
          subtitle: 'Subir y editar leyes y reglamentos',
          color: Colors.purple,
          onTap: () {
            Navigator.pushNamed(context, '/admin/regulations');
          },
        ),
        const SizedBox(height: 12),
        _buildActionTile(
          context: context,
          theme: theme,
          icon: Icons.article_outlined,
          title: 'Gestionar Posts',
          subtitle: 'Moderar y administrar posts del foro',
          color: Colors.green,
          onTap: () {
            Navigator.pushNamed(context, '/admin/posts');
          },
        ),
        const SizedBox(height: 12),
        _buildActionTile(
          context: context,
          theme: theme,
          icon: Icons.people_outline,
          title: 'Gestionar Usuarios',
          subtitle: 'Ver y moderar usuarios',
          color: Colors.blue,
          onTap: () {
            Navigator.pushNamed(context, '/admin/users');
          },
        ),
        const SizedBox(height: 12),
        _buildActionTile(
          context: context,
          theme: theme,
          icon: Icons.history,
          title: 'Logs de Administración',
          subtitle: 'Ver historial de acciones',
          color: Colors.grey,
          onTap: () {
            Navigator.pushNamed(context, '/admin/logs');
          },
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required BuildContext context,
    required ThemeData theme,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: color,
            size: 24,
          ),
        ),
        title: Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}