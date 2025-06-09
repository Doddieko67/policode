import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'; // Para kIsWeb

/// Configuración centralizada de Firebase para PoliCode
/// Compatible con configuración automática de flutterfire configure
class FirebaseConfig {
  static FirebaseAuth? _auth;
  static FirebaseFirestore? _firestore;
  static bool _isInitialized = false;

  /// Inicializar Firebase (usando instancias existentes)
  static Future<void> initialize() async {
    if (_isInitialized) {
      print('✅ FirebaseConfig ya inicializado');
      return;
    }

    try {
      // Verificar que Firebase ya esté inicializado (por main.dart)
      if (Firebase.apps.isEmpty) {
        throw Exception(
          'Firebase debe estar inicializado antes de llamar FirebaseConfig.initialize(). '
          'Asegúrate de llamar Firebase.initializeApp() primero.',
        );
      }

      print('📱 Configurando servicios de Firebase...');

      // Usar las instancias estándar de Firebase
      _auth = FirebaseAuth.instance;
      _firestore = FirebaseFirestore.instance;

      // Configurar Firestore para offline
      await _configurarFirestore();

      _isInitialized = true;
      print('✅ FirebaseConfig inicializado correctamente');
    } catch (e) {
      print('❌ Error inicializando FirebaseConfig: $e');
      rethrow;
    }
  }

  /// Configurar opciones específicas de Firestore
  static Future<void> _configurarFirestore() async {
    try {
      // Para Flutter Web: habilitar persistencia
      if (kIsWeb) {
        await _firestore!.enablePersistence();
      }

      // La configuración de cache se hace automáticamente en versiones recientes
      print('✅ Firestore configurado para la plataforma actual');
    } catch (e) {
      // Es normal que falle si ya está configurado
      print('⚠️ Firestore ya configurado: $e');
    }
  }

  /// Obtener instancia de FirebaseAuth
  static FirebaseAuth get auth {
    if (_auth == null || !_isInitialized) {
      throw Exception(
        'FirebaseConfig no inicializado. Llama a FirebaseConfig.initialize() primero.',
      );
    }
    return _auth!;
  }

  /// Obtener instancia de FirebaseFirestore
  static FirebaseFirestore get firestore {
    if (_firestore == null || !_isInitialized) {
      throw Exception(
        'FirebaseConfig no inicializado. Llama a FirebaseConfig.initialize() primero.',
      );
    }
    return _firestore!;
  }

  /// Obtener usuario actual
  static User? get currentUser => _auth?.currentUser;

  /// Verificar si hay usuario autenticado
  static bool get isUserSignedIn => currentUser != null;

  /// Stream del estado de autenticación
  static Stream<User?> get authStateChanges =>
      _auth?.authStateChanges() ?? const Stream.empty();

  /// Verificar si FirebaseConfig está inicializado
  static bool get isInitialized => _isInitialized;
}

/// Clase para manejar las colecciones de Firestore
class FirestoreCollections {
  static const String usuarios = 'usuarios';
  static const String notas = 'notas';
  static const String configuraciones = 'configuraciones';
  static const String historialChat = 'historial_chat';

  /// Referencia a la colección de usuarios
  static CollectionReference get usuariosRef =>
      FirebaseConfig.firestore.collection(usuarios);

  /// Referencia a la colección de notas
  static CollectionReference get notasRef =>
      FirebaseConfig.firestore.collection(notas);

  /// Referencia a la colección de configuraciones
  static CollectionReference get configuracionesRef =>
      FirebaseConfig.firestore.collection(configuraciones);

  /// Referencia a la colección de historial de chat
  static CollectionReference get historialChatRef =>
      FirebaseConfig.firestore.collection(historialChat);

  /// Obtener referencia a las notas de un usuario específico
  static CollectionReference notasDelUsuario(String userId) =>
      usuariosRef.doc(userId).collection('notas');

  /// Obtener referencia al historial de chat de un usuario específico
  static CollectionReference historialDelUsuario(String userId) =>
      usuariosRef.doc(userId).collection('historial_chat');
}

/// Utilidades para Firestore
class FirestoreUtils {
  /// Convertir Timestamp de Firestore a DateTime
  static DateTime timestampToDateTime(Timestamp timestamp) {
    return timestamp.toDate();
  }

  /// Convertir DateTime a Timestamp de Firestore
  static Timestamp dateTimeToTimestamp(DateTime dateTime) {
    return Timestamp.fromDate(dateTime);
  }

  /// Verificar si un documento existe
  static Future<bool> documentExists(DocumentReference docRef) async {
    try {
      final doc = await docRef.get();
      return doc.exists;
    } catch (e) {
      print('Error verificando documento: $e');
      return false;
    }
  }

  /// Batch write para múltiples operaciones
  static WriteBatch get batch => FirebaseConfig.firestore.batch();

  /// Transacción
  static Future<T> runTransaction<T>(
    Future<T> Function(Transaction transaction) updateFunction,
  ) {
    return FirebaseConfig.firestore.runTransaction(updateFunction);
  }
}

/// Extensiones útiles para trabajar con Firestore
extension DocumentReferenceExtension on DocumentReference {
  /// Obtener datos con manejo de errores
  Future<Map<String, dynamic>?> getSafely() async {
    try {
      final doc = await get();
      return doc.exists ? doc.data() as Map<String, dynamic>? : null;
    } catch (e) {
      print('Error obteniendo documento $id: $e');
      return null;
    }
  }
}

extension QueryExtension on Query {
  /// Obtener documentos con manejo de errores
  Future<List<QueryDocumentSnapshot>> getSafely() async {
    try {
      final snapshot = await get();
      return snapshot.docs;
    } catch (e) {
      print('Error ejecutando query: $e');
      return [];
    }
  }
}

/// Configuración de reglas de seguridad recomendadas
///
/// Agrega estas reglas en Firebase Console -> Firestore Database -> Rules:
///
/// ```
/// rules_version = '2';
/// service cloud.firestore {
///   match /databases/{database}/documents {
///     // Usuarios pueden leer/escribir solo sus propios datos
///     match /usuarios/{userId} {
///       allow read, write: if request.auth != null && request.auth.uid == userId;
///
///       // Notas del usuario
///       match /notas/{notaId} {
///         allow read, write: if request.auth != null && request.auth.uid == userId;
///       }
///
///       // Historial de chat del usuario
///       match /historial_chat/{chatId} {
///         allow read, write: if request.auth != null && request.auth.uid == userId;
///       }
///     }
///
///     // Configuraciones globales (solo lectura para usuarios autenticados)
///     match /configuraciones/{configId} {
///       allow read: if request.auth != null;
///       allow write: if false; // Solo admins pueden escribir
///     }
///   }
/// }
/// ```
