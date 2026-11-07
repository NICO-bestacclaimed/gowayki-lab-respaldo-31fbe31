import '../../domain/auth/auth_failure.dart';
import '../../l10n/generated/app_localizations.dart';

String authErrorText(Object error, AppLocalizations l) => switch (error) {
  AuthFailure(code: final code) => switch (code) {
    AuthFailureCode.invalidCredentials => l.authInvalidCredentials,
    AuthFailureCode.invalidEmail => l.authInvalidEmail,
    AuthFailureCode.weakPassword => l.authWeakPassword,
    AuthFailureCode.emailInUse => l.authEmailInUse,
    AuthFailureCode.disabled => l.authDisabled,
    AuthFailureCode.methodUnavailable => l.authMethodUnavailable,
    AuthFailureCode.network => l.authNetwork,
    AuthFailureCode.tooManyRequests => l.authTooMany,
    AuthFailureCode.differentProvider => l.authDifferentProvider,
    AuthFailureCode.localOnly => l.authLocalHelp,
    AuthFailureCode.profileUpdateFailed => l.authProfileWarning,
    _ => l.genericError,
  },
  _ => l.genericError,
};
