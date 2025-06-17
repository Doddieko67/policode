import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:policode/models/usuario_model.dart';

/// Resultado de operaciones de autenticación
class AuthResult {
  final bool success;
  final String? error;
  final Usuario? usuario;

  const AuthResult({required this.success, this.error, this.usuario});

  factory AuthResult.success(Usuario usuario) =>
      AuthResult(success: true, usuario: usuario);

  factory AuthResult.error(String error) =>
      AuthResult(success: false, error: error);
}

/// Servicio para manejar autenticación con Firebase
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Google Sign-In instance
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

  /// Stream del usuario actual
  Stream<Usuario?> get userStream {
    return _auth.authStateChanges().asyncMap((firebaseUser) async {
      if (firebaseUser == null) return null;
      return await _getUserFromFirestore(firebaseUser.uid);
    });
  }

  /// Usuario actual
  Usuario? _currentUser;
  Usuario? get currentUser => _currentUser;

  /// Verificar si hay usuario autenticado
  bool get isSignedIn => _auth.currentUser != null;

  /// Inicializar el servicio y cargar usuario actual
  Future<void> initialize() async {
    try {
      final firebaseUser = _auth.currentUser;
      if (firebaseUser != null) {
        _currentUser = await _getUserFromFirestore(firebaseUser.uid);
      }
      print('✅ AuthService inicializado');
    } catch (e) {
      print('❌ Error inicializando AuthService: $e');
      rethrow;
    }
  }

  /// Iniciar sesión con Google
  Future<AuthResult> signInWithGoogle() async {
    try {
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // User canceled the sign-in
        return AuthResult.error('Inicio de sesión cancelado');
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Once signed in, return the UserCredential
      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );
      final firebaseUser = userCredential.user;

      if (firebaseUser == null) {
        return AuthResult.error('No se pudo completar el inicio de sesión');
      }

      // Obtener o crear usuario en Firestore
      Usuario? usuario = await _getUserFromFirestore(firebaseUser.uid);

      if (usuario == null) {
        // Si no existe en Firestore, crearlo
        usuario = Usuario.fromFirebaseUser(
          firebaseUser.uid,
          firebaseUser.email!,
          displayName: firebaseUser.displayName,
        );
        await _saveUserToFirestore(usuario);
      } else {
        // Actualizar información de Google si es necesario
        if (usuario.nombre != firebaseUser.displayName) {
          usuario = usuario.copyWith(
            nombre: firebaseUser.displayName ?? usuario.nombre,
            ultimaConexion: DateTime.now(),
          );
          await _saveUserToFirestore(usuario);
        } else {
          // Solo actualizar última conexión
          usuario = usuario.actualizarUltimaConexion();
          await _saveUserToFirestore(usuario);
        }
      }

      _currentUser = usuario;
      return AuthResult.success(usuario);
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_getAuthErrorMessage(e));
    } catch (e) {
      print('Error en Google Sign-In: $e');
      return AuthResult.error(
        'Error inesperado durante el inicio de sesión con Google',
      );
    }
  }

  /// Registrar nuevo usuario
  Future<AuthResult> register({
    required String email,
    required String password,
    String? nombre,
  }) async {
    try {
      // Crear usuario en Firebase Auth
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final firebaseUser = credential.user;
      if (firebaseUser == null) {
        return AuthResult.error('No se pudo crear el usuario');
      }

      // Actualizar perfil si se proporciona nombre
      if (nombre != null && nombre.trim().isNotEmpty) {
        await firebaseUser.updateDisplayName(nombre);
      }

      // Crear usuario en Firestore
      final usuario = Usuario.fromFirebaseUser(
        firebaseUser.uid,
        firebaseUser.email!,
        displayName: nombre,
      );

      await _saveUserToFirestore(usuario);
      _currentUser = usuario;

      return AuthResult.success(usuario);
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_getAuthErrorMessage(e));
    } catch (e) {
      return AuthResult.error('Error inesperado: ${e.toString()}');
    }
  }

  /// Iniciar sesión con email y contraseña
  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final firebaseUser = credential.user;
      if (firebaseUser == null) {
        return AuthResult.error('No se pudo iniciar sesión');
      }

      // Obtener o crear usuario en Firestore
      Usuario? usuario = await _getUserFromFirestore(firebaseUser.uid);

      if (usuario == null) {
        // Si no existe en Firestore, crearlo
        usuario = Usuario.fromFirebaseUser(
          firebaseUser.uid,
          firebaseUser.email!,
          displayName: firebaseUser.displayName,
        );
        await _saveUserToFirestore(usuario);
      } else {
        // Actualizar última conexión
        usuario = usuario.actualizarUltimaConexion();
        await _saveUserToFirestore(usuario);
      }

      _currentUser = usuario;
      return AuthResult.success(usuario);
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_getAuthErrorMessage(e));
    } catch (e) {
      return AuthResult.error('Error inesperado: ${e.toString()}');
    }
  }

  /// Cerrar sesión
  Future<void> signOut() async {
    try {
      // Sign out from Google if user signed in with Google
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
      }

      await _auth.signOut();
      _currentUser = null;
    } catch (e) {
      print('Error cerrando sesión: $e');
      rethrow;
    }
  }

  /// Enviar email de recuperación de contraseña
  Future<AuthResult> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return const AuthResult(success: true);
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_getAuthErrorMessage(e));
    } catch (e) {
      return AuthResult.error('Error inesperado: ${e.toString()}');
    }
  }

  /// Verificar si un username está disponible
  Future<bool> isUsernameAvailable(String username) async {
    try {
      final query = await _firestore
          .collection('usuarios')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();
      return query.docs.isEmpty;
    } catch (e) {
      print('Error verificando username: $e');
      return false;
    }
  }

  /// Generar username único basado en el nombre
  Future<String> generateUniqueUsername(String baseName) async {
    String baseUsername = baseName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '')
        .substring(0, baseName.length < 15 ? baseName.length : 15);
    
    if (baseUsername.isEmpty) {
      baseUsername = 'user';
    }

    String username = baseUsername;
    int counter = 1;

    while (!await isUsernameAvailable(username)) {
      username = '$baseUsername$counter';
      counter++;
      if (counter > 999) break; // Evitar bucle infinito
    }

    return username;
  }

  /// Actualizar perfil del usuario
  Future<AuthResult> updateProfile({
    String? nombre,
    String? username,
    Map<String, dynamic>? configuraciones,
  }) async {
    try {
      if (_currentUser == null) {
        return AuthResult.error('No hay usuario autenticado');
      }

      final firebaseUser = _auth.currentUser;
      if (firebaseUser == null) {
        return AuthResult.error('Usuario no válido');
      }

      // Verificar que el username esté disponible si se proporciona
      if (username != null && username.trim().isNotEmpty) {
        final cleanUsername = username.trim();
        if (cleanUsername != _currentUser!.username) {
          if (!await isUsernameAvailable(cleanUsername)) {
            return AuthResult.error('Ese nombre de usuario ya está en uso');
          }
        }
      }

      // Actualizar en Firebase Auth si se proporciona nombre
      if (nombre != null && nombre.trim().isNotEmpty) {
        await firebaseUser.updateDisplayName(nombre);
      }

      // Actualizar en Firestore
      final usuarioActualizado = _currentUser!.copyWith(
        nombre: nombre,
        username: username?.trim(),
        configuraciones: configuraciones,
        ultimaConexion: DateTime.now(),
      );

      await _saveUserToFirestore(usuarioActualizado);
      _currentUser = usuarioActualizado;

      return AuthResult.success(usuarioActualizado);
    } catch (e) {
      return AuthResult.error('Error actualizando perfil: ${e.toString()}');
    }
  }

  /// Eliminar cuenta
  Future<AuthResult> deleteAccount() async {
    try {
      if (_currentUser == null) {
        return AuthResult.error('No hay usuario autenticado');
      }

      final firebaseUser = _auth.currentUser;
      if (firebaseUser == null) {
        return AuthResult.error('Usuario no válido');
      }

      // Eliminar datos de Firestore
      await _deleteUserFromFirestore(_currentUser!.uid);

      // Sign out from Google if needed
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
      }

      // Eliminar cuenta de Firebase Auth
      await firebaseUser.delete();
      _currentUser = null;

      return const AuthResult(success: true);
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_getAuthErrorMessage(e));
    } catch (e) {
      return AuthResult.error('Error eliminando cuenta: ${e.toString()}');
    }
  }

  /// Reautenticar usuario (requerido para operaciones sensibles)
  Future<AuthResult> reauthenticate(String password) async {
    try {
      final firebaseUser = _auth.currentUser;
      if (firebaseUser == null || firebaseUser.email == null) {
        return AuthResult.error('Usuario no válido');
      }

      final credential = EmailAuthProvider.credential(
        email: firebaseUser.email!,
        password: password,
      );

      await firebaseUser.reauthenticateWithCredential(credential);
      return const AuthResult(success: true);
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_getAuthErrorMessage(e));
    } catch (e) {
      return AuthResult.error('Error reautenticando: ${e.toString()}');
    }
  }

  /// Cambiar contraseña
  Future<AuthResult> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      // Primero reautenticar
      final reauthResult = await reauthenticate(currentPassword);
      if (!reauthResult.success) {
        return reauthResult;
      }

      final firebaseUser = _auth.currentUser;
      if (firebaseUser == null) {
        return AuthResult.error('Usuario no válido');
      }

      await firebaseUser.updatePassword(newPassword);
      return const AuthResult(success: true);
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_getAuthErrorMessage(e));
    } catch (e) {
      return AuthResult.error('Error cambiando contraseña: ${e.toString()}');
    }
  }

  /// Verificar si el usuario se registró con Google
  bool get isGoogleUser {
    final user = _auth.currentUser;
    if (user == null) return false;

    return user.providerData.any(
      (provider) => provider.providerId == 'google.com',
    );
  }

  // Métodos privados

  /// Obtener usuario de Firestore
  Future<Usuario?> _getUserFromFirestore(String uid) async {
    try {
      final doc = await _firestore.collection('usuarios').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return Usuario.fromJson(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      print('Error obteniendo usuario de Firestore: $e');
      return null;
    }
  }

  /// Guardar usuario en Firestore
  Future<void> _saveUserToFirestore(Usuario usuario) async {
    try {
      await _firestore
          .collection('usuarios')
          .doc(usuario.uid)
          .set(usuario.toJson(), SetOptions(merge: true));
      
      // También crear/actualizar en la colección 'users' para el sistema de admin
      // Verificar si el usuario ya existe para no sobrescribir el rol
      final userDoc = await _firestore.collection('users').doc(usuario.uid).get();
      
      if (userDoc.exists) {
        // Usuario existe, solo actualizar campos necesarios sin tocar el rol
        await _firestore
            .collection('users')
            .doc(usuario.uid)
            .update({
              'email': usuario.email,
              'displayName': usuario.nombre,
              'photoURL': null,
            });
      } else {
        // Usuario nuevo, crear con rol por defecto
        await _firestore
            .collection('users')
            .doc(usuario.uid)
            .set({
              'email': usuario.email,
              'displayName': usuario.nombre,
              'photoURL': null,
              'role': 'user', // Solo establecer rol para usuarios nuevos
              'status': 'active',
              'createdAt': FieldValue.serverTimestamp(),
              'reportCount': 0,
            });
      }
    } catch (e) {
      print('Error guardando usuario en Firestore: $e');
      rethrow;
    }
  }

  /// Eliminar usuario de Firestore
  Future<void> _deleteUserFromFirestore(String uid) async {
    try {
      final batch = _firestore.batch();

      // Eliminar usuario
      batch.delete(_firestore.collection('usuarios').doc(uid));

      // Eliminar todas las notas del usuario
      final notas = await _firestore
          .collection('usuarios')
          .doc(uid)
          .collection('notas')
          .get();
      for (final nota in notas.docs) {
        batch.delete(nota.reference);
      }

      // Eliminar historial de chat si existe
      final historial = await _firestore
          .collection('usuarios')
          .doc(uid)
          .collection('historial_chat')
          .get();
      for (final chat in historial.docs) {
        batch.delete(chat.reference);
      }

      await batch.commit();
    } catch (e) {
      print('Error eliminando datos de usuario: $e');
      rethrow;
    }
  }

  /// Convertir errores de Firebase Auth a mensajes legibles
  String _getAuthErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No existe una cuenta con este email';
      case 'wrong-password':
        return 'Contraseña incorrecta';
      case 'email-already-in-use':
        return 'Ya existe una cuenta con este email';
      case 'weak-password':
        return 'La contraseña debe tener al menos 6 caracteres';
      case 'invalid-email':
        return 'Email no válido';
      case 'user-disabled':
        return 'Esta cuenta ha sido deshabilitada';
      case 'too-many-requests':
        return 'Demasiados intentos. Intenta más tarde';
      case 'operation-not-allowed':
        return 'Operación no permitida';
      case 'requires-recent-login':
        return 'Operación sensible. Vuelve a iniciar sesión';
      case 'account-exists-with-different-credential':
        return 'Ya existe una cuenta con este email pero con diferente método de inicio de sesión';
      case 'invalid-credential':
        return 'Las credenciales de autenticación son incorrectas';
      case 'credential-already-in-use':
        return 'Esta cuenta de Google ya está vinculada a otro usuario';
      default:
        return 'Error de autenticación: ${e.message ?? e.code}';
    }
  }
}

/// Extensiones para facilitar el uso
extension AuthServiceExtension on AuthService {
  /// Verificar si el usuario tiene un perfil completo
  bool get hasCompleteProfile {
    return currentUser?.perfilCompleto ?? false;
  }

  /// Obtener configuración específica del usuario
  T? getUserConfig<T>(String key, [T? defaultValue]) {
    return currentUser?.getConfiguracion<T>(key, defaultValue);
  }

  /// Actualizar configuración específica
  Future<AuthResult> updateUserConfig(String key, dynamic value) async {
    if (currentUser == null) {
      return AuthResult.error('No hay usuario autenticado');
    }

    final updatedUser = currentUser!.actualizarConfiguracion(key, value);
    return await updateProfile(configuraciones: updatedUser.configuraciones);
  }
}
