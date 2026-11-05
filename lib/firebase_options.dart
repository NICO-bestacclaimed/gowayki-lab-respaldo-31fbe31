import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Placeholder: reemplaza con `flutterfire configure`.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Web no configurado.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError('Plataforma no configurada.');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'REEMPLAZAR_API_KEY',
    appId: 'REEMPLAZAR_APP_ID',
    messagingSenderId: 'REEMPLAZAR_SENDER_ID',
    projectId: 'gowayki-lab-tecsup',
    storageBucket: 'gowayki-lab-tecsup.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'REEMPLAZAR_API_KEY',
    appId: 'REEMPLAZAR_APP_ID',
    messagingSenderId: 'REEMPLAZAR_SENDER_ID',
    projectId: 'gowayki-lab-tecsup',
    storageBucket: 'gowayki-lab-tecsup.appspot.com',
    iosBundleId: 'pe.edu.tecsup.gowaykiLab',
  );
}
