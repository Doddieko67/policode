# 🔔 Configurar OneSignal para Notificaciones Push

OneSignal es una alternativa gratuita y fácil de usar para Cloud Functions.

## 📱 **Paso 1: Crear cuenta en OneSignal**

1. Ve a [https://onesignal.com/](https://onesignal.com/)
2. Crea una cuenta gratuita
3. Crea una nueva app:
   - **Name**: PoliCode
   - **Platform**: Android

## 🔧 **Paso 2: Configurar Android**

En OneSignal Dashboard:
1. **Settings** → **Keys & IDs**
2. Copia el **App ID**
3. En **Google Android (FCM)**: 
   - Sube tu archivo `google-services.json`
   - O agrega manualmente el **Server Key** desde Firebase Console

## 📦 **Paso 3: Agregar dependencia a Flutter**

Agrega a `pubspec.yaml`:
```yaml
dependencies:
  onesignal_flutter: ^5.2.5
```

## 🛠️ **Paso 4: Código Flutter**

Reemplaza el `PushNotificationService` con OneSignal:

```dart
// lib/services/onesignal_service.dart
import 'package:onesignal_flutter/onesignal_flutter.dart';

class OneSignalService {
  static const String appId = "TU_APP_ID_AQUI";
  
  static Future<void> initialize() async {
    OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
    
    OneSignal.initialize(appId);
    
    // Solicitar permisos
    OneSignal.Notifications.requestPermission(true);
    
    // Listeners
    OneSignal.Notifications.addForegroundWillDisplayListener(_onForegroundWillDisplay);
    OneSignal.Notifications.addClickListener(_onNotificationOpened);
  }
  
  static void _onForegroundWillDisplay(OSNotificationWillDisplayEvent event) {
    event.notification.display();
  }
  
  static void _onNotificationOpened(OSNotificationClickEvent result) {
    // Manejar navegación
    print('Notification opened: ${result.notification.additionalData}');
  }
  
  static Future<void> sendNotification({
    required String userId,
    required String title,
    required String message,
    Map<String, dynamic>? data,
  }) async {
    // Enviar via OneSignal REST API
    // (implementar llamada HTTP)
  }
}
```

## 🎯 **Ventajas de OneSignal:**

- ✅ **Gratuito** hasta 10,000 usuarios
- ✅ **Sin configuración de IAM**
- ✅ **Dashboard web** para enviar notificaciones
- ✅ **Estadísticas incluidas**
- ✅ **Soporte para segmentación**
- ✅ **API REST simple**

## 🔄 **Paso 5: Actualizar ForumService**

```dart
// En lugar de PushNotificationService
await OneSignalService.sendNotification(
  userId: postAuthorId,
  title: 'Nueva respuesta',
  message: '${reply.autorNombre} respondió a tu post',
  data: {'postId': reply.postId},
);
```

## 🧪 **Paso 6: Probar**

1. Instala la app
2. Ve al Dashboard de OneSignal
3. **Messages** → **New Push**
4. Envía una notificación de prueba

## 📊 **Resultado:**

Tendrás notificaciones push funcionando sin necesidad de:
- Cloud Functions
- Permisos especiales de Firebase
- Configuración compleja de IAM

¿Quieres que implemente OneSignal en lugar de Cloud Functions?