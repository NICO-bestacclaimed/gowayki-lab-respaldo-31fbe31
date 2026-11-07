import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In es, this message translates to:
  /// **'GoWayki'**
  String get appTitle;

  /// No description provided for @explore.
  ///
  /// In es, this message translates to:
  /// **'Explorar'**
  String get explore;

  /// No description provided for @routes.
  ///
  /// In es, this message translates to:
  /// **'Rutas'**
  String get routes;

  /// No description provided for @favorites.
  ///
  /// In es, this message translates to:
  /// **'Favoritos'**
  String get favorites;

  /// No description provided for @profile.
  ///
  /// In es, this message translates to:
  /// **'Perfil'**
  String get profile;

  /// No description provided for @retry.
  ///
  /// In es, this message translates to:
  /// **'Reintentar'**
  String get retry;

  /// No description provided for @settings.
  ///
  /// In es, this message translates to:
  /// **'Ajustes'**
  String get settings;

  /// No description provided for @help.
  ///
  /// In es, this message translates to:
  /// **'Ayuda y comentarios'**
  String get help;

  /// No description provided for @signOut.
  ///
  /// In es, this message translates to:
  /// **'Cerrar sesión'**
  String get signOut;

  /// No description provided for @signIn.
  ///
  /// In es, this message translates to:
  /// **'Iniciar sesión'**
  String get signIn;

  /// No description provided for @guest.
  ///
  /// In es, this message translates to:
  /// **'Invitado'**
  String get guest;

  /// No description provided for @menu.
  ///
  /// In es, this message translates to:
  /// **'Menú'**
  String get menu;

  /// No description provided for @back.
  ///
  /// In es, this message translates to:
  /// **'Volver'**
  String get back;

  /// No description provided for @continueAction.
  ///
  /// In es, this message translates to:
  /// **'Continuar'**
  String get continueAction;

  /// No description provided for @bootstrapError.
  ///
  /// In es, this message translates to:
  /// **'No pudimos preparar los datos de Arequipa.'**
  String get bootstrapError;

  /// No description provided for @linesError.
  ///
  /// In es, this message translates to:
  /// **'No pudimos cargar las líneas.'**
  String get linesError;

  /// No description provided for @favoritesEmpty.
  ///
  /// In es, this message translates to:
  /// **'Aún no tienes líneas favoritas. Guarda una desde Rutas.'**
  String get favoritesEmpty;

  /// No description provided for @linesEmpty.
  ///
  /// In es, this message translates to:
  /// **'No hay líneas en el paquete actual.'**
  String get linesEmpty;

  /// No description provided for @removeFavorite.
  ///
  /// In es, this message translates to:
  /// **'Quitar de favoritos'**
  String get removeFavorite;

  /// No description provided for @addFavorite.
  ///
  /// In es, this message translates to:
  /// **'Guardar en favoritos'**
  String get addFavorite;

  /// No description provided for @saveFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo guardar el cambio. Inténtalo otra vez.'**
  String get saveFailed;

  /// No description provided for @noSession.
  ///
  /// In es, this message translates to:
  /// **'No hay sesión iniciada.'**
  String get noSession;

  /// No description provided for @localGuestHelp.
  ///
  /// In es, this message translates to:
  /// **'Puedes explorar rutas y guardar favoritos en este dispositivo.'**
  String get localGuestHelp;

  /// No description provided for @locationTitle.
  ///
  /// In es, this message translates to:
  /// **'Tu ubicación, tú decides'**
  String get locationTitle;

  /// No description provided for @locationExplanation.
  ///
  /// In es, this message translates to:
  /// **'GoWayki puede usar tu ubicación para sugerir puntos de subida cercanos y ayudarte a iniciar un viaje desde tu posición.'**
  String get locationExplanation;

  /// No description provided for @locationOptional.
  ///
  /// In es, this message translates to:
  /// **'El permiso es opcional. Puedes continuar sin ubicación.'**
  String get locationOptional;

  /// No description provided for @locationDenied.
  ///
  /// In es, this message translates to:
  /// **'El permiso no se concedió. Puedes continuar y cambiarlo más adelante.'**
  String get locationDenied;

  /// No description provided for @locationPermanent.
  ///
  /// In es, this message translates to:
  /// **'El permiso está desactivado en los ajustes de la aplicación.'**
  String get locationPermanent;

  /// No description provided for @openSettings.
  ///
  /// In es, this message translates to:
  /// **'Abrir ajustes'**
  String get openSettings;

  /// No description provided for @waitMoment.
  ///
  /// In es, this message translates to:
  /// **'Un momento…'**
  String get waitMoment;

  /// No description provided for @allowLocation.
  ///
  /// In es, this message translates to:
  /// **'Permitir ubicación'**
  String get allowLocation;

  /// No description provided for @continueWithoutLocation.
  ///
  /// In es, this message translates to:
  /// **'Continuar sin ubicación'**
  String get continueWithoutLocation;

  /// No description provided for @continueFailed.
  ///
  /// In es, this message translates to:
  /// **'No pudimos continuar. Inténtalo otra vez.'**
  String get continueFailed;

  /// No description provided for @permissionFailed.
  ///
  /// In es, this message translates to:
  /// **'No pudimos solicitar el permiso. Puedes continuar sin ubicación.'**
  String get permissionFailed;

  /// No description provided for @permissionSettingsHelp.
  ///
  /// In es, this message translates to:
  /// **'Abre los ajustes de la aplicación para cambiar el permiso.'**
  String get permissionSettingsHelp;

  /// No description provided for @deviceSettingsHelp.
  ///
  /// In es, this message translates to:
  /// **'Puedes cambiar el permiso desde los ajustes del dispositivo.'**
  String get deviceSettingsHelp;

  /// No description provided for @onboardFind.
  ///
  /// In es, this message translates to:
  /// **'Encuentra tu combi'**
  String get onboardFind;

  /// No description provided for @onboardFindBody.
  ///
  /// In es, this message translates to:
  /// **'Explora las líneas de Arequipa y reconoce tu micro.'**
  String get onboardFindBody;

  /// No description provided for @onboardAlight.
  ///
  /// In es, this message translates to:
  /// **'Sabe dónde bajar'**
  String get onboardAlight;

  /// No description provided for @onboardAlightBody.
  ///
  /// In es, this message translates to:
  /// **'Consulta los puntos del recorrido y los transbordos de tu viaje.'**
  String get onboardAlightBody;

  /// No description provided for @onboardTime.
  ///
  /// In es, this message translates to:
  /// **'Llega a tiempo (tiempos estimados)'**
  String get onboardTime;

  /// No description provided for @onboardTimeBody.
  ///
  /// In es, this message translates to:
  /// **'Compara alternativas con tiempos aproximados de caminata, espera y viaje.'**
  String get onboardTimeBody;

  /// No description provided for @skip.
  ///
  /// In es, this message translates to:
  /// **'Omitir'**
  String get skip;

  /// No description provided for @start.
  ///
  /// In es, this message translates to:
  /// **'Comenzar'**
  String get start;

  /// No description provided for @next.
  ///
  /// In es, this message translates to:
  /// **'Siguiente'**
  String get next;

  /// No description provided for @preparing.
  ///
  /// In es, this message translates to:
  /// **'Preparando Arequipa…'**
  String get preparing;

  /// No description provided for @line.
  ///
  /// In es, this message translates to:
  /// **'Línea'**
  String get line;

  /// No description provided for @allDirections.
  ///
  /// In es, this message translates to:
  /// **'Todas'**
  String get allDirections;

  /// No description provided for @outbound.
  ///
  /// In es, this message translates to:
  /// **'Ida'**
  String get outbound;

  /// No description provided for @inbound.
  ///
  /// In es, this message translates to:
  /// **'Vuelta'**
  String get inbound;

  /// No description provided for @whereTo.
  ///
  /// In es, this message translates to:
  /// **'¿Adónde vas?'**
  String get whereTo;

  /// No description provided for @searchExamples.
  ///
  /// In es, this message translates to:
  /// **'Prueba “TECSUP”, “Plaza” o “Mall”'**
  String get searchExamples;

  /// No description provided for @directions.
  ///
  /// In es, this message translates to:
  /// **'Cómo llegar'**
  String get directions;

  /// No description provided for @buses.
  ///
  /// In es, this message translates to:
  /// **'Combis'**
  String get buses;

  /// No description provided for @searchLine.
  ///
  /// In es, this message translates to:
  /// **'Buscar línea o combi…'**
  String get searchLine;

  /// No description provided for @noResults.
  ///
  /// In es, this message translates to:
  /// **'Sin resultados'**
  String get noResults;

  /// No description provided for @mapError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo cargar el mapa sin conexión.'**
  String get mapError;

  /// No description provided for @feedbackMinimum.
  ///
  /// In es, this message translates to:
  /// **'Escribe al menos 5 caracteres'**
  String get feedbackMinimum;

  /// No description provided for @feedbackSent.
  ///
  /// In es, this message translates to:
  /// **'Gracias. Comentario enviado.'**
  String get feedbackSent;

  /// No description provided for @feedbackBug.
  ///
  /// In es, this message translates to:
  /// **'Bug'**
  String get feedbackBug;

  /// No description provided for @feedbackIdea.
  ///
  /// In es, this message translates to:
  /// **'Idea'**
  String get feedbackIdea;

  /// No description provided for @feedbackOther.
  ///
  /// In es, this message translates to:
  /// **'Otro'**
  String get feedbackOther;

  /// No description provided for @message.
  ///
  /// In es, this message translates to:
  /// **'Mensaje'**
  String get message;

  /// No description provided for @send.
  ///
  /// In es, this message translates to:
  /// **'Enviar'**
  String get send;

  /// No description provided for @genericError.
  ///
  /// In es, this message translates to:
  /// **'No pudimos completar la acción. Inténtalo otra vez.'**
  String get genericError;

  /// No description provided for @planTrip.
  ///
  /// In es, this message translates to:
  /// **'Planificar viaje'**
  String get planTrip;

  /// No description provided for @demoOptions.
  ///
  /// In es, this message translates to:
  /// **'Opciones de demostración'**
  String get demoOptions;

  /// No description provided for @demoOrigin.
  ///
  /// In es, this message translates to:
  /// **'Origen de demostración'**
  String get demoOrigin;

  /// No description provided for @brandTagline.
  ///
  /// In es, this message translates to:
  /// **'Tu ciudad, más cerca'**
  String get brandTagline;

  /// No description provided for @email.
  ///
  /// In es, this message translates to:
  /// **'Correo'**
  String get email;

  /// No description provided for @password.
  ///
  /// In es, this message translates to:
  /// **'Contraseña'**
  String get password;

  /// No description provided for @createAccount.
  ///
  /// In es, this message translates to:
  /// **'Crear cuenta'**
  String get createAccount;

  /// No description provided for @guestEntry.
  ///
  /// In es, this message translates to:
  /// **'Entrar como invitado'**
  String get guestEntry;

  /// No description provided for @firebaseActive.
  ///
  /// In es, this message translates to:
  /// **'Firebase Auth activo'**
  String get firebaseActive;

  /// No description provided for @localDemo.
  ///
  /// In es, this message translates to:
  /// **'Modo demo · sin Firebase'**
  String get localDemo;

  /// No description provided for @pageUnavailable.
  ///
  /// In es, this message translates to:
  /// **'Esta página no está disponible.'**
  String get pageUnavailable;

  /// No description provided for @backExplore.
  ///
  /// In es, this message translates to:
  /// **'Volver a Explorar'**
  String get backExplore;

  /// No description provided for @chooseDestination.
  ///
  /// In es, this message translates to:
  /// **'Selecciona un destino desde Explorar.'**
  String get chooseDestination;

  /// No description provided for @city.
  ///
  /// In es, this message translates to:
  /// **'Ciudad'**
  String get city;

  /// No description provided for @activeCity.
  ///
  /// In es, this message translates to:
  /// **'Ciudad activa'**
  String get activeCity;

  /// No description provided for @language.
  ///
  /// In es, this message translates to:
  /// **'Idioma'**
  String get language;

  /// No description provided for @systemDefault.
  ///
  /// In es, this message translates to:
  /// **'Sistema'**
  String get systemDefault;

  /// No description provided for @spanish.
  ///
  /// In es, this message translates to:
  /// **'Español (Perú)'**
  String get spanish;

  /// No description provided for @english.
  ///
  /// In es, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @appearance.
  ///
  /// In es, this message translates to:
  /// **'Apariencia'**
  String get appearance;

  /// No description provided for @theme.
  ///
  /// In es, this message translates to:
  /// **'Tema'**
  String get theme;

  /// No description provided for @lightTheme.
  ///
  /// In es, this message translates to:
  /// **'Claro'**
  String get lightTheme;

  /// No description provided for @darkTheme.
  ///
  /// In es, this message translates to:
  /// **'Oscuro'**
  String get darkTheme;

  /// No description provided for @plannerPreferences.
  ///
  /// In es, this message translates to:
  /// **'Preferencias de viaje'**
  String get plannerPreferences;

  /// No description provided for @maxWalking.
  ///
  /// In es, this message translates to:
  /// **'Caminata máxima hasta un paradero'**
  String get maxWalking;

  /// No description provided for @avoidTransfers.
  ///
  /// In es, this message translates to:
  /// **'Evitar transbordos'**
  String get avoidTransfers;

  /// No description provided for @alarmType.
  ///
  /// In es, this message translates to:
  /// **'Aviso de bajada'**
  String get alarmType;

  /// No description provided for @alarmSound.
  ///
  /// In es, this message translates to:
  /// **'Sonido'**
  String get alarmSound;

  /// No description provided for @alarmVibration.
  ///
  /// In es, this message translates to:
  /// **'Vibración'**
  String get alarmVibration;

  /// No description provided for @alarmOff.
  ///
  /// In es, this message translates to:
  /// **'Desactivado'**
  String get alarmOff;

  /// No description provided for @offlineData.
  ///
  /// In es, this message translates to:
  /// **'Datos sin conexión'**
  String get offlineData;

  /// No description provided for @checkUpdate.
  ///
  /// In es, this message translates to:
  /// **'Buscar actualización'**
  String get checkUpdate;

  /// No description provided for @updatesLater.
  ///
  /// In es, this message translates to:
  /// **'Las actualizaciones del paquete estarán disponibles próximamente.'**
  String get updatesLater;

  /// No description provided for @about.
  ///
  /// In es, this message translates to:
  /// **'Acerca de'**
  String get about;

  /// No description provided for @privacy.
  ///
  /// In es, this message translates to:
  /// **'Privacidad'**
  String get privacy;

  /// No description provided for @terms.
  ///
  /// In es, this message translates to:
  /// **'Términos'**
  String get terms;

  /// No description provided for @legalUnavailable.
  ///
  /// In es, this message translates to:
  /// **'Los documentos legales estarán disponibles cuando se publiquen.'**
  String get legalUnavailable;

  /// No description provided for @openLinkFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo abrir el enlace.'**
  String get openLinkFailed;

  /// No description provided for @osmAttribution.
  ///
  /// In es, this message translates to:
  /// **'© Colaboradores de OpenStreetMap · ODbL'**
  String get osmAttribution;

  /// No description provided for @openMapTilesAttribution.
  ///
  /// In es, this message translates to:
  /// **'OpenMapTiles · cartografía sin conexión'**
  String get openMapTilesAttribution;

  /// No description provided for @emptyTitle.
  ///
  /// In es, this message translates to:
  /// **'Todavía no hay elementos.'**
  String get emptyTitle;

  /// No description provided for @gpsOffTitle.
  ///
  /// In es, this message translates to:
  /// **'Activa la ubicación del dispositivo'**
  String get gpsOffTitle;

  /// No description provided for @gpsOffBody.
  ///
  /// In es, this message translates to:
  /// **'Activa el GPS para encontrar puntos cercanos.'**
  String get gpsOffBody;

  /// No description provided for @permissionTitle.
  ///
  /// In es, this message translates to:
  /// **'Permiso de ubicación necesario'**
  String get permissionTitle;

  /// No description provided for @permissionBody.
  ///
  /// In es, this message translates to:
  /// **'Puedes permitir la ubicación o continuar eligiendo los puntos del viaje.'**
  String get permissionBody;

  /// No description provided for @noResultsBody.
  ///
  /// In es, this message translates to:
  /// **'Prueba con otro punto o cambia las preferencias del viaje.'**
  String get noResultsBody;

  /// No description provided for @outsideTitle.
  ///
  /// In es, this message translates to:
  /// **'Fuera del área de servicio'**
  String get outsideTitle;

  /// No description provided for @outsideBody.
  ///
  /// In es, this message translates to:
  /// **'El paquete actual contiene rutas de Arequipa.'**
  String get outsideBody;

  /// No description provided for @errorTitle.
  ///
  /// In es, this message translates to:
  /// **'No pudimos cargar la información'**
  String get errorTitle;

  /// No description provided for @errorBody.
  ///
  /// In es, this message translates to:
  /// **'Inténtalo otra vez. Tus datos guardados se conservan.'**
  String get errorBody;

  /// No description provided for @towards.
  ///
  /// In es, this message translates to:
  /// **'hacia {destination}'**
  String towards(String destination);

  /// No description provided for @outboundTo.
  ///
  /// In es, this message translates to:
  /// **'Ida → {destination}'**
  String outboundTo(String destination);

  /// No description provided for @inboundTo.
  ///
  /// In es, this message translates to:
  /// **'Vuelta → {destination}'**
  String inboundTo(String destination);

  /// No description provided for @directionCount.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, one {1 sentido} other {{count} sentidos}}'**
  String directionCount(int count);

  /// No description provided for @tripStats.
  ///
  /// In es, this message translates to:
  /// **'~{minutes} min · {transfers, plural, one {1 transbordo} other {{transfers} transbordos}}'**
  String tripStats(int minutes, int transfers);

  /// No description provided for @walkingLimit.
  ///
  /// In es, this message translates to:
  /// **'Hasta {meters} m'**
  String walkingLimit(int meters);

  /// No description provided for @automaticWalking.
  ///
  /// In es, this message translates to:
  /// **'Automático ({initial}–{fallback} m)'**
  String automaticWalking(int initial, int fallback);

  /// No description provided for @dataVersion.
  ///
  /// In es, this message translates to:
  /// **'Versión de datos: {version}'**
  String dataVersion(int version);

  /// No description provided for @dataBuiltAt.
  ///
  /// In es, this message translates to:
  /// **'Paquete compilado el {date}'**
  String dataBuiltAt(String date);

  /// No description provided for @nearbyStops.
  ///
  /// In es, this message translates to:
  /// **'Paraderos cerca de ti'**
  String get nearbyStops;

  /// No description provided for @estimatedName.
  ///
  /// In es, this message translates to:
  /// **'Nombre estimado · pendiente de revisión'**
  String get estimatedName;

  /// No description provided for @home.
  ///
  /// In es, this message translates to:
  /// **'Casa'**
  String get home;

  /// No description provided for @work.
  ///
  /// In es, this message translates to:
  /// **'Trabajo'**
  String get work;

  /// No description provided for @goHere.
  ///
  /// In es, this message translates to:
  /// **'Ir aquí'**
  String get goHere;

  /// No description provided for @leaveHere.
  ///
  /// In es, this message translates to:
  /// **'Salir desde aquí'**
  String get leaveHere;

  /// No description provided for @selectedPoint.
  ///
  /// In es, this message translates to:
  /// **'Punto elegido en el mapa'**
  String get selectedPoint;

  /// No description provided for @origin.
  ///
  /// In es, this message translates to:
  /// **'Origen'**
  String get origin;

  /// No description provided for @destination.
  ///
  /// In es, this message translates to:
  /// **'Destino'**
  String get destination;

  /// No description provided for @choosePoints.
  ///
  /// In es, this message translates to:
  /// **'Elegir puntos del viaje'**
  String get choosePoints;

  /// No description provided for @usePoints.
  ///
  /// In es, this message translates to:
  /// **'Usar estos puntos'**
  String get usePoints;

  /// No description provided for @swapPoints.
  ///
  /// In es, this message translates to:
  /// **'Intercambiar origen y destino'**
  String get swapPoints;

  /// No description provided for @myLocation.
  ///
  /// In es, this message translates to:
  /// **'Mi ubicación'**
  String get myLocation;

  /// No description provided for @recent.
  ///
  /// In es, this message translates to:
  /// **'Recientes'**
  String get recent;

  /// No description provided for @places.
  ///
  /// In es, this message translates to:
  /// **'Lugares'**
  String get places;

  /// No description provided for @stops.
  ///
  /// In es, this message translates to:
  /// **'Paraderos'**
  String get stops;

  /// No description provided for @streets.
  ///
  /// In es, this message translates to:
  /// **'Calles'**
  String get streets;

  /// No description provided for @chooseStop.
  ///
  /// In es, this message translates to:
  /// **'Selecciona un paradero de esta línea'**
  String get chooseStop;

  /// No description provided for @showRoutes.
  ///
  /// In es, this message translates to:
  /// **'Mostrar rutas'**
  String get showRoutes;

  /// No description provided for @hideRoutes.
  ///
  /// In es, this message translates to:
  /// **'Ocultar rutas'**
  String get hideRoutes;

  /// No description provided for @approxWalk.
  ///
  /// In es, this message translates to:
  /// **'~{meters} m a pie'**
  String approxWalk(int meters);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
