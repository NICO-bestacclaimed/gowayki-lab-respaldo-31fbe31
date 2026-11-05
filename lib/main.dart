import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'data/service_locator.dart';
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

  await ServiceLocator.init(useFirebase: kUseFirebase);
  runApp(const GowaykiLabApp());
}
