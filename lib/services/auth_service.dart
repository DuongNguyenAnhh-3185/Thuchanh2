import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Xác thực Google bằng Firebase Authentication.
class AuthService {
  static final AuthService instance = AuthService._internal();

  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  GoogleSignIn? _googleSignIn;

  GoogleSignIn get _googleSignInInstance => _googleSignIn ??= GoogleSignIn();

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<User?> signInWithGoogle() async {
    if (kIsWeb) {
      final provider = GoogleAuthProvider()
        ..addScope('email')
        ..addScope('profile')
        // Google keeps its browser session after Firebase signs out. Force the
        // account chooser so a tester can switch between multiple accounts.
        ..setCustomParameters(<String, String>{'prompt': 'select_account'});
      final credential = await _auth.signInWithPopup(provider);
      return credential.user;
    }

    final googleUser = await _googleSignInInstance.signIn();
    if (googleUser == null) return null;

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final result = await _auth.signInWithCredential(credential);
    return result.user;
  }

  Future<void> signOut() async {
    if (!kIsWeb) {
      try {
        await _googleSignInInstance.signOut();
      } catch (_) {
        // Firebase vẫn phải đăng xuất nếu plugin Google không có trên nền tảng.
      }
    }
    await _auth.signOut();
  }
}

Future<User?> signInWithGoogle() => AuthService.instance.signInWithGoogle();
