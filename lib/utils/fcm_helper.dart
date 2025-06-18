import 'package:flutter/foundation.dart';
import '../services/push_notification_service.dart';

/// Utilidades para FCM en desarrollo
class FCMHelper {
  
  /// Imprimir el token FCM actual en la consola (solo en debug)
  static void printFCMToken() {
    if (kDebugMode) {
      final pushService = PushNotificationService();
      final token = pushService.fcmToken;
      
      if (token != null) {
        print('\n' + '='*50);
        print('🔔 FCM TOKEN:');
        print('='*50);
        print(token);
        print('='*50);
        print('Status: ${pushService.isInitialized ? "✅ Inicializado" : "❌ No inicializado"}');
        print('='*50 + '\n');
      } else {
        print('\n❌ FCM Token no disponible\n');
      }
    }
  }
  
  /// Obtener el token FCM como string
  static String? getFCMToken() {
    final pushService = PushNotificationService();
    return pushService.fcmToken;
  }
  
  /// Verificar si el servicio está inicializado
  static bool isInitialized() {
    final pushService = PushNotificationService();
    return pushService.isInitialized;
  }
}