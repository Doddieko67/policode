import 'package:flutter/material.dart';
import 'package:policode/services/migration_service.dart';
import 'package:policode/widgets/loading_widgets.dart';
import 'package:policode/widgets/custom_button.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final MigrationService _migrationService = MigrationService();
  
  bool _isLoading = false;
  Map<String, dynamic>? _migrationStatus;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _loadMigrationStatus();
  }

  Future<void> _loadMigrationStatus() async {
    setState(() => _isLoading = true);
    
    try {
      final status = await _migrationService.getMigrationStatus();
      setState(() {
        _migrationStatus = status;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error cargando estado: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Administración'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: LoadingWidget())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatusCard(),
                  const SizedBox(height: 24),
                  _buildMigrationActions(),
                  const SizedBox(height: 24),
                  _buildDataActions(),
                  if (_statusMessage != null) ...[
                    const SizedBox(height: 24),
                    _buildStatusMessage(),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildStatusCard() {
    final theme = Theme.of(context);
    final hasData = _migrationStatus != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  hasData ? Icons.check_circle : Icons.warning,
                  color: hasData ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  'Estado de la Base de Datos',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (hasData) ...[
              _buildStatusRow('Total de artículos', '${_migrationStatus!['total_articulos']}'),
              _buildStatusRow('Estado', _migrationStatus!['estado'] ?? 'Desconocido'),
              _buildStatusRow('Versión', _migrationStatus!['version_reglamento'] ?? 'N/A'),
              if (_migrationStatus!['fecha_migracion'] != null)
                _buildStatusRow(
                  'Fecha de migración', 
                  _formatTimestamp(_migrationStatus!['fecha_migracion']),
                ),
            ] else ...[
              Text(
                'No se han encontrado datos migrados en Firebase.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Usa las opciones de abajo para migrar el reglamento desde el archivo JSON.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, String value) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMigrationActions() {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Migración de Datos',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Migra el reglamento desde el archivo JSON local a Firebase.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: CustomButton(
                    text: 'Migrar Reglamento',
                    onPressed: _migrationStatus == null ? _migrateReglamento : null,
                    icon: Icons.upload,
                    type: ButtonType.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CustomButton(
                    text: 'Crear Artículos',
                    onPressed: _createSampleArticles,
                    icon: Icons.article,
                    type: ButtonType.secondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataActions() {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gestión de Datos',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '⚠️ Estas acciones son irreversibles. Úsalas con cuidado.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: CustomButton.danger(
                    text: 'Limpiar Datos',
                    onPressed: _migrationStatus != null ? _showClearDataDialog : null,
                    icon: Icons.delete_forever,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CustomButton(
                    text: 'Actualizar Estado',
                    onPressed: _loadMigrationStatus,
                    icon: Icons.refresh,
                    type: ButtonType.secondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusMessage() {
    final theme = Theme.of(context);
    final isError = _statusMessage!.toLowerCase().contains('error');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isError 
            ? theme.colorScheme.errorContainer 
            : theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _statusMessage!,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: isError 
              ? theme.colorScheme.onErrorContainer 
              : theme.colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }

  Future<void> _migrateReglamento() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Iniciando migración del reglamento...';
    });

    try {
      final success = await _migrationService.migrateReglamentoToFirebase();
      
      setState(() {
        _isLoading = false;
        _statusMessage = success
            ? '✅ Migración completada exitosamente!'
            : '❌ Error en la migración. Revisa la consola para más detalles.';
      });

      if (success) {
        await _loadMigrationStatus();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = '❌ Error en la migración: $e';
      });
    }
  }

  Future<void> _createSampleArticles() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Creando artículos de ejemplo...';
    });

    try {
      final success = await _migrationService.createSampleArticles();
      
      setState(() {
        _isLoading = false;
        _statusMessage = success
            ? '✅ Artículos de ejemplo creados exitosamente!'
            : '❌ Error creando artículos de ejemplo.';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = '❌ Error creando artículos: $e';
      });
    }
  }

  void _showClearDataDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Confirmar Eliminación'),
        content: const Text(
          'Esta acción eliminará TODOS los datos del reglamento en Firebase. '
          'Esta operación no se puede deshacer.\n\n'
          '¿Estás seguro de que quieres continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          CustomButton.danger(
            text: 'Eliminar Todo',
            onPressed: () {
              Navigator.pop(context);
              _clearData();
            },
            size: ButtonSize.small,
          ),
        ],
      ),
    );
  }

  Future<void> _clearData() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Eliminando datos...';
    });

    try {
      final success = await _migrationService.clearReglamentoData();
      
      setState(() {
        _isLoading = false;
        _statusMessage = success
            ? '✅ Datos eliminados exitosamente!'
            : '❌ Error eliminando datos.';
      });

      if (success) {
        await _loadMigrationStatus();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = '❌ Error eliminando datos: $e';
      });
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    try {
      if (timestamp == null) return 'N/A';
      
      // Asumiendo que es un Timestamp de Firestore
      final date = timestamp.toDate() as DateTime;
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Formato inválido';
    }
  }
}