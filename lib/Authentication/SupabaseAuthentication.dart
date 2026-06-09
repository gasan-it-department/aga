import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:gasan_port_tracker/Database/SupabaseUtility.dart';
import 'package:gasan_port_tracker/Utility/Utility.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../Dialogs/ClassicDialog.dart';

class SupabaseAuthentication {
  final supabase = Supabase.instance.client;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  final _classicDialog = ClassicDialog();

  bool isUserAuthenticated() {
    final session = supabase.auth.currentSession;
    return session != null;
  }

  void signInWithGoogle(void Function(String? errorMessage, StackTrace? stacktrrace) onError, void Function(AuthResponse authResponse) onSuccess) async {
    try {
      await Future.delayed(Duration(milliseconds: 500));
      if (kIsWeb) {
        Utility().printLog('Starting Supabase Web OAuth Flow...');

        final String redirectUrl = kDebugMode
            ? 'http://localhost:3000'
              :'https://aga-app.gasan.workers.dev/';

        await supabase.auth.signInWithOAuth(
          OAuthProvider.google,
          queryParams: {
            'prompt': 'select_account',
          },
          redirectTo: redirectUrl,
          authScreenLaunchMode: LaunchMode.inAppWebView
        );

        await Completer<void>().future;
        return null;
      } else {
        await _googleSignIn.initialize(
          clientId: SupabaseUtility().getGoogleOauthClientId(),
          serverClientId: SupabaseUtility().getGoogleOauthClientId(),
        );

        final googleUser = await _googleSignIn.authenticate();

        final googleAuth = googleUser.authentication;
        final idToken = googleAuth.idToken;

        if (idToken == null) {
          throw 'Missing Google ID Token.';
        }

        final authorization = await googleUser.authorizationClient.authorizeScopes([
          'email',
          'profile',
        ]);

        final accessToken = authorization.accessToken;

        final response = await supabase.auth.signInWithIdToken(
          provider: OAuthProvider.google,
          idToken: idToken,
          accessToken: accessToken,
        );

        Utility().printLog('Supabase Sign-In Successful for: ${response.user?.email}');
        onSuccess(response);
      }

    } catch (error, stacktrace) {
      Utility().printLog('General Error: $error');
      Utility().printLog('Stacktrace: $stacktrace');
      onError(error.toString(), stacktrace);
    }
  }

  Future<AuthResponse?> signUpWithEmail(String email, String password) async {
    try {
      return await supabase.auth.signUp(
        email: email,
        password: password,
      );
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
