import 'package:flutter/material.dart';
import 'package:policode/services/admin_service.dart';
import 'package:policode/widgets/loading_widgets.dart';

class AdminGuard extends StatefulWidget {
  final Widget child;

  const AdminGuard({
    super.key,
    required this.child,
  });

  @override
  State<AdminGuard> createState() => _AdminGuardState();
}

class _AdminGuardState extends State<AdminGuard> {
  final AdminService _adminService = AdminService();
  bool _isLoading = true;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAdminAccess();
  }

  Future<void> _checkAdminAccess() async {
    try {
      final isAdmin = await _adminService.isCurrentUserAdmin();
      if (mounted) {
        setState(() {
          _isAdmin = isAdmin;
          _isLoading = false;
        });

        if (!isAdmin) {
          _showAccessDeniedDialog();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showAccessDeniedDialog();
      }
    }
  }

  void _showAccessDeniedDialog() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.block, color: Colors.red, size: 28),
              SizedBox(width: 8),
              Text('Acceso Denegado'),
            ],
          ),
          content: const Text(
            'No tienes permisos para acceder a esta sección. Solo los administradores pueden ver esta página.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              child: const Text('Volver'),
            ),
          ],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: LoadingWidget(),
        ),
      );
    }

    if (!_isAdmin) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock,
                size: 64,
                color: Colors.grey,
              ),
              SizedBox(height: 16),
              Text(
                'Sin acceso',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return widget.child;
  }
}