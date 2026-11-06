import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/providers/app_providers.dart';
import 'firebase_options.dart';

const bool kUseFirebase = bool.fromEnvironment(
  'USE_FIREBASE',
  defaultValue: false,
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kUseFirebase) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  runApp(
    ProviderScope(
      overrides: [useFirebaseProvider.overrideWithValue(kUseFirebase)],
      child: const GowaykiLabApp(),
    ),
  );
}
