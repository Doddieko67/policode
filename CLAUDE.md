# CLAUDE.md - Contexto del Proyecto PoliCode

## Información General del Proyecto
- **Nombre**: PoliCode
- **Tipo**: Aplicación Flutter para la comunidad del IPN
- **Propósito**: Asistente del Reglamento Estudiantil con foro comunitario y chat IA
- **Backend**: Firebase (Firestore, Storage, Auth)
- **IA**: Flutter Gemini para chatbot

## Estructura del Proyecto

### Pantallas Principales
- `auth_screen.dart` - Autenticación con Google
- `home_screen.dart` - Dashboard principal
- `chat_screen.dart` - Chat con IA especializada en reglamento
- `forum_screen.dart` - Foro de la comunidad
- `forum_post_detail_screen.dart` - Detalles de posts
- `create_post_screen.dart` - Crear posts
- `edit_post_screen.dart` - Editar posts
- `edit_reply_screen.dart` - **NUEVA** Editar respuestas con multimedia
- `mis_posts_screen.dart` - **NUEVA** Posts y respuestas del usuario
- `reglamentos_screen.dart` - Consulta de reglamentos
- `notas_screen.dart` - Sistema de notas

### Pantallas de Administración (NUEVAS)
- `admin/admin_dashboard_screen.dart` - Panel principal de administración
- `admin/reports_management_screen.dart` - Gestión de reportes
- `admin/regulations_management_screen.dart` - Gestión de reglamentos

### Servicios Principales
- `forum_service.dart` - **ACTUALIZADO** con métodos para IA y notificaciones
- `media_service.dart` - **ACTUALIZADO** con métodos multimedia
- `chatbot_service.dart` - **ACTUALIZADO** con contexto de posts
- `flutter_gemini_service.dart` - **ACTUALIZADO** con prompts combinados
- `auth_service.dart` - **ACTUALIZADO** con soporte para roles y OneSignal
- `admin_service.dart` - **NUEVO** Gestión de administración
- `reglamento_service.dart` - Gestión del reglamento
- `push_notification_service.dart` - **NUEVO** FCM como respaldo
- `onesignal_service.dart` - **NUEVO** Servicio principal de notificaciones
- `notification_service.dart` - Gestión de notificaciones en BD

### Widgets Principales
- `forum_widgets.dart` - **ACTUALIZADO** con botón de reporte
- `media_widgets.dart` - Componentes multimedia interactivos
- `chat_components.dart` - **ACTUALIZADO** con posts relacionados
- `related_posts_widget.dart` - **NUEVO** Cards de posts relacionados
- `admin_guard.dart` - **NUEVO** Protección de rutas admin
- `custom_cards.dart` - Cards reutilizables
- `loading_widgets.dart` - Estados de carga

## Últimas Funcionalidades Implementadas

### 7. Sistema de Notificaciones Push con Firebase
**Estado**: ✅ COMPLETADO - ÚLTIMA IMPLEMENTACIÓN
- **Servicios implementados**:
  - `PushNotificationService` - FCM directo (principal)
  - `NotificationService` - Gestión en base de datos
  - `Cloud Functions` - Trigger automático (opcional)
- **Integración completa**:
  - Notificaciones automáticas en likes de posts
  - Notificaciones automáticas en respuestas a posts
  - Sistema directo (ForumService → FCM)
  - Historial completo en Firestore
- **Gestión avanzada**:
  - Tokens FCM multi-dispositivo
  - Limpieza automática de tokens inválidos
  - Badge count con notificaciones no leídas
  - Navegación automática desde notificaciones
- **UX integrada**:
  - Pantalla de notificaciones nativa
  - Botón debug para ver token FCM
  - Logs detallados para troubleshooting
  - Sin dependencias externas

### 6. Panel de Administración Completo
**Estado**: ✅ COMPLETADO - ÚLTIMA IMPLEMENTACIÓN
- **Modelos nuevos**:
  - `user_model.dart` - Usuarios con roles y estados
  - `report_model.dart` - Sistema de reportes
- **AdminService**: Gestión completa de moderación
  - Suspender/banear usuarios
  - Eliminar contenido reportado
  - Subir y gestionar reglamentos
  - Estadísticas del sistema
- **Pantallas de admin** con protección AdminGuard
- **Botón de reporte** en posts y respuestas
- **Acceso diferenciado**: Solo admins ven el botón Admin

### 1. Multimedia Completa en Respuestas del Foro
**Estado**: ✅ COMPLETADO
- Las respuestas ahora soportan imágenes, videos y documentos
- Cambio de `MediaPreview` (miniaturas) a `AttachmentsList` (completo)
- Funcionalidad idéntica a posts principales
- Galería de imágenes con zoom
- Reproductores de video con controles
- Descarga de documentos

### 2. Pantalla de Edición de Respuestas
**Estado**: ✅ COMPLETADO
- `edit_reply_screen.dart` - Pantalla completa para editar respuestas
- Similar a `create_post_screen.dart` en funcionalidad
- Gestión completa de archivos multimedia:
  - Ver archivos existentes
  - Eliminar archivos
  - Agregar nuevos archivos
- Navegación desde `forum_post_detail_screen.dart`

### 3. Eliminación de Chat Privado
**Estado**: ✅ COMPLETADO
- Eliminados archivos:
  - `private_chat_screen.dart`
  - `chats_list_screen.dart`
  - `private_chat_service.dart`
  - `private_chat_model.dart`
- Reemplazado botón "Chats" por "Mis posts" en `home_screen.dart`

### 4. Pantalla "Mis Posts"
**Estado**: ✅ COMPLETADO
- `mis_posts_screen.dart` - Muestra posts y respuestas del usuario
- Dos pestañas: "Mis Posts" y "Mis Respuestas"
- Navegación desde respuestas al post original
- Refresh y like functionality
- Ruta agregada en `main.dart`: `/mis-posts`

### 5. IA con Contexto de Posts del Foro
**Estado**: ✅ COMPLETADO - ÚLTIMA IMPLEMENTACIÓN
- **ForumService actualizado** con métodos para IA:
  - `searchPostsForAI()` - Búsqueda inteligente de posts
  - `generarContextoPostsParaIA()` - Contexto para Gemini
  - Scoring por relevancia en título, contenido, tags
- **FlutterGeminiService actualizado**:
  - `askAboutReglamentoAndForum()` - Método combinado
  - `_buildCombinedPrompt()` - Prompt que prioriza reglamento
- **ChatbotService actualizado**:
  - Integra contexto de reglamento + foro
  - Retorna posts relacionados en metadata
- **RelatedPostsWidget**: Cards detallados de posts relacionados
- **ChatBubble actualizado**: Muestra posts relacionados junto a artículos

## Comandos de Desarrollo

### Compilación
```bash
flutter build apk --debug  # Para testing
flutter build apk --release  # Para producción
```

### Análisis
```bash
flutter analyze  # Verificar errores
```

### Testing
- Los logs están habilitados en `forum_service.dart` para debug
- Quitar logs cuando sea necesario

## Estado Actual del Proyecto

### ✅ Funcionalidades Completadas
1. **Foro completo** con multimedia en posts y respuestas
2. **Sistema de edición** avanzado para posts y respuestas
3. **Chat IA** con contexto de reglamento Y posts del foro
4. **Cards de posts relacionados** en respuestas de IA
5. **Navegación fluida** entre chat → foro → posts específicos
6. **Pantalla "Mis Posts"** con navegación a discusiones
7. **Panel de Administración** completo con:
   - Dashboard con estadísticas
   - Gestión de reportes y moderación
   - Subida y edición de reglamentos
   - Acciones de suspensión/baneo
   - Protección con AdminGuard
8. **Sistema de Notificaciones Push** completo con:
   - Firebase Cloud Messaging (FCM) como servicio principal
   - Cloud Functions como alternativa opcional
   - Notificaciones automáticas en likes y respuestas
   - Gestión automática de tokens FCM
   - Historial completo en base de datos
   - Sistema de limpieza de tokens inválidos

### 🔄 En Progreso
- Ninguna tarea pendiente específica

### 📋 Posibles Mejoras Futuras
1. Sistema de moderación avanzado
2. Búsqueda avanzada en el foro
3. Estadísticas de usuario
4. Modo offline
5. Notificaciones programadas
6. Segmentación de notificaciones por categorías

## Configuración Importante

### Firebase
- Configurado en `firebase_options.dart`
- Collections principales:
  - `forum_posts` - Posts del foro
  - `forum_replies` - Respuestas
  - `forum_likes` - Likes de posts
  - `forum_reply_likes` - Likes de respuestas
  - `users` - Usuarios con roles y permisos
  - `reports` - Reportes de contenido
  - `regulations` - Reglamentos del sistema
  - `admin_logs` - Logs de acciones administrativas

### Gemini IA
- Configurado en `main.dart`
- API Key en `.env`
- Modelo: `gemini-2.0-flash`
- Contexto combinado: reglamento + posts

### Notificaciones Push
- **Firebase FCM**: Servicio principal
- **Cloud Functions**: Triggers automáticos (opcional)
- **Configuración**: Automática via `google-services.json`
- **Collections**: 
  - `notifications` - Historial completo
  - `users` - Tokens FCM en campo `fcmTokens`
- **Documentación**: Ver `FIREBASE_FUNCTIONS_NOTIFICATIONS.md`

### Rutas Principales
```dart
'/': AppInitializer
'/home': HomeScreen
'/chat': ChatScreen
'/forum': ForumScreen
'/create-post': CreatePostScreen
'/mis-posts': MisPostsScreen
'/reglamentos': ReglamentosScreen
'/notas': NotasScreen
// Rutas admin (protegidas)
'/admin': AdminDashboardScreen
'/admin/reports': ReportsManagementScreen
'/admin/regulations': RegulationsManagementScreen
```

## Notas de Desarrollo

### Últimos Cambios Importantes
1. **Multimedia**: Cambiado `MediaPreview` → `AttachmentsList` en respuestas
2. **Navegación**: "Mis respuestas" ahora llevan al post específico
3. **IA**: Combina reglamento oficial + discusiones comunitarias
4. **UX**: Cards interactivos para posts relacionados

### Patrones Establecidos
- Usar `AttachmentsList` para multimedia completa
- Usar `MediaPreview` solo para vistas compactas
- Mantener separación entre información oficial (reglamento) y comunitaria (foro)
- Logs de debug en servicios para troubleshooting

### Arquitectura de IA
- **Prioridad 1**: Reglamento oficial (fuente autoritativa)
- **Prioridad 2**: Posts del foro (contexto y ejemplos)
- **UI**: Cards distinguibles (primario para reglamento, secundario para foro)
- **Navegación**: Flujo chat → post específico

---

## Para la Próxima Sesión

Cuando retomes el proyecto, ejecuta:
```bash
flutter analyze
flutter build apk --debug
```

Y revisa que todas las funcionalidades estén operativas:
1. Chat IA con posts relacionados
2. Creación/edición de posts y respuestas con multimedia
3. Navegación "Mis Posts" → post específico
4. Multimedia interactiva en todas las respuestas

**Estado del proyecto**: Estable y completamente funcional con sistema de administración ✅

### Notas importantes sobre roles:
- Por defecto, todos los usuarios nuevos tienen rol 'user'
- Para hacer a alguien admin, actualizar manualmente en Firestore:
  - Colección `users` > documento del usuario > campo `role: 'admin'`
- Los admins pueden:
  - Ver panel de administración
  - Gestionar reportes
  - Suspender/banear usuarios
  - Eliminar contenido
  - Subir/editar reglamentos