import 'package:flutter/material.dart';
import 'package:policode/widgets/admin_guard.dart';
import 'package:policode/utils/migrate_regulations.dart';
import 'package:policode/services/reglamento_service.dart';
import 'package:policode/widgets/loading_widgets.dart';

class MigrationScreen extends StatefulWidget {
  const MigrationScreen({super.key});

  @override
  State<MigrationScreen> createState() => _MigrationScreenState();
}

class _MigrationScreenState extends State<MigrationScreen> {
  final RegulationMigrator _migrator = RegulationMigrator();
  final ReglamentoService _reglamentoService = ReglamentoService();
  
  bool _isMigrated = false;
  int _regulationCount = 0;
  bool _isLoading = true;
  bool _isMigrating = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _checkMigrationStatus();
  }

  Future<void> _checkMigrationStatus() async {
    try {
      setState(() {
        _isLoading = true;
        _statusMessage = null;
      });

      final isMigrated = await _migrator.areRegulationsMigrated();
      final count = await _migrator.countRegulationsInFirebase();

      if (mounted) {
        setState(() {
          _isMigrated = isMigrated;
          _regulationCount = count;
          _isLoading = false;
          _statusMessage = isMigrated 
              ? 'Reglamentos ya migrados a Firebase' 
              : 'Reglamentos aún en assets locales';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = 'Error verificando estado: $e';
        });
      }
    }
  }

  Future<void> _performMigration() async {
    try {
      setState(() {
        _isMigrating = true;
        _statusMessage = 'Migrando reglamentos...';
      });

      await _migrator.migrateRegulationsToFirebase();
      
      // Limpiar caché del servicio para forzar recarga
      _reglamentoService.limpiarCache();
      
      await _checkMigrationStatus();

      if (mounted) {
        setState(() {
          _isMigrating = false;
          _statusMessage = 'Migración completada exitosamente';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reglamentos migrados a Firebase exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isMigrating = false;
          _statusMessage = 'Error durante migración: $e';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error migrando: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _testFirebaseConnection() async {
    try {
      setState(() {
        _statusMessage = 'Probando conexión con Firebase...';
      });

      final count = await _migrator.countRegulationsInFirebase();
      
      if (mounted) {
        setState(() {
          _statusMessage = 'Conexión exitosa. $count reglamentos en Firebase';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Conexión exitosa: $count reglamentos encontrados'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Error de conexión: $e';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error de conexión: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AdminGuard(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Migración de Reglamentos'),
          centerTitle: true,
        ),
        body: _isLoading
            ? const LoadingWidget()
            : Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatusCard(theme),
                    const SizedBox(height: 24),
                    _buildInfoCard(theme),
                    const SizedBox(height: 24),
                    _buildActionsCard(theme),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildStatusCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _isMigrated ? Icons.cloud_done : Icons.cloud_off,
                  color: _isMigrated ? Colors.green : Colors.orange,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Estado de Migración',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _statusMessage ?? 'Verificando...',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildStatChip(
                  'Estado',
                  _isMigrated ? 'Migrado' : 'Local',
                  _isMigrated ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 12),
                _buildStatChip(
                  'Reglamentos',
                  _regulationCount.toString(),
                  Colors.blue,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
            ),
          ),
        ],
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
              'Información',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '• Los reglamentos se migran desde assets/data/reglamento.json a Firebase\n'
              '• La migración se ejecuta automáticamente en el primer uso\n'
              '• Una vez migrados, la app usará Firebase como fuente principal\n'
              '• Los administradores pueden gestionar reglamentos desde el panel admin',
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
              'Acciones',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isMigrating ? null : _testFirebaseConnection,
                icon: const Icon(Icons.wifi_find),
                label: const Text('Probar Conexión Firebase'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (!_isMigrated) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isMigrating ? null : _performMigration,
                  icon: _isMigrating 
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_upload),
                  label: Text(_isMigrating ? 'Migrando...' : 'Migrar a Firebase'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _checkMigrationStatus,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Actualizar Estado'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}