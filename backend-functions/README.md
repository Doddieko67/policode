# PoliCode - Firebase Cloud Functions

Sistema de notificaciones push para la aplicación PoliCode.

## 🚀 Funciones Disponibles

### `sendNotificationOnCreate`
- **Trigger**: Se ejecuta automáticamente cuando se crea una notificación en Firestore
- **Propósito**: Envía notificación push al dispositivo del usuario
- **Características**:
  - Soporte para múltiples tokens FCM por usuario
  - Limpieza automática de tokens inválidos
  - Contador de badge para iOS
  - Configuración específica para Android/iOS

### `sendDirectNotification`
- **Trigger**: Llamada HTTPS desde la aplicación
- **Propósito**: Enviar notificaciones directas sin crear en BD
- **Uso**: Para notificaciones inmediatas o de testing

### `sendTestNotification`
- **Trigger**: Llamada HTTPS desde la aplicación
- **Propósito**: Enviar notificación de prueba al usuario actual
- **Uso**: Testing del sistema de notificaciones

### `cleanupOldNotifications`
- **Trigger**: Programado (cada domingo a las 2 AM)
- **Propósito**: Eliminar notificaciones de más de 30 días
- **Uso**: Mantenimiento automático

## 📦 Instalación

1. **Instalar dependencias**:
   ```bash
   npm install
   ```

2. **Compilar TypeScript**:
   ```bash
   npm run build
   ```

3. **Desplegar a Firebase**:
   ```bash
   npm run deploy
   ```

## 🛠️ Comandos Disponibles

```bash
# Compilar
npm run build

# Ejecutar emulador local
npm run serve

# Desplegar a producción
npm run deploy

# Ver logs
npm run logs

# Limpiar archivos build
npm run clean
```

## 🔧 Configuración

Las funciones están configuradas para:
- **Runtime**: Node.js 20
- **Región**: us-central1 (default)
- **Proyecto**: foquita-hiromi-7ea96

## 📱 Integración con Flutter

La aplicación Flutter se conecta automáticamente a estas funciones:
- Las notificaciones creadas en `/notifications` disparan `sendNotificationOnCreate`
- La app puede llamar `sendTestNotification` para probar el sistema
- Tokens FCM se gestionan automáticamente

## 🐛 Debugging

Para ver logs en tiempo real:
```bash
firebase functions:log --follow
```

Para testing local:
```bash
npm run serve
```

## 🔒 Seguridad

- Todas las funciones requieren autenticación
- Validación de permisos antes de enviar notificaciones
- Limpieza automática de tokens inválidos
- No exposición de información sensible en logs