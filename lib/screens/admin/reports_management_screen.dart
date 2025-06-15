import 'package:flutter/material.dart';
import 'package:policode/models/report_model.dart';
import 'package:policode/services/admin_service.dart';
import 'package:policode/widgets/loading_widgets.dart';
import 'package:policode/widgets/admin_guard.dart';
import 'package:intl/intl.dart';

class ReportsManagementScreen extends StatefulWidget {
  const ReportsManagementScreen({super.key});

  @override
  State<ReportsManagementScreen> createState() => _ReportsManagementScreenState();
}

class _ReportsManagementScreenState extends State<ReportsManagementScreen>
    with SingleTickerProviderStateMixin {
  final AdminService _adminService = AdminService();
  late TabController _tabController;
  ReportStatus? _filterStatus;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AdminGuard(
      child: Scaffold(
        appBar: AppBar(
        title: const Text('Gestión de Reportes'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          onTap: (index) {
            setState(() {
              switch (index) {
                case 0:
                  _filterStatus = null;
                  break;
                case 1:
                  _filterStatus = ReportStatus.pending;
                  break;
                case 2:
                  _filterStatus = ReportStatus.reviewed;
                  break;
                case 3:
                  _filterStatus = ReportStatus.resolved;
                  break;
              }
            });
          },
          tabs: const [
            Tab(text: 'Todos'),
            Tab(text: 'Pendientes'),
            Tab(text: 'En revisión'),
            Tab(text: 'Resueltos'),
          ],
        ),
      ),
      body: StreamBuilder<List<ReportModel>>(
        stream: _adminService.getReports(status: _filterStatus),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingWidget();
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          final reports = snapshot.data ?? [];

          if (reports.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.flag_outlined,
                    size: 64,
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No hay reportes',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: reports.length,
            itemBuilder: (context, index) {
              final report = reports[index];
              return _buildReportCard(context, theme, report);
            },
          );
        },
      ),
      ),
    );
  }

  Widget _buildReportCard(BuildContext context, ThemeData theme, ReportModel report) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _showReportDetails(context, report),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildStatusChip(theme, report.status),
                  const SizedBox(width: 8),
                  _buildTypeChip(theme, report.type),
                  const Spacer(),
                  Text(
                    DateFormat('dd/MM/yyyy HH:mm').format(report.createdAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Reportado: ${report.reportedUserName}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    _getContentIcon(report.contentType),
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Contenido: ${report.contentPreview}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Razón: ${report.reason}',
                style: theme.textTheme.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (report.status == ReportStatus.pending) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _dismissReport(context, report),
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Desestimar'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _showReportDetails(context, report),
                      icon: const Icon(Icons.visibility, size: 16),
                      label: const Text('Revisar'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(ThemeData theme, ReportStatus status) {
    Color color;
    switch (status) {
      case ReportStatus.pending:
        color = Colors.orange;
        break;
      case ReportStatus.reviewed:
        color = Colors.blue;
        break;
      case ReportStatus.resolved:
        color = Colors.green;
        break;
      case ReportStatus.dismissed:
        color = Colors.grey;
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
        status.name.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTypeChip(ThemeData theme, ReportType type) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        type.name,
        style: TextStyle(
          color: theme.colorScheme.onSecondaryContainer,
          fontSize: 10,
        ),
      ),
    );
  }

  IconData _getContentIcon(ReportedContentType type) {
    switch (type) {
      case ReportedContentType.post:
        return Icons.article;
      case ReportedContentType.reply:
        return Icons.comment;
      case ReportedContentType.user:
        return Icons.person;
    }
  }

  void _dismissReport(BuildContext context, ReportModel report) {
    showDialog(
      context: context,
      builder: (context) {
        final reasonController = TextEditingController();
        return AlertDialog(
          title: const Text('Desestimar Reporte'),
          content: TextField(
            controller: reasonController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Razón para desestimar',
              hintText: 'Explica por qué se desestima este reporte...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (reasonController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Por favor ingresa una razón'),
                    ),
                  );
                  return;
                }

                try {
                  await _adminService.dismissReport(
                    report.id,
                    reasonController.text.trim(),
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Reporte desestimado'),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Error al desestimar el reporte'),
                      ),
                    );
                  }
                }
              },
              child: const Text('Desestimar'),
            ),
          ],
        );
      },
    );
  }

  void _showReportDetails(BuildContext context, ReportModel report) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReportDetailScreen(report: report),
      ),
    );
  }
}

class ReportDetailScreen extends StatefulWidget {
  final ReportModel report;

  const ReportDetailScreen({super.key, required this.report});

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  final AdminService _adminService = AdminService();
  final _notesController = TextEditingController();
  String? _selectedAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle del Reporte'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoCard(theme),
            const SizedBox(height: 16),
            _buildContentCard(theme),
            const SizedBox(height: 16),
            if (widget.report.status == ReportStatus.pending ||
                widget.report.status == ReportStatus.reviewed)
              _buildActionsCard(theme),
            if (widget.report.status == ReportStatus.resolved ||
                widget.report.status == ReportStatus.dismissed)
              _buildResolutionCard(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Información del Reporte',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
              theme,
              'Estado:',
              widget.report.statusLabel,
              color: _getStatusColor(widget.report.status),
            ),
            _buildInfoRow(theme, 'Tipo:', widget.report.typeLabel),
            _buildInfoRow(
              theme,
              'Fecha:',
              DateFormat('dd/MM/yyyy HH:mm').format(widget.report.createdAt),
            ),
            _buildInfoRow(
              theme,
              'Reportado por:',
              widget.report.reporterName,
            ),
            _buildInfoRow(
              theme,
              'Usuario reportado:',
              widget.report.reportedUserName,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Contenido Reportado',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _getContentIcon(widget.report.contentType),
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.report.contentType.name.toUpperCase(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.report.contentPreview,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Razón del Reporte',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.report.reason,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Acciones de Moderación',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedAction,
              decoration: const InputDecoration(
                labelText: 'Seleccionar acción',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'delete_content',
                  child: Text('Eliminar contenido'),
                ),
                DropdownMenuItem(
                  value: 'warn_user',
                  child: Text('Advertir al usuario'),
                ),
                DropdownMenuItem(
                  value: 'suspend_24h',
                  child: Text('Suspender 24 horas'),
                ),
                DropdownMenuItem(
                  value: 'suspend_7d',
                  child: Text('Suspender 7 días'),
                ),
                DropdownMenuItem(
                  value: 'suspend_30d',
                  child: Text('Suspender 30 días'),
                ),
                DropdownMenuItem(
                  value: 'ban_user',
                  child: Text('Banear permanentemente'),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedAction = value;
                });
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notas de resolución',
                hintText: 'Describe las acciones tomadas...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _dismissReport(context),
                  child: const Text('Desestimar'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _selectedAction != null
                      ? () => _resolveReport(context)
                      : null,
                  child: const Text('Resolver'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResolutionCard(ThemeData theme) {
    return Card(
      color: theme.colorScheme.secondaryContainer.withOpacity(0.3),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Resolución',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (widget.report.reviewedAt != null)
              _buildInfoRow(
                theme,
                'Revisado:',
                DateFormat('dd/MM/yyyy HH:mm').format(widget.report.reviewedAt!),
              ),
            if (widget.report.actionTaken != null)
              _buildInfoRow(theme, 'Acción tomada:', widget.report.actionTaken!),
            if (widget.report.resolutionNotes != null) ...[
              const SizedBox(height: 8),
              Text(
                'Notas:',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.report.resolutionNotes!,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(ThemeData theme, String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: color,
                fontWeight: color != null ? FontWeight.w500 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(ReportStatus status) {
    switch (status) {
      case ReportStatus.pending:
        return Colors.orange;
      case ReportStatus.reviewed:
        return Colors.blue;
      case ReportStatus.resolved:
        return Colors.green;
      case ReportStatus.dismissed:
        return Colors.grey;
    }
  }

  IconData _getContentIcon(ReportedContentType type) {
    switch (type) {
      case ReportedContentType.post:
        return Icons.article;
      case ReportedContentType.reply:
        return Icons.comment;
      case ReportedContentType.user:
        return Icons.person;
    }
  }

  void _dismissReport(BuildContext context) async {
    if (_notesController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor ingresa notas de resolución'),
        ),
      );
      return;
    }

    try {
      await _adminService.dismissReport(
        widget.report.id,
        _notesController.text.trim(),
      );
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reporte desestimado'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al desestimar el reporte'),
          ),
        );
      }
    }
  }

  void _resolveReport(BuildContext context) async {
    if (_notesController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor ingresa notas de resolución'),
        ),
      );
      return;
    }

    try {
      // Ejecutar la acción seleccionada
      switch (_selectedAction) {
        case 'delete_content':
          if (widget.report.contentType == ReportedContentType.post) {
            await _adminService.deletePost(
              widget.report.contentId,
              _notesController.text.trim(),
            );
          } else if (widget.report.contentType == ReportedContentType.reply) {
            await _adminService.deleteReply(
              widget.report.contentId,
              _notesController.text.trim(),
            );
          }
          break;
        case 'warn_user':
          // Solo registrar la advertencia en las notas
          break;
        case 'suspend_24h':
          await _adminService.suspendUser(
            widget.report.reportedUserId,
            const Duration(hours: 24),
            _notesController.text.trim(),
          );
          break;
        case 'suspend_7d':
          await _adminService.suspendUser(
            widget.report.reportedUserId,
            const Duration(days: 7),
            _notesController.text.trim(),
          );
          break;
        case 'suspend_30d':
          await _adminService.suspendUser(
            widget.report.reportedUserId,
            const Duration(days: 30),
            _notesController.text.trim(),
          );
          break;
        case 'ban_user':
          await _adminService.banUser(
            widget.report.reportedUserId,
            _notesController.text.trim(),
          );
          break;
      }

      // Marcar el reporte como resuelto
      await _adminService.resolveReport(
        widget.report.id,
        _notesController.text.trim(),
        _getActionLabel(_selectedAction!),
      );

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reporte resuelto exitosamente'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al resolver el reporte'),
          ),
        );
      }
    }
  }

  String _getActionLabel(String action) {
    switch (action) {
      case 'delete_content':
        return 'Contenido eliminado';
      case 'warn_user':
        return 'Usuario advertido';
      case 'suspend_24h':
        return 'Usuario suspendido 24 horas';
      case 'suspend_7d':
        return 'Usuario suspendido 7 días';
      case 'suspend_30d':
        return 'Usuario suspendido 30 días';
      case 'ban_user':
        return 'Usuario baneado permanentemente';
      default:
        return action;
    }
  }
}