import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../domain/auth/auth_failure.dart';
import '../../domain/repositories/google_identity_repository.dart';
import '../../google_oauth_options.dart';

class PlatformGoogleIdentityRepository implements GoogleIdentityRepository {
  // The platform SDK is a process singleton and must be initialized only once.
  static Future<void>? _initializing;
  Future<void> _init() async {
    if (kIsWeb ||
        !{
          TargetPlatform.android,
          TargetPlatform.iOS,
        }.contains(defaultTargetPlatform)) {
      throw const AuthFailure(AuthFailureCode.methodUnavailable);
    }
    final opening = _initializing ??= GoogleSignIn.instance.initialize(
      clientId: defaultTargetPlatform == TargetPlatform.iOS
          ? GoogleOAuthOptions.iosClientId
          : null,
      serverClientId: GoogleOAuthOptions.serverClientId,
    );
    try {
      await opening;
    } on Object {
      _initializing = null;
      rethrow;
    }
  }

  @override
  Future<String> authenticateIdToken() async {
    try {
      await _init();
      final account = await GoogleSignIn.instance.authenticate();
      final token = account.authentication.idToken;
      if (token == null || token.isEmpty) {
        throw const AuthFailure(AuthFailureCode.invalidCredentials);
      }
      return token;
    } on GoogleSignInException catch (error) {
      throw AuthFailure(switch (error.code) {
        GoogleSignInExceptionCode.canceled => AuthFailureCode.cancelled,
        GoogleSignInExceptionCode.interrupted => AuthFailureCode.network,
        GoogleSignInExceptionCode.clientConfigurationError ||
        GoogleSignInExceptionCode.providerConfigurationError ||
        GoogleSignInExceptionCode.uiUnavailable =>
          AuthFailureCode.methodUnavailable,
        _ => AuthFailureCode.unexpected,
      });
    }
  }

  @override
  Future<void> signOut() async {
    if (_initializing != null) {
      await _initializing;
      await GoogleSignIn.instance.signOut();
    }
  }
}
