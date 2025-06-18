import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/notification_model.dart';
import 'notification_service.dart';

/// Servicio para manejar notificaciones push y locales
class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final NotificationService _notificationService = NotificationService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isInitialized = false;
  String? _fcmToken;

  /// Inicializar el servicio de notificaciones
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Solicitar permisos para notificaciones
      await _requestPermissions();

      // Configurar notificaciones locales
      await _initializeLocalNotifications();

      // Configurar Firebase Messaging
      await _configureFCM();

      // Obtener y guardar el token FCM
      await _getFCMToken();

      _isInitialized = true;
      if (kDebugMode) {
        print('PushNotificationService inicializado correctamente');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error inicializando PushNotificationService: $e');
      }
    }
  }

  /// Solicitar permisos para notificaciones
  Future<void> _requestPermissions() async {
    final settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      announcement: false,
    );

    if (kDebugMode) {
      print('Permisos de notificación: ${settings.authorizationStatus}');
    }
  }

  /// Configurar notificaciones locales
  Future<void> _initializeLocalNotifications() async {
    const androidInitializationSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const iosInitializationSettings = DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );

    const initializationSettings = InitializationSettings(
      android: androidInitializationSettings,
      iOS: iosInitializationSettings,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Crear canal de notificaciones para Android
    await _createNotificationChannels();
  }

  /// Crear canales de notificaciones para Android
  Future<void> _createNotificationChannels() async {
    const androidChannel = AndroidNotificationChannel(
      'policode_channel',
      'PoliCode Notifications',
      description: 'Notificaciones de la aplicación PoliCode',
      importance: Importance.high,
      playSound: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  /// Configurar Firebase Cloud Messaging
  Future<void> _configureFCM() async {
    // Manejar mensajes cuando la app está en primer plano
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Manejar cuando se abre la app desde una notificación
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTapped);

    // Manejar mensajes en segundo plano
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Verificar si la app se abrió desde una notificación
    final initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTapped(initialMessage);
    }
  }

  /// Obtener y guardar el token FCM
  Future<void> _getFCMToken() async {
    try {
      final token = await _firebaseMessaging.getToken();
      if (token != null) {
        _fcmToken = token;
        await _saveTokenToFirestore(token);
        
        if (kDebugMode) {
          print('✅ FCM Token obtenido: ${token.substring(0, 20)}...');
        }
      }

      // Escuchar cambios en el token
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        _saveTokenToFirestore(newToken);
        if (kDebugMode) {
          print('🔄 FCM Token actualizado: ${newToken.substring(0, 20)}...');
        }
      });
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error obteniendo FCM token: $e');
      }
    }
  }

  /// Forzar la obtención de un nuevo token (útil para debug)
  Future<String?> refreshToken() async {
    try {
      await _firebaseMessaging.deleteToken();
      final newToken = await _firebaseMessaging.getToken();
      if (newToken != null) {
        _fcmToken = newToken;
        await _saveTokenToFirestore(newToken);
        if (kDebugMode) {
          print('🆕 Nuevo FCM Token: ${newToken.substring(0, 20)}...');
        }
      }
      return newToken;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error refrescando FCM token: $e');
      }
      return null;
    }
  }

  /// Guardar token FCM en Firestore
  Future<void> _saveTokenToFirestore(String token) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'fcmTokens': FieldValue.arrayUnion([token]),
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error guardando FCM token: $e');
      }
    }
  }

  /// Manejar mensaje cuando la app está en primer plano
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    if (kDebugMode) {
      print('Mensaje recibido en primer plano: ${message.data}');
    }

    // Solo mostrar notificación local para que el usuario la vea
    // NO guardar en base de datos aquí porque ya se hace desde ForumService
    await _showLocalNotification(message);
  }

  /// Mostrar notificación local
  Future<void> _showLocalNotification(RemoteMessage message) async {
    const androidDetails = AndroidNotificationDetails(
      'policode_channel',
      'PoliCode Notifications',
      channelDescription: 'Notificaciones de la aplicación PoliCode',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? 'PoliCode',
      message.notification?.body ?? '',
      notificationDetails,
      payload: jsonEncode(message.data),
    );
  }


  /// Manejar cuando se toca una notificación
  void _handleNotificationTapped(RemoteMessage message) {
    if (kDebugMode) {
      print('Notificación tocada: ${message.data}');
    }
    
    // Aquí puedes agregar lógica de navegación basada en los datos del mensaje
    _navigateFromNotification(message.data);
  }

  /// Manejar cuando se toca una notificación local
  void _onNotificationTapped(NotificationResponse response) {
    if (response.payload != null) {
      try {
        final data = jsonDecode(response.payload!) as Map<String, dynamic>;
        _navigateFromNotification(data);
      } catch (e) {
        if (kDebugMode) {
          print('Error procesando payload de notificación: $e');
        }
      }
    }
  }

  /// Navegar basado en los datos de la notificación
  void _navigateFromNotification(Map<String, dynamic> data) {
    // Esta lógica se puede expandir según los tipos de notificación
    final type = data['type'];
    final postId = data['postId'];
    
    if (type != null && postId != null) {
      // Aquí puedes usar un NavigatorKey global para navegar
      // Por ahora solo imprimimos para debug
      if (kDebugMode) {
        print('Debería navegar a: tipo=$type, postId=$postId');
      }
    }
  }

  /// Enviar solo notificación push (sin guardar en BD)
  Future<void> sendPushOnly({
    required String userId,
    required String title,
    required String body,
    required Map<String, String> data,
  }) async {
    try {
      // Obtener tokens FCM del usuario
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final fcmTokens = List<String>.from(userDoc.data()?['fcmTokens'] ?? []);

      if (fcmTokens.isEmpty) {
        if (kDebugMode) {
          print('Usuario $userId no tiene tokens FCM');
        }
        return;
      }

      // En una implementación real, aquí enviarías la notificación
      // usando el servidor de tu backend o Cloud Functions
      if (kDebugMode) {
        print('📱 Enviando SOLO push a $userId: $title');
        print('Tokens: ${fcmTokens.length} dispositivos');
      }

      // TODO: Aquí se enviaría la notificación real usando:
      // - Cloud Functions de Firebase
      // - Tu propio backend
      // - Firebase Admin SDK
      
    } catch (e) {
      if (kDebugMode) {
        print('Error enviando notificación push: $e');
      }
    }
  }

  /// Enviar notificación completa (push + base de datos)
  Future<void> sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    required Map<String, String> data,
  }) async {
    try {
      // Enviar push
      await sendPushOnly(
        userId: userId,
        title: title,
        body: body,
        data: data,
      );

      // Crear la notificación en la base de datos
      final notification = NotificationModel(
        id: '',
        userId: userId,
        type: NotificationType.fromString(data['type'] ?? 'system_message'),
        title: title,
        message: body,
        priority: NotificationPriority.fromString(data['priority'] ?? 'medium'),
        isRead: false,
        createdAt: DateTime.now(),
        postId: data['postId'],
        replyId: data['replyId'],
        fromUserId: data['fromUserId'],
        fromUserName: data['fromUserName'],
        actionUrl: data['actionUrl'],
        metadata: data.cast<String, dynamic>(),
      );

      await _notificationService.createNotification(notification);
    } catch (e) {
      if (kDebugMode) {
        print('Error enviando notificación completa: $e');
      }
    }
  }

  /// Limpiar token FCM al cerrar sesión
  Future<void> clearTokens() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'fcmTokens': FieldValue.delete(),
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error limpiando tokens FCM: $e');
      }
    }
  }

  /// Getter para el token actual
  String? get fcmToken => _fcmToken;

  /// Verificar si está inicializado
  bool get isInitialized => _isInitialized;
}

/// Handler para mensajes en segundo plano (debe ser función top-level)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kDebugMode) {
    print('Mensaje en segundo plano: ${message.data}');
  }
  
  // Aquí puedes procesar el mensaje en segundo plano
  // No puedes mostrar UI desde aquí, pero puedes actualizar datos
}