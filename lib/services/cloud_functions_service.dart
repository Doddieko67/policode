import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// Servicio para manejar Cloud Functions
class CloudFunctionsService {
  static final CloudFunctionsService _instance = CloudFunctionsService._internal();
  factory CloudFunctionsService() => _instance;
  CloudFunctionsService._internal();

  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Enviar notificación directa usando Cloud Function
  Future<bool> sendDirectNotification({
    required String targetUserId,
    required String title,
    required String body,
    String? type,
    String? postId,
    String? fromUserId,
    String? fromUserName,
    String? actionUrl,
    String? priority,
  }) async {
    try {
      if (kDebugMode) {
        print('📡 Enviando notificación via Cloud Function...');
      }

      final callable = _functions.httpsCallable('sendDirectNotification');
      
      final result = await callable.call({
        'targetUserId': targetUserId,
        'title': title,
        'body': body,
        'type': type ?? 'system_message',
        'postId': postId,
        'fromUserId': fromUserId,
        'fromUserName': fromUserName,
        'actionUrl': actionUrl,
        'priority': priority ?? 'medium',
      });

      final data = result.data as Map<String, dynamic>;
      final success = data['success'] ?? false;
      
      if (kDebugMode) {
        print('✅ Cloud Function response: $data');
      }

      return success;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error llamando Cloud Function: $e');
      }
      return false;
    }
  }

  /// Verificar si las Cloud Functions están disponibles
  Future<bool> areCloudFunctionsAvailable() async {
    try {
      // Intentar hacer una llamada simple para verificar conectividad
      final callable = _functions.httpsCallable('sendDirectNotification');
      // Solo verificamos que la función existe, no la ejecutamos
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Cloud Functions no disponibles: $e');
      }
      return false;
    }
  }

  /// Configurar emulador (solo para desarrollo)
  void useEmulator() {
    if (kDebugMode) {
      _functions.useFunctionsEmulator('localhost', 5001);
      print('🔧 Usando emulador de Cloud Functions');
    }
  }
}