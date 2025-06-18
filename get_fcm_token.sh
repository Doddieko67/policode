#!/bin/bash

echo "🚀 Compilando PoliCode en modo debug..."
echo "================================="

# Compilar la app
flutter build apk --debug

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Compilación exitosa!"
    echo ""
    echo "📱 Para obtener el token FCM:"
    echo "1. Instala la APK: flutter install"
    echo "2. Abre la app e inicia sesión"
    echo "3. Ve a Configuración de Perfil"
    echo "4. Toca 'Ver Token FCM'"
    echo ""
    echo "🔍 También puedes ver el token en:"
    echo "- La pantalla principal (widget de debug)"
    echo "- Los logs de la app después del login"
    echo ""
    echo "📦 APK ubicada en: build/app/outputs/flutter-apk/app-debug.apk"
else
    echo "❌ Error en la compilación"
    exit 1
fi