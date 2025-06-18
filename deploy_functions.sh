#!/bin/bash

echo "🔥 Desplegando Firebase Cloud Functions para PoliCode..."
echo "=================================================="

# Verificar que Firebase CLI esté instalado
if ! command -v firebase &> /dev/null; then
    echo "❌ Firebase CLI no está instalado."
    echo "📥 Instala con: npm install -g firebase-tools"
    exit 1
fi

# Navegar a la carpeta functions
cd functions

echo "📦 Instalando dependencias de Node.js..."
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

# Volver a la raíz del proyecto
cd ..

echo "☁️ Desplegando Cloud Functions..."
firebase deploy --only functions

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ ¡Cloud Functions desplegadas exitosamente!"
    echo ""
    echo "🎯 Funciones disponibles:"
    echo "- sendNotificationOnCreate: Se ejecuta automáticamente al crear notificaciones"
    echo "- sendDirectNotification: Para enviar notificaciones directas"
    echo "- cleanupOldNotifications: Limpia notificaciones antiguas (ejecuta semanalmente)"
    echo ""
    echo "🔔 Ahora recibirás notificaciones push reales en segundo plano!"
else
    echo "❌ Error desplegando Cloud Functions"
    exit 1
fi