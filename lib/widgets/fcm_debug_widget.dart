import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/push_notification_service.dart';

/// Widget de debug para mostrar el token FCM (solo en modo debug)
class FCMDebugWidget extends StatelessWidget {
  const FCMDebugWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // Solo mostrar en modo debug
    assert(() {
      return true;
    }());

    final pushService = PushNotificationService();
    final token = pushService.fcmToken;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber[50],
        border: Border.all(color: Colors.amber),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.bug_report, color: Colors.amber, size: 16),
              const SizedBox(width: 8),
              const Text(
                'FCM Token (Debug):',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (token != null)
                IconButton(
                  icon: const Icon(Icons.copy, size: 16),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: token));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Token FCM copiado')),
                    );
                  },
                  tooltip: 'Copiar token',
                ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(
            token ?? 'Token no disponible - asegúrate de haber iniciado sesión',
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 10,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Status: ${pushService.isInitialized ? "Inicializado" : "No inicializado"}',
            style: TextStyle(
              fontSize: 10,
              color: pushService.isInitialized ? Colors.green : Colors.red,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}