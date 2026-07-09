import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:gasan_port_tracker/Database/SupabaseUtility.dart';
import 'package:gasan_port_tracker/Services/BackgroundService.dart';
import 'package:gasan_port_tracker/Services/WebPushNotificationService.dart';
import 'package:gasan_port_tracker/Utility/Utility.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseAuthentication {
  static bool _googleSignInInProgress = false;
  final supabase = Supabase.instance.client;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  bool isUserAuthenticated() {
    final session = supabase.auth.currentSession;
    return session != null;
  }

  void signInWithGoogle(
    void Function(String? errorMessage, StackTrace? stacktrrace) onError,
    void Function(AuthResponse authResponse) onSuccess,
  ) async {
    if (_googleSignInInProgress) return;
    _googleSignInInProgress = true;
    try {
      await Future.delayed(Duration(milliseconds: 500));
      if (kIsWeb) {
        Utility().printLog('Starting Supabase Web OAuth Flow...');

        final String redirectUrl = Uri.base.origin;

        await supabase.auth.signInWithOAuth(
          OAuthProvider.google,
          queryParams: {'prompt': 'select_account'},
          redirectTo: redirectUrl,
          authScreenLaunchMode: LaunchMode.inAppWebView,
        );

        await Completer<void>().future;
        return null;
      } else {
        final googleIOSClientId = SupabaseUtility().getGoogleIOSClientId();
        await _googleSignIn.initialize(
          clientId:
              defaultTargetPlatform == TargetPlatform.iOS &&
                  googleIOSClientId.isNotEmpty
              ? googleIOSClientId
              : null,
          serverClientId: SupabaseUtility().getGoogleOauthClientId(),
        );

        final googleUser = await _googleSignIn.authenticate();

        final googleAuth = googleUser.authentication;
        final idToken = googleAuth.idToken;

        if (idToken == null) {
          throw 'Missing Google ID Token.';
        }

        final response = await supabase.auth.signInWithIdToken(
          provider: OAuthProvider.google,
          idToken: idToken,
        );

        Utility().printLog(
          'Supabase Sign-In Successful for: ${response.user?.email}',
        );
        _googleSignInInProgress = false;
        onSuccess(response);
      }
    } catch (error, stacktrace) {
      _googleSignInInProgress = false;
      Utility().printLog('General Error: $error');
      Utility().printLog('Stacktrace: $stacktrace');
      onError(error.toString(), stacktrace);
    }
  }

  Future<AuthResponse?> signUpWithEmail(String email, String password) async {
    try {
      return await supabase.auth.signUp(email: email, password: password);
    } catch (e) {
      Utility().printLog('Email Sign-Up Error: $e');
      return null;
    }
  }

  Future<AuthResponse?> signInWithEmail(String email, String password) async {
    try {
      return await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      Utility().printLog('Email Login Error: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      await NotificationBackgroundService().clearAuthenticatedUser();
      await WebPushNotificationService.instance.unregisterCurrentUser();
      if (!kIsWeb) {
        await _googleSignIn.signOut();
      }
      await supabase.auth.signOut();
      Utility().printLog('Successfully signed out.');
    } catch (e) {
      rethrow;
    }
  }
}
