import 'package:flutter/widgets.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../l10n/generated/app_localizations_es.dart';

extension LocalizedContext on BuildContext {
  AppLocalizations get l10n =>
      Localizations.of<AppLocalizations>(this, AppLocalizations) ??
      AppLocalizationsEs();
}
