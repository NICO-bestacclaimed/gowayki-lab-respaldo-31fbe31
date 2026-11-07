import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gowayki_lab/firebase_options.dart';

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);
  test(
    'Android options use the supplied app client and project, without placeholders',
    () {
      final data =
          jsonDecode(
                File('android/app/google-services.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      final client = (data['client'] as List)
          .cast<Map<String, dynamic>>()
          .singleWhere(
            (c) =>
                c['client_info']['android_client_info']['package_name'] ==
                'pe.edu.tecsup.gowayki_lab',
          );
      final options = DefaultFirebaseOptions.android;
      expect(options.projectId, data['project_info']['project_id']);
      expect(options.appId, client['client_info']['mobilesdk_app_id']);
      expect(options.apiKey, client['api_key'][0]['current_key']);
      expect(options.messagingSenderId, data['project_info']['project_number']);
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(DefaultFirebaseOptions.currentPlatform, options);
      expect(options.projectId, DefaultFirebaseOptions.ios.projectId);
      expect(
        File('lib/firebase_options.dart').readAsStringSync(),
        isNot(contains('REEMPLAZAR')),
      );
    },
  );
  test(
    'iOS options and Xcode resources match the registered bundle and plist',
    () {
      final xml = File(
        'ios/Runner/GoogleService-Info.plist',
      ).readAsStringSync();
      String? value(String key) => RegExp(
        '<key>$key</key>\\s*<string>([^<]+)</string>',
      ).firstMatch(xml)?.group(1);
      final options = DefaultFirebaseOptions.ios;
      expect(options.projectId, value('PROJECT_ID'));
      expect(options.appId, value('GOOGLE_APP_ID'));
      expect(options.iosBundleId, value('BUNDLE_ID'));
      expect(options.iosClientId, value('CLIENT_ID'));
      final xcode = File(
        'ios/Runner.xcodeproj/project.pbxproj',
      ).readAsStringSync();
      expect(
        xcode,
        contains('PRODUCT_BUNDLE_IDENTIFIER = ${options.iosBundleId};'),
      );
      expect(xcode, contains('GoogleService-Info.plist in Resources'));
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(DefaultFirebaseOptions.currentPlatform, options);
    },
  );
  test(
    'unsupported platforms fail explicitly instead of choosing an invented Firebase app',
    () {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      expect(
        () => DefaultFirebaseOptions.currentPlatform,
        throwsUnsupportedError,
      );
    },
  );
}
