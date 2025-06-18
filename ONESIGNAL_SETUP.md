# 🔔 Configuración de OneSignal para PoliCode

## 📋 Pasos para Configurar OneSignal

### 1. Crear Cuenta y App en OneSignal

1. **Crear cuenta**: Ve a [OneSignal.com](https://onesignal.com) y crea una cuenta gratuita
2. **Crear nueva app**: 
   - Click en "New App/Website"
   - Nombre: "PoliCode"
   - Selecciona "Mobile App"
3. **Configurar plataforma**:
   - Selecciona "Flutter"
   - Selecciona "Android" y/o "iOS" según necesites

### 2. Configuración Android

1. **En OneSignal Dashboard:**
   - Ve a Settings > Platforms
   - Click en "Google Android (FCM)"
   - Necesitarás el archivo `google-services.json` de tu proyecto Firebase

2. **Obtener Server Key de Firebase:**
   - Ve a Firebase Console > Project Settings
   - Tab "Cloud Messaging" 
   - Copia el "Server key" (Legacy)
   - Pégalo en OneSignal

### 3. Obtener Credenciales de OneSignal

Después de configurar la app, ve a Settings:

- **App ID**: Cópialo de Settings > Keys & IDs
- **REST API Key**: También en Settings > Keys & IDs

### 4. Actualizar el Código

Edita `lib/services/onesignal_service.dart`:

```dart
// Reemplaza estas líneas:
static const String _appId = "TU_APP_ID_AQUI";
static const String _restApiKey = "TU_REST_API_KEY_AQUI";

// Por tus valores reales:
static const String _appId = "tu-app-id-real";
static const String _restApiKey = "tu-rest-api-key-real";
```

### 5. Configuración de Android (opcional pero recomendado)

Edita `android/app/src/main/AndroidManifest.xml`:

```xml
<!-- Agregar dentro de <application> -->
<meta-data android:name="onesignal_app_id" android:value="tu-app-id-real" />
<meta-data android:name="onesignal_google_project_number" android:value="tu-firebase-sender-id" />
```

### 6. Probar el Sistema

1. **Compilar la app**: `flutter build apk --debug`
2. **Instalar en dispositivo real** (no emulador para mejores resultados)
3. **Abrir la app y ir a Perfil**
4. **Presionar "Probar OneSignal"**
5. **Deberías recibir una notificación de prueba**

## 🔧 Solución de Problemas

### Problema: No recibo notificaciones

**Verificaciones:**
1. ✅ App ID y REST API Key correctos
2. ✅ Firebase configurado correctamente
3. ✅ Dispositivo real (no emulador)
4. ✅ Permisos de notificación otorgados
5. ✅ App ejecutándose en primer plano

### Problema: Error 400 en API

- Verifica que el REST API Key sea correcto
- Asegúrate de que el usuario tenga Player ID guardado
- Revisa los logs de OneSignal Dashboard

### Problema: Player ID null

- Espera unos segundos después del login
- Reinicia la app
- Verifica que OneSignal esté inicializado

## 📱 Características Implementadas

### ✅ Funcionalidades Actuales

1. **Inicialización automática** al arrancar la app
2. **Login/logout de usuarios** automático
3. **Notificaciones de likes** en posts
4. **Notificaciones de respuestas** en posts
5. **Botón de prueba** en configuración de perfil
6. **Respaldo con FCM** si OneSignal falla
7. **Player ID guardado** en Firestore
8. **Manejo de errores** completo

### 🔄 Integración con el Foro

El sistema está completamente integrado:

- **Al dar like**: Notificación al autor del post
- **Al responder**: Notificación al autor del post
- **Navegación**: Data incluye postId para navegar
- **Filtros**: No se envían notificaciones a uno mismo

## 🚀 Próximos Pasos (Opcionales)

1. **Segmentación**: Enviar notificaciones por categorías
2. **Programadas**: Notificaciones de recordatorios
3. **Rich Media**: Imágenes en notificaciones
4. **Deep Links**: Navegación directa a posts específicos
5. **Análiticas**: Estadísticas de engagement

## 📝 Notas Importantes

- **OneSignal es gratuito** hasta 10,000 usuarios
- **Mejor que FCM** para apps Flutter
- **Funciona offline** (las notificaciones llegan cuando se conecta)
- **Soporte multiplataforma** (Android + iOS)
- **Dashboard completo** para gestionar notificaciones

## 🔗 Enlaces Útiles

- [OneSignal Flutter Setup](https://documentation.onesignal.com/docs/flutter-sdk-setup)
- [OneSignal Dashboard](https://app.onesignal.com)
- [REST API Docs](https://documentation.onesignal.com/reference/create-notification)

---

**Estado**: ✅ Implementación completa - Solo falta configurar credenciales