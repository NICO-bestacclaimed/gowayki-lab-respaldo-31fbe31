import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gowayki_lab/app/features/sign_in/presentation/screens/sign_in_screen.dart';
import 'package:gowayki_lab/app/providers/app_providers.dart';
import 'package:gowayki_lab/core/models/auth_user.dart';
import 'package:gowayki_lab/domain/auth/auth_failure.dart';
import 'package:gowayki_lab/domain/repositories/auth_repository.dart';

class Auth extends Fake implements AuthRepository {
  final calls = <String>[];
  Completer<void>? pending;
  AuthFailure? error;
  @override
  AuthUser? get currentUser => null;
  Future<void> action(String value) async {
    calls.add(value);
    if (pending != null) await pending!.future;
    if (error != null) throw error!;
  }

  @override
  Stream<AuthUser?> observeSession() => Stream.value(null);
  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) => action('email:$email');
  @override
  Future<void> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) => action('register:$email:$displayName');
  @override
  Future<void> sendPasswordReset({required String email}) =>
      action('reset:$email');
  @override
  Future<void> signInWithGoogle() => action('google');
  @override
  Future<void> signInAnonymously() => action('guest');
  @override
  Future<void> signOut() => action('out');
}

void main() {
  late Auth auth;
  var signed = 0;
  setUp(() {
    auth = Auth();
    signed = 0;
  });
  Future<void> mount(WidgetTester tester, {bool firebase = true}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          useFirebaseProvider.overrideWithValue(firebase),
        ],
        child: MaterialApp(home: SignInScreen(onSignedIn: () => signed++)),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder key(String value) => find.byKey(ValueKey('auth.$value'));
  Future<void> tap(WidgetTester tester, String value) async {
    await tester.ensureVisible(key(value));
    await tester.tap(key(value));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'fields start empty and invalid credentials never call authentication',
    (tester) async {
      await mount(tester);
      for (final field in ['email', 'password']) {
        final widget = tester.widget<TextFormField>(key(field));
        expect(widget.controller!.text, isEmpty);
      }
      await tap(tester, 'submit');
      expect(auth.calls, isEmpty);
      expect(find.text('Escribe un correo válido.'), findsOneWidget);
      await tester.enterText(key('email'), 'fixture@example.test');
      await tester.enterText(key('password'), 'Fixture-Pass-123');
      await tap(tester, 'submit');
      expect(auth.calls, ['email:fixture@example.test']);
      expect(signed, 1);
    },
  );
  testWidgets(
    'registration validates name and matching passwords and uses the entered name',
    (tester) async {
      await mount(tester);
      await tap(tester, 'mode');
      await tester.enterText(key('name'), 'Ana');
      await tester.enterText(key('email'), 'fixture@example.test');
      await tester.enterText(key('password'), 'Fixture-Pass-123');
      await tester.enterText(key('confirmation'), 'Other-Pass-123');
      await tap(tester, 'submit');
      expect(auth.calls, isEmpty);
      expect(find.text('Las contraseñas no coinciden.'), findsOneWidget);
      await tester.enterText(key('confirmation'), 'Fixture-Pass-123');
      await tap(tester, 'submit');
      expect(auth.calls, ['register:fixture@example.test:Ana']);
      expect(signed, 1);
    },
  );
  testWidgets(
    'password recovery only needs a valid email and does not navigate',
    (tester) async {
      await mount(tester);
      await tap(tester, 'reset');
      expect(auth.calls, isEmpty);
      await tester.enterText(key('email'), 'fixture@example.test');
      await tap(tester, 'reset');
      expect(auth.calls, ['reset:fixture@example.test']);
      expect(signed, 0);
      expect(find.textContaining('Si existe una cuenta'), findsOneWidget);
    },
  );
  testWidgets(
    'Google cancellation is quiet and actions become available again',
    (tester) async {
      await mount(tester);
      auth.error = const AuthFailure(AuthFailureCode.cancelled);
      await tap(tester, 'google');
      expect(auth.calls, ['google']);
      expect(signed, 0);
      expect(key('error'), findsNothing);
      auth.error = null;
      await tap(tester, 'guest');
      expect(auth.calls, ['google', 'guest']);
      expect(signed, 1);
    },
  );
  testWidgets('network errors are localized and contain no SDK code', (
    tester,
  ) async {
    await mount(tester);
    auth.error = const AuthFailure(AuthFailureCode.network);
    await tap(tester, 'google');
    expect(
      find.text(
        'No pudimos conectar. Revisa tu conexión e inténtalo de nuevo.',
      ),
      findsOneWidget,
    );
    expect(signed, 0);
  });
  testWidgets(
    'local mode offers a real local guest without fake accounts or credentials',
    (tester) async {
      await mount(tester, firebase: false);
      expect(key('email'), findsNothing);
      expect(key('google'), findsNothing);
      await tap(tester, 'guest');
      expect(auth.calls, ['guest']);
      expect(signed, 1);
      expect(find.text('wayki@gowayki.lab'), findsNothing);
    },
  );
  testWidgets(
    'small screen with keyboard and large text remains scrollable without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(auth),
            useFirebaseProvider.overrideWithValue(true),
          ],
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(1.8),
                viewInsets: const EdgeInsets.only(bottom: 220),
              ),
              child: child!,
            ),
            home: SignInScreen(onSignedIn: () => signed++),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tap(tester, 'mode');
      expect(tester.takeException(), isNull);
    },
  );
}
