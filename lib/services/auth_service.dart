import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'push_notification_service.dart';
import 'supabase_service.dart';

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

    if (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux) {
      throw UnsupportedError(
        'Đăng nhập Google trên nền tảng này cần bản Web. Hãy chạy run.bat hoặc flutter run -d chrome.',
      );
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
    if (SupabaseService.isInitialized) {
      try {
        await PushNotificationService.instance.unregisterCurrentDevice(
          SupabaseService.client,
        );
      } catch (error) {
        debugPrint('Push token cleanup on logout failed: $error');
      }
    }
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
