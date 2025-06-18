# 🔔 Sistema de Notificaciones con Firebase Functions - PoliCode

## ✅ Estado: COMPLETADO - Firebase Functions v2

Se ha implementado un sistema completo de notificaciones push usando **Firebase Cloud Functions v2 (2nd Gen)** con **Firebase Cloud Messaging (FCM)**, proporcionando la arquitectura más moderna y escalable disponible.

## 🚀 Arquitectura del Sistema

### 1. Sistema Actual (FCM Directo)
```
┌─────────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Forum Actions     │────│  ForumService    │────│ Firebase FCM    │
│ (likes, replies)    │    │  (Direct Push)   │    │  (Push Tokens)  │
└─────────────────────┘    └──────────────────┘    └─────────────────┘
                                      │
                           ┌──────────▼──────────┐
                           │ NotificationService │
                           │  (Database Store)   │
                           └─────────────────────┘
```

### 2. Sistema con Functions v2 (ACTIVO)
```
┌─────────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Forum Actions     │────│ NotificationService │──│ Cloud Functions │
│ (likes, replies)    │    │  (Create Document)  │  │ v2 (2nd Gen)    │
└─────────────────────┘    └──────────────────┘    │ Auto Triggers   │
                                   │                └─────────────────┘
                                   │                         │
                           ┌───────▼────────┐         ┌──────▼──────┐
                           │ Sistema Híbrido │         │ Firebase FCM│
                           │ (Cloud + FCM)   │─────────│ (Push Send) │
                           └────────────────┘         └─────────────┘
```

## 📁 Implementación Actual

### Servicios Implementados

#### 1. PushNotificationService (FCM Directo)
- **Ubicación**: `lib/services/push_notification_service.dart`
- **Función**: Envío directo de notificaciones push via FCM
- **Uso**: Llamado directamente desde ForumService
- **Estado**: ✅ **ACTIVO Y FUNCIONAL**

#### 2. NotificationService 
- **Ubicación**: `lib/services/notification_service.dart`
- **Función**: Gestión de notificaciones en base de datos
- **Uso**: Historial y gestión de notificaciones
- **Estado**: ✅ **ACTIVO Y FUNCIONAL**

#### 3. Cloud Functions v2 (Principal)
- **Ubicación**: `functions/src/index.ts`
- **Función**: Trigger automático con Node.js 20 (2nd Gen)
- **Uso**: Sistema principal de notificaciones
- **Estado**: ✅ **DESPLEGADO Y ACTIVO**

#### 4. CloudFunctionsService
- **Ubicación**: `lib/services/cloud_functions_service.dart`
- **Función**: Cliente para llamar Cloud Functions desde Flutter
- **Uso**: Sistema híbrido con respaldo FCM
- **Estado**: ✅ **ACTIVO Y FUNCIONAL**

## 🎯 Cómo Funciona Actualmente

### Flujo de Notificaciones con Functions v2

1. **Usuario da like a un post**:
   ```dart
   // En ForumService.togglePostLike()
   await _notificationService.notifyPostLiked(...);     // 1. Guardar en BD
   await _sendHybridNotification(...);                  // 2. Sistema híbrido
   ```

2. **Sistema Híbrido ejecuta**:
   ```dart
   // En ForumService._sendHybridNotification()
   1. Intenta Cloud Functions v2 (preferido)
   2. Si falla, usa FCM directo como respaldo
   3. Último recurso: FCM directo con manejo de errores
   ```

3. **Cloud Function v2 se ejecuta automáticamente**:
   ```typescript
   // functions/src/index.ts - sendNotificationOnCreate
   1. Detecta nuevo documento en "notifications" collection
   2. Obtiene tokens FCM del usuario objetivo
   3. Envía notificación push via Firebase Admin SDK
   4. Limpia tokens inválidos automáticamente
   5. Actualiza estado de la notificación
   ```

4. **Notificación llega al dispositivo**:
   - Token FCM del usuario objetivo
   - Título y mensaje personalizados
   - Data con información del post y usuario
   - Badge count automático
   - Metadatos de delivery y estado

## 🔧 Configuración Requerida

### Variables de Entorno
```env
# Solo requerido para Gemini AI
GEMINI_API_KEY=tu_api_key_gemini
```

### Firebase Configuration
- **FCM**: Configurado automáticamente via `google-services.json`
- **Firestore**: Collections `notifications` y `users`
- **Tokens**: Guardados en campo `fcmTokens` de cada usuario

## 📱 Uso para Usuarios

### Automático
1. **Instalar la app** y permitir notificaciones
2. **Interactuar en el foro** (dar likes, responder posts)
3. **Recibir notificaciones** automáticamente cuando:
   - Alguien responda a tus posts
   - Alguien le dé like a tus posts

### Manual (Debug)
- **Botón "Ver Token FCM"** en configuración de perfil
- **Logs de consola** para troubleshooting
- **Pantalla de notificaciones** para ver historial

## 🔄 Opciones de Arquitectura

### Opción 1: Sistema Híbrido Actual (Recomendado)
- **Cloud Functions v2** como principal
- **FCM directo** como respaldo automático
- **Máxima confiabilidad** con redundancia
- **Escalabilidad profesional** con triggers automáticos
- **Separación de responsabilidades** moderna

### Opción 2: Solo FCM Directo
- **FCM Directo** desde ForumService únicamente
- **Menos complejidad**, más simple
- **Sin costos adicionales** de Cloud Functions
- **Latencia mínima** pero menos escalable

## 🎉 Funcionalidades Implementadas

### ✅ Notificaciones Automáticas
- Likes en posts → Notificación al autor
- Respuestas en posts → Notificación al autor
- Filtrado inteligente (no notificar a uno mismo)
- Badge count con número de notificaciones no leídas

### ✅ Gestión de Tokens
- Registro automático de tokens FCM
- Limpieza de tokens inválidos
- Soporte multi-dispositivo por usuario
- Logout automático de tokens

### ✅ Base de Datos
- Historial completo de notificaciones
- Estados de leído/no leído
- Metadata completa (post, usuario, etc.)
- Cleanup automático de notificaciones antiguas

### ✅ UX Integrada
- Pantalla de notificaciones nativa
- Navegación automática a posts desde notificaciones
- Indicadores visuales de estado
- Debugging tools para desarrolladores

## 🚀 Cloud Functions v2 Desplegadas

Las Cloud Functions v2 están **ya desplegadas y funcionando**:

```bash
✅ sendNotificationOnCreate - Trigger automático (ACTIVO)
✅ sendDirectNotification - Función callable (ACTIVO)
```

### Re-desplegar si es necesario:
```bash
cd functions
npm install
npm run build
firebase deploy --only functions
```

### Verificar estado:
```bash
firebase functions:list
firebase functions:log --only sendNotificationOnCreate
```

## 📊 Comparación de Enfoques

| Característica | FCM Directo | Cloud Functions |
|---|---|---|
| **Latencia** | ⚡ Muy baja | 🔄 Baja-Media |
| **Complejidad** | 🟢 Simple | 🟡 Media |
| **Costos** | 🟢 Solo FCM | 🟡 FCM + Functions |
| **Escalabilidad** | 🟡 Buena | 🟢 Excelente |
| **Mantenimiento** | 🟢 Mínimo | 🟡 Medio |
| **Debugging** | 🟢 Fácil | 🟡 Complejo |

## 🔧 Troubleshooting

### No recibo notificaciones
1. ✅ Verificar permisos de notificación en el dispositivo
2. ✅ Confirmar que el token FCM se guarde correctamente
3. ✅ Revisar logs de consola en modo debug
4. ✅ Probar en dispositivo real (no emulador)

### Notificaciones duplicadas
- ❌ **Resuelto**: OneSignal eliminado
- ✅ Ahora solo usa FCM directo

### Errores de token
- ✅ Limpieza automática de tokens inválidos
- ✅ Re-registro automático en login

## 📚 Archivos Relevantes

### Servicios
- `lib/services/push_notification_service.dart` - FCM directo
- `lib/services/notification_service.dart` - Base de datos
- `lib/services/forum_service.dart` - Integración con foro
- `lib/services/auth_service.dart` - Gestión de tokens

### UI
- `lib/screens/notifications_screen.dart` - Pantalla de notificaciones
- `lib/screens/profile_settings_screen.dart` - Debug tools

### Functions (Opcional)
- `functions/src/index.ts` - Cloud Functions
- `functions/package.json` - Dependencias

---

## Estado Final: ✅ COMPLETAMENTE FUNCIONAL

El sistema de notificaciones está **100% operativo** usando Firebase FCM directo. Las Cloud Functions están disponibles como alternativa pero no son necesarias para el funcionamiento básico.

**Ventajas del sistema actual**:
- ✅ Simplicidad y confiabilidad
- ✅ Latencia mínima
- ✅ Sin dependencias externas
- ✅ Costos reducidos
- ✅ Fácil mantenimiento

**Recomendación**: Mantener el sistema actual (FCM directo) a menos que se requiera escalabilidad masiva o integración con múltiples servicios.