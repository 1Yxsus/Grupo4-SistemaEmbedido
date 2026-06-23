import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  // Stream para escuchar los cambios de estado de autenticación (logueado / no logueado)
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Obtener el usuario actual
  User? get usuarioActual => _auth.currentUser;

  // Registrar un nuevo usuario (Authentication + Realtime Database)
  Future<User?> registrarUsuario(
    String nombre,
    String email,
    String password,
  ) async {
    try {
      // 1. Crear usuario en Firebase Authentication
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

      User? user = userCredential.user;

      if (user != null) {
        // 2. Guardar datos adicionales en Realtime Database usando el UID del usuario
        await _dbRef.child('usuarios').child(user.uid).set({
          'nombre': nombre,
          'correo': email,
          'fecha_registro': ServerValue.timestamp,
          'rol': 'Almacenero', // Rol predeterminado
        });
      }
      return user;
    } on FirebaseAuthException catch (e) {
      debugPrint(
        "Error en FirebaseAuth al registrar: ${e.code} - ${e.message}",
      );
      rethrow; // Lanzamos la excepción para manejarla en la UI y mostrar el error adecuado
    } catch (e) {
      debugPrint("Error inesperado en el registro: $e");
      rethrow;
    }
  }

  // Iniciar Sesión (Login)
  Future<User?> iniciarSesion(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      debugPrint(
        "Error en FirebaseAuth al iniciar sesión: ${e.code} - ${e.message}",
      );
      rethrow;
    } catch (e) {
      debugPrint("Error inesperado en el login: $e");
      rethrow;
    }
  }

  // Cerrar Sesión (Sign Out)
  Future<void> cerrarSesion() async {
    try {
      await _auth.signOut();
    } catch (e) {
      debugPrint("Error al cerrar sesión: $e");
      rethrow;
    }
  }
}
