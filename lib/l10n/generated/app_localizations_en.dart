// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'GoWayki';

  @override
  String get explore => 'Explore';

  @override
  String get routes => 'Routes';

  @override
  String get favorites => 'Favorites';

  @override
  String get profile => 'Profile';

  @override
  String get retry => 'Retry';

  @override
  String get settings => 'Settings';

  @override
  String get help => 'Help and feedback';

  @override
  String get signOut => 'Sign out';

  @override
  String get signIn => 'Sign in';

  @override
  String get guest => 'Guest';

  @override
  String get menu => 'Menu';

  @override
  String get back => 'Back';

  @override
  String get continueAction => 'Continue';

  @override
  String get bootstrapError => 'We could not prepare the Arequipa data.';

  @override
  String get linesError => 'We could not load the lines.';

  @override
  String get favoritesEmpty =>
      'You have no favorite lines yet. Save one from Routes.';

  @override
  String get linesEmpty => 'There are no lines in the current data package.';

  @override
  String get removeFavorite => 'Remove from favorites';

  @override
  String get addFavorite => 'Save to favorites';

  @override
  String get saveFailed => 'The change could not be saved. Please try again.';

  @override
  String get noSession => 'You are not signed in.';

  @override
  String get localGuestHelp =>
      'You can explore routes and save favorites on this device.';

  @override
  String get locationTitle => 'Your location, your choice';

  @override
  String get locationExplanation =>
      'GoWayki can use your location to suggest nearby boarding points and help you start a trip from your position.';

  @override
  String get locationOptional =>
      'Permission is optional. You can continue without location access.';

  @override
  String get locationDenied =>
      'Permission was not granted. You can continue and change it later.';

  @override
  String get locationPermanent =>
      'Location permission is disabled in the app settings.';

  @override
  String get openSettings => 'Open settings';

  @override
  String get waitMoment => 'One moment…';

  @override
  String get allowLocation => 'Allow location';

  @override
  String get continueWithoutLocation => 'Continue without location';

  @override
  String get continueFailed => 'We could not continue. Please try again.';

  @override
  String get permissionFailed =>
      'We could not request permission. You can continue without location access.';

  @override
  String get permissionSettingsHelp =>
      'Open the app settings to change the permission.';

  @override
  String get deviceSettingsHelp =>
      'You can change the permission in your device settings.';

  @override
  String get onboardFind => 'Find your bus';

  @override
  String get onboardFindBody =>
      'Explore Arequipa lines and recognize your bus.';

  @override
  String get onboardAlight => 'Know where to get off';

  @override
  String get onboardAlightBody =>
      'Check the stops along your route and your trip connections.';

  @override
  String get onboardTime => 'Arrive on time (estimated times)';

  @override
  String get onboardTimeBody =>
      'Compare options with approximate walking, waiting and riding times.';

  @override
  String get skip => 'Skip';

  @override
  String get start => 'Get started';

  @override
  String get next => 'Next';

  @override
  String get preparing => 'Preparing Arequipa…';

  @override
  String get line => 'Line';

  @override
  String get allDirections => 'All';

  @override
  String get outbound => 'Outbound';

  @override
  String get inbound => 'Inbound';

  @override
  String get whereTo => 'Where are you going?';

  @override
  String get searchExamples => 'Try “TECSUP”, “Plaza” or “Mall”';

  @override
  String get directions => 'Get directions';

  @override
  String get buses => 'Buses';

  @override
  String get searchLine => 'Search line or bus…';

  @override
  String get noResults => 'No results';

  @override
  String get mapError => 'The offline map could not be loaded.';

  @override
  String get feedbackMinimum => 'Enter at least 5 characters';

  @override
  String get feedbackSent => 'Thank you. Your feedback was submitted.';

  @override
  String get feedbackBug => 'Bug';

  @override
  String get feedbackIdea => 'Idea';

  @override
  String get feedbackOther => 'Other';

  @override
  String get message => 'Message';

  @override
  String get send => 'Send';

  @override
  String get genericError =>
      'We could not complete the action. Please try again.';

  @override
  String get planTrip => 'Plan a trip';

  @override
  String get demoOptions => 'Demo options';

  @override
  String get demoOrigin => 'Demo origin';

  @override
  String get brandTagline => 'Your city, closer';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get createAccount => 'Create account';

  @override
  String get guestEntry => 'Continue as guest';

  @override
  String get firebaseActive => 'Firebase Auth enabled';

  @override
  String get localDemo => 'Demo mode · without Firebase';

  @override
  String get pageUnavailable => 'This page is not available.';

  @override
  String get backExplore => 'Back to Explore';

  @override
  String get chooseDestination => 'Choose a destination from Explore.';

  @override
  String get city => 'City';

  @override
  String get activeCity => 'Active city';

  @override
  String get language => 'Language';

  @override
  String get systemDefault => 'System';

  @override
  String get spanish => 'Spanish (Peru)';

  @override
  String get english => 'English';

  @override
  String get appearance => 'Appearance';

  @override
  String get theme => 'Theme';

  @override
  String get lightTheme => 'Light';

  @override
  String get darkTheme => 'Dark';

  @override
  String get plannerPreferences => 'Trip preferences';

  @override
  String get maxWalking => 'Maximum walk to a stop';

  @override
  String get avoidTransfers => 'Avoid transfers';

  @override
  String get alarmType => 'Get-off alert';

  @override
  String get alarmSound => 'Sound';

  @override
  String get alarmVibration => 'Vibration';

  @override
  String get alarmOff => 'Off';

  @override
  String get offlineData => 'Offline data';

  @override
  String get checkUpdate => 'Check for updates';

  @override
  String get updatesLater =>
      'Data package updates will be available in a future release.';

  @override
  String get about => 'About';

  @override
  String get privacy => 'Privacy';

  @override
  String get terms => 'Terms';

  @override
  String get legalUnavailable =>
      'Legal documents will be available once published.';

  @override
  String get openLinkFailed => 'The link could not be opened.';

  @override
  String get osmAttribution => '© OpenStreetMap contributors · ODbL';

  @override
  String get openMapTilesAttribution => 'OpenMapTiles · offline mapping';

  @override
  String get emptyTitle => 'There are no items yet.';

  @override
  String get gpsOffTitle => 'Turn on device location';

  @override
  String get gpsOffBody => 'Turn on GPS to find nearby points.';

  @override
  String get permissionTitle => 'Location permission needed';

  @override
  String get permissionBody =>
      'You can allow location access or continue choosing trip points.';

  @override
  String get noResultsBody =>
      'Try another point or change your trip preferences.';

  @override
  String get outsideTitle => 'Outside the service area';

  @override
  String get outsideBody =>
      'The current data package contains Arequipa routes.';

  @override
  String get errorTitle => 'We could not load this information';

  @override
  String get errorBody => 'Please try again. Your saved data is preserved.';

  @override
  String towards(String destination) {
    return 'towards $destination';
  }

  @override
  String outboundTo(String destination) {
    return 'Outbound → $destination';
  }

  @override
  String inboundTo(String destination) {
    return 'Inbound → $destination';
  }

  @override
  String directionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count directions',
      one: '1 direction',
    );
    return '$_temp0';
  }

  @override
  String tripStats(int minutes, int transfers) {
    String _temp0 = intl.Intl.pluralLogic(
      transfers,
      locale: localeName,
      other: '$transfers transfers',
      one: '1 transfer',
    );
    return '~$minutes min · $_temp0';
  }

  @override
  String walkingLimit(int meters) {
    return 'Up to $meters m';
  }

  @override
  String automaticWalking(int initial, int fallback) {
    return 'Automatic ($initial–$fallback m)';
  }

  @override
  String dataVersion(int version) {
    return 'Data version: $version';
  }

  @override
  String dataBuiltAt(String date) {
    return 'Package built on $date';
  }
}
