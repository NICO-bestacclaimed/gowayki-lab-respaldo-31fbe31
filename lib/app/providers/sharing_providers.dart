import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

abstract interface class TextSharing {
  Future<void> share(String text, {required Rect origin});
}

class PlatformTextSharing implements TextSharing {
  @override
  Future<void> share(String text, {required Rect origin}) async {
    await SharePlus.instance.share(
      ShareParams(text: text, sharePositionOrigin: origin),
    );
  }
}

final textSharingProvider = Provider<TextSharing>(
  (ref) => PlatformTextSharing(),
);
