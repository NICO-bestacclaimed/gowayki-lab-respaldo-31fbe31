// Generated locally from the supplied client configuration. Regenerate with tool/configure_firebase.py.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) throw UnsupportedError('Firebase web no configurado.');
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => android,
      TargetPlatform.iOS => ios,
      _ => throw UnsupportedError(
        'Firebase disponible para Android/iOS en este proyecto.',
      ),
    };
  }

  static const android = FirebaseOptions(
    apiKey: "AIzaSyDuCpGsXMXrsMzG_CvGiERL0m-8A2VF7ec",
    appId: "1:959294066022:android:3ab035e603ff2ab4998ca7",
    messagingSenderId: "959294066022",
    projectId: "gowayki-lab",
    storageBucket: "gowayki-lab.firebasestorage.app",
  );
  static const ios = FirebaseOptions(
    apiKey: "AIzaSyCdl-dj-W4Ct-8Ctxzk897DjKa-gJHCSgU",
    appId: "1:959294066022:ios:9995015ebc89a67d998ca7",
    messagingSenderId: "959294066022",
    projectId: "gowayki-lab",
    storageBucket: "gowayki-lab.firebasestorage.app",
    iosBundleId: "pe.edu.tecsup.mobilityLab",
    iosClientId:
        "959294066022-esk3p3la0al73lrnbhspk5h6608mtb6m.apps.googleusercontent.com",
  );
}
