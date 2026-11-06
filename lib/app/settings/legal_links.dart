import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

class LegalLinks {
  const LegalLinks({this.privacy, this.terms});
  final Uri? privacy, terms;
  static Uri? parse(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
            ['https', 'http'].contains(uri.scheme) &&
            uri.host.isNotEmpty
        ? uri
        : null;
  }
}

final legalLinksProvider = Provider<LegalLinks>(
  (ref) => LegalLinks(
    privacy: LegalLinks.parse(const String.fromEnvironment('PRIVACY_URL')),
    terms: LegalLinks.parse(const String.fromEnvironment('TERMS_URL')),
  ),
);

abstract interface class ExternalLinkOpener {
  Future<bool> open(Uri uri);
}

class BrowserLinkOpener implements ExternalLinkOpener {
  @override
  Future<bool> open(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);
}

final externalLinkOpenerProvider = Provider<ExternalLinkOpener>(
  (ref) => BrowserLinkOpener(),
);
