#!/bin/bash

echo "🔥 Desplegando Firebase Cloud Functions para PoliCode..."
echo "=================================================="

# Verificar que Firebase CLI esté instalado
if ! command -v firebase &> /dev/null; then
    echo "❌ Firebase CLI no está instalado."
    echo "📥 Instala con: npm install -g firebase-tools"
    exit 1
fi

# Verificar que estamos en el directorio correcto
if [ ! -f "package.json" ]; then
    echo "❌ No se encontró package.json. Ejecuta desde el directorio functions/"
    exit 1
fi

echo "📦 Instalando dependencias..."
npm install

if [ $? -ne 0 ]; then
    echo "❌ Error instalando dependencias"
    exit 1
fi

echo "🔨 Compilando TypeScript..."
npm run build

if [ $? -ne 0 ]; then
    echo "❌ Error compilando TypeScript"
    exit 1
fi

echo "☁️ Desplegando Cloud Functions..."
firebase deploy --only functions

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ ¡Cloud Functions desplegadas exitosamente!"
    echo ""
    echo "🎯 Funciones disponibles:"
    echo "- sendNotificationOnCreate: Automática al crear notificaciones"
    echo "- sendDirectNotification: Para notificaciones directas"
    echo "- sendTestNotification: Para pruebas del sistema"
    echo "- cleanupOldNotifications: Limpieza automática semanal"
    echo ""
    echo "🔔 Ahora recibirás notificaciones push reales!"
    echo ""
    echo "🧪 Para probar, usa la función sendTestNotification desde la app"
else
    echo "❌ Error desplegando Cloud Functions"
    exit 1
fi