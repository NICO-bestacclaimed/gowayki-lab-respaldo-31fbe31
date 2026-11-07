import 'dart:async';

/// Serializes native Auth mutations, including deletion, across repositories.
/// FlutterFire's native delete API addresses the current user of the app.
class AuthOperations {
  Future<void>? _tail;
  Future<AuthLease> acquire() async {
    final previous = _tail, turn = Completer<void>();
    _tail = turn.future;
    if (previous != null) await previous;
    return AuthLease(() {
      turn.complete();
      if (identical(_tail, turn.future)) _tail = null;
    });
  }

  Future<T> run<T>(Future<T> Function() action) async {
    final lease = await acquire();
    try {
      return await action();
    } finally {
      lease.release();
    }
  }
}

class AuthLease {
  AuthLease(this._release);
  void Function()? _release;
  void release() {
    final release = _release;
    _release = null;
    release?.call();
  }
}

final firebaseAuthOperations = AuthOperations();
