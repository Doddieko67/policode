import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Firebase imports
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:policode/screens/articulo_detail_screen.dart';
import 'package:policode/screens/forum_screen.dart';
import 'package:policode/screens/create_post_screen.dart';
import 'package:policode/screens/reglamentos_screen.dart';
import 'package:policode/screens/mis_posts_screen.dart';
import 'package:policode/screens/admin/admin_dashboard_screen.dart';
import 'package:policode/screens/admin/reports_management_screen.dart';
import 'package:policode/screens/admin/regulations_management_screen.dart';
import 'package:policode/screens/profile_settings_screen.dart';
import 'package:policode/services/firebase_config.dart';

import 'package:policode/core/themes/app_theme.dart';
import 'package:policode/screens/auth_screen.dart';
import 'package:policode/screens/chat_screen.dart';
import 'package:policode/screens/home_screen.dart';
import 'package:policode/screens/notas_screen.dart';
import 'package:policode/widgets/loading_widgets.dart';

// Services
import 'services/auth_service.dart';
import 'services/reglamento_service.dart';


void main() async {
  // Asegurar que Flutter esté inicializado
  WidgetsFlutterBinding.ensureInitialized();

  // Cargar variables de entorno
  await dotenv.load(fileName: ".env");

  // Configurar orientación (solo portrait por ahora)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Configurar barra de estado
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Inicializar Gemini con API key desde .env
  final geminiApiKey = dotenv.env['GEMINI_API_KEY'];
  if (geminiApiKey == null || geminiApiKey.isEmpty) {
    throw Exception('GEMINI_API_KEY no está configurada en .env');
  }
  
  Gemini.init(
    apiKey: geminiApiKey,
    enableDebugging: true, // Solo para desarrollo
  );

  await Firebase.initializeApp();
  await FirebaseConfig.initialize();
  // Ejecutar app con manejo de errores
  runApp(const PoliCodeApp());
}

/// Aplicación principal de PoliCode
class PoliCodeApp extends StatelessWidget {
  const PoliCodeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PoliCode',
      debugShowCheckedModeBanner: false,

      // Tema de la aplicación
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,

      // Pantalla inicial se define en routes con '/'
      initialRoute: '/',

      // Rutas de navegación
      routes: _buildRoutes(),

      // Resto del código igual...
      onUnknownRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(title: const Text('Error')),
            body: const Center(
              child: CustomErrorWidget(
                title: 'Página no encontrada',
                message: 'La página que buscas no existe.',
                icon: Icons.error_outline,
              ),
            ),
          ),
        );
      },

      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaleFactor: MediaQuery.of(
              context,
            ).textScaleFactor.clamp(0.8, 1.2),
          ),
          child: child ?? const SizedBox(),
        );
      },
    );
  }

  /// Configurar todas las rutas de la aplicación
  Map<String, WidgetBuilder> _buildRoutes() {
    return {
      '/': (context) => const AppInitializer(),
      '/auth': (context) => const AuthScreen(),
      '/home': (context) => const HomeScreen(),
      '/chat': (context) => const ChatScreen(),
      '/notas': (context) => const NotasScreen(),
      '/forum': (context) => const ForumScreen(),
      '/create-post': (context) => const CreatePostScreen(),
      '/articulo': (context) => const ArticuloDetailScreen(),
      '/reglamentos': (context) => const ReglamentosScreen(),
      '/mis-posts': (context) => const MisPostsScreen(),
      '/profile-settings': (context) => const ProfileSettingsScreen(),
      // Admin routes
      '/admin': (context) => const AdminDashboardScreen(),
      '/admin/reports': (context) => const ReportsManagementScreen(),
      '/admin/regulations': (context) => const RegulationsManagementScreen(),
    };
  }
}

/// Widget que maneja la inicialización de la aplicación
class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  bool _isInitialized = false;
  bool _hasError = false;
  String? _errorMessage;

  // Flag para prevenir múltiples inicializaciones
  static bool _isInitializing = false;

  @override
  void initState() {
    super.initState();
    if (!_isInitializing) {
      _initializeApp();
    }
  }

  Future<void> _initializeApp() async {
    if (_isInitializing) return; // Prevenir múltiples llamadas

    _isInitializing = true;

    try {
      print('🚀 Iniciando app...');

      // 1. Firebase ya fue inicializado en main()
      print('📱 Firebase ya inicializado...');

      // 2. Inicializar servicios
      print('🔐 Inicializando servicios...');
      await AuthService().initialize();

      // 3. Precargar reglamento
      print('📚 Cargando reglamento...');
      await ReglamentoService().cargarReglamento();

      // 4. Pequeña pausa para mostrar splash
      await Future.delayed(const Duration(milliseconds: 1500));

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });

        // 5. Navegar a la pantalla apropiada
        _navigateToInitialScreen();
      }

      print('✅ App inicializada correctamente');
    } catch (e) {
      print('❌ Error inicializando app: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    } finally {
      _isInitializing = false;
    }
  }

  void _retryInitialization() {
    setState(() {
      _isInitialized = false;
      _hasError = false;
      _errorMessage = null;
    });
    _isInitializing = false; // Reset flag
    _initializeApp();
  }

  void _navigateToInitialScreen() {
    if (!mounted) return;

    // Verificar si hay usuario autenticado
    final authService = AuthService();

    if (authService.isSignedIn) {
      // Usuario ya autenticado -> ir a home
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      // No hay usuario -> ir a auth
      Navigator.pushReplacementNamed(context, '/auth');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Scaffold(
        body: Center(
          child: CustomErrorWidget(
            title: 'Error de inicialización',
            message: _errorMessage ?? 'Error desconocido',
            onRetry: _retryInitialization,
            icon: Icons.error_outline,
          ),
        ),
      );
    }

    if (!_isInitialized) {
      return const SplashScreen();
    }

    // Esta pantalla nunca debería mostrarse ya que navegamos inmediatamente
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

/// Pantalla de Splash
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.primaryColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo animado
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 1000),
              tween: Tween(begin: 0.0, end: 1.0),
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const CircleAvatar(
                      backgroundColor: Colors.white,
                      radius: 18,
                      backgroundImage: AssetImage('assets/images/logo.png'),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 40),

            // Título
            Text(
              'PoliCode',
              style: theme.textTheme.headlineLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),

            const SizedBox(height: 12),

            // Subtítulo
            Text(
              'Asistente del Reglamento Estudiantil',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: Colors.white.withOpacity(0.9),
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 60),

            // Loading indicator
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              strokeWidth: 3,
            ),

            const SizedBox(height: 20),

            Text(
              'Cargando...',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pantalla de Error genérica
class ErrorScreen extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onRetry;

  const ErrorScreen({
    super.key,
    required this.title,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 80,
                color: theme.colorScheme.error,
              ),

              const SizedBox(height: 24),

              Text(
                title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              Text(
                message,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 40),

              if (onRetry != null)
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

