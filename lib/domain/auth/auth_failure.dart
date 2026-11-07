enum AuthFailureCode {
  invalidCredentials,
  invalidEmail,
  weakPassword,
  emailInUse,
  disabled,
  methodUnavailable,
  network,
  tooManyRequests,
  differentProvider,
  cancelled,
  localOnly,
  profileUpdateFailed,
  unexpected,
}

class AuthFailure implements Exception {
  const AuthFailure(this.code);
  final AuthFailureCode code;
  @override
  String toString() => 'AuthFailure(${code.name})';
}
