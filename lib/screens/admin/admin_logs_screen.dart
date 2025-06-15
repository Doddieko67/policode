import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:policode/services/admin_service.dart';
import 'package:policode/widgets/loading_widgets.dart';
import 'package:policode/widgets/admin_guard.dart';
import 'package:intl/intl.dart';

class AdminLogsScreen extends StatefulWidget {
  const AdminLogsScreen({super.key});

  @override
  State<AdminLogsScreen> createState() => _AdminLogsScreenState();
}

class _AdminLogsScreenState extends State<AdminLogsScreen> {
  final AdminService _adminService = AdminService();
  final TextEditingController _searchController = TextEditingController();
  
  String _searchQuery = '';
  String? _filterAction;
  int _limit = 50;

  final Map<String, String> _actionLabels = {
    'suspend_user': 'Suspender Usuario',
    'ban_user': 'Banear Usuario',
    'reactivate_user': 'Reactivar Usuario',
    'delete_post': 'Eliminar Post',
    'delete_reply': 'Eliminar Respuesta',
    'upload_regulation': 'Subir Reglamento',
    'update_regulation': 'Actualizar Reglamento',
    'delete_regulation': 'Eliminar Reglamento',
  };

  final Map<String, Color> _actionColors = {
    'suspend_user': Colors.orange,
    'ban_user': Colors.red,
    'reactivate_user': Colors.green,
    'delete_post': Colors.red,
    'delete_reply': Colors.red,
    'upload_regulation': Colors.blue,
    'update_regulation': Colors.blue,
    'delete_regulation': Colors.orange,
  };

  final Map<String, IconData> _actionIcons = {
    'suspend_user': Icons.schedule,
    'ban_user': Icons.block,
    'reactivate_user': Icons.check_circle,
    'delete_post': Icons.delete,
    'delete_reply': Icons.delete,
    'upload_regulation': Icons.upload,
    'update_regulation': Icons.edit,
    'delete_regulation': Icons.delete_outline,
  };

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AdminGuard(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Logs de Administración'),
          centerTitle: true,
          elevation: 2,
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onPrimary,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                setState(() {});
              },
            ),
          ],
        ),
        body: Column(
          children: [
            _buildFilters(),
            Expanded(
              child: _buildLogsList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Buscar en logs...',
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
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _filterAction,
                  decoration: InputDecoration(
                    labelText: 'Filtrar por acción',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('Todas las acciones'),
                    ),
                    ..._actionLabels.entries.map((entry) {
                      return DropdownMenuItem<String>(
                        value: entry.key,
                        child: Row(
                          children: [
                            Icon(
                              _actionIcons[entry.key],
                              size: 16,
                              color: _actionColors[entry.key],
                            ),
                            const SizedBox(width: 8),
                            Text(entry.value),
                          ],
                        ),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _filterAction = value;
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<int>(
                value: _limit,
                items: const [
                  DropdownMenuItem(value: 25, child: Text('25')),
                  DropdownMenuItem(value: 50, child: Text('50')),
                  DropdownMenuItem(value: 100, child: Text('100')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _limit = value;
                    });
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLogsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getLogsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingWidget();
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          );
        }

        final logs = snapshot.data?.docs ?? [];
        final filteredLogs = _filterLogs(logs);

        if (filteredLogs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No se encontraron logs'),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredLogs.length,
          itemBuilder: (context, index) {
            final logDoc = filteredLogs[index];
            final logData = logDoc.data() as Map<String, dynamic>;
            return _buildLogCard(logData);
          },
        );
      },
    );
  }

  Stream<QuerySnapshot> _getLogsStream() {
    Query query = FirebaseFirestore.instance.collection('admin_logs');
    
    if (_filterAction != null) {
      query = query.where('action', isEqualTo: _filterAction);
    }
    
    return query
        .orderBy('timestamp', descending: true)
        .limit(_limit)
        .snapshots();
  }

  List<QueryDocumentSnapshot> _filterLogs(List<QueryDocumentSnapshot> logs) {
    if (_searchQuery.isEmpty) return logs;
    
    return logs.where((logDoc) {
      final data = logDoc.data() as Map<String, dynamic>;
      final details = (data['details'] ?? '').toString().toLowerCase();
      final action = (data['action'] ?? '').toString().toLowerCase();
      
      return details.contains(_searchQuery) || action.contains(_searchQuery);
    }).toList();
  }

  Widget _buildLogCard(Map<String, dynamic> logData) {
    final theme = Theme.of(context);
    final action = logData['action'] as String? ?? '';
    final details = logData['details'] as String? ?? '';
    final timestamp = (logData['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
    final adminId = logData['adminId'] as String? ?? '';
    final targetUserId = logData['targetUserId'] as String?;
    final contentId = logData['contentId'] as String?;

    final actionLabel = _actionLabels[action] ?? action;
    final actionColor = _actionColors[action] ?? Colors.grey;
    final actionIcon = _actionIcons[action] ?? Icons.info;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _showLogDetails(logData),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: actionColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      actionIcon,
                      color: actionColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          actionLabel,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: actionColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          DateFormat('dd/MM/yyyy HH:mm:ss').format(timestamp),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _getTimeAgo(timestamp),
                      style: TextStyle(
                        color: theme.colorScheme.onSecondaryContainer,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                details,
                style: theme.textTheme.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (targetUserId != null || contentId != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (targetUserId != null) ...[
                      Icon(
                        Icons.person,
                        size: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Usuario: ${targetUserId.substring(0, 8)}...',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (contentId != null) const SizedBox(width: 16),
                    ],
                    if (contentId != null) ...[
                      Icon(
                        Icons.link,
                        size: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'ID: ${contentId.substring(0, 8)}...',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _getTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Ahora';
    } else if (difference.inMinutes < 60) {
      return 'Hace ${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return 'Hace ${difference.inHours}h';
    } else {
      return 'Hace ${difference.inDays}d';
    }
  }

  void _showLogDetails(Map<String, dynamic> logData) {
    final action = logData['action'] as String? ?? '';
    final details = logData['details'] as String? ?? '';
    final timestamp = (logData['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
    final adminId = logData['adminId'] as String? ?? '';
    final targetUserId = logData['targetUserId'] as String?;
    final contentId = logData['contentId'] as String?;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_actionLabels[action] ?? action),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Fecha y hora', DateFormat('dd/MM/yyyy HH:mm:ss').format(timestamp)),
              _buildDetailRow('Administrador', adminId),
              if (targetUserId != null)
                _buildDetailRow('Usuario objetivo', targetUserId),
              if (contentId != null)
                _buildDetailRow('ID de contenido', contentId),
              const SizedBox(height: 8),
              const Text(
                'Detalles:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(details),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
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
            child: Text(
              value,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }
}