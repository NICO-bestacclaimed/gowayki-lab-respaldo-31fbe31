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
  /// **'Escribe al menos 3 caracteres.'**
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

  /// No description provided for @leaveNow.
  ///
  /// In es, this message translates to:
  /// **'Salir ahora'**
  String get leaveNow;

  /// No description provided for @leaveAt.
  ///
  /// In es, this message translates to:
  /// **'Salir a una hora'**
  String get leaveAt;

  /// No description provided for @arriveBy.
  ///
  /// In es, this message translates to:
  /// **'Llegar antes de una hora'**
  String get arriveBy;

  /// No description provided for @fastest.
  ///
  /// In es, this message translates to:
  /// **'Más rápida'**
  String get fastest;

  /// No description provided for @fewestTransfers.
  ///
  /// In es, this message translates to:
  /// **'Menos transbordos'**
  String get fewestTransfers;

  /// No description provided for @leastWalking.
  ///
  /// In es, this message translates to:
  /// **'Menos caminata'**
  String get leastWalking;

  /// No description provided for @noTransfers.
  ///
  /// In es, this message translates to:
  /// **'Sin transbordo'**
  String get noTransfers;

  /// No description provided for @noService.
  ///
  /// In es, this message translates to:
  /// **'Sin servicio en la hora elegida'**
  String get noService;

  /// No description provided for @walkOnly.
  ///
  /// In es, this message translates to:
  /// **'Alternativa a pie'**
  String get walkOnly;

  /// No description provided for @walkingEstimate.
  ///
  /// In es, this message translates to:
  /// **'Caminata aproximada · trazado orientativo'**
  String get walkingEstimate;

  /// No description provided for @details.
  ///
  /// In es, this message translates to:
  /// **'Ver detalle'**
  String get details;

  /// No description provided for @saveTrip.
  ///
  /// In es, this message translates to:
  /// **'Guardar viaje'**
  String get saveTrip;

  /// No description provided for @share.
  ///
  /// In es, this message translates to:
  /// **'Compartir'**
  String get share;

  /// No description provided for @startTrip.
  ///
  /// In es, this message translates to:
  /// **'Iniciar viaje'**
  String get startTrip;

  /// No description provided for @intermediateStops.
  ///
  /// In es, this message translates to:
  /// **'Paraderos intermedios'**
  String get intermediateStops;

  /// No description provided for @estimatedTimes.
  ///
  /// In es, this message translates to:
  /// **'Todos los tiempos son estimados'**
  String get estimatedTimes;

  /// No description provided for @optionNumber.
  ///
  /// In es, this message translates to:
  /// **'Opción {number}'**
  String optionNumber(int number);

  /// No description provided for @minutesApprox.
  ///
  /// In es, this message translates to:
  /// **'~{minutes} min'**
  String minutesApprox(int minutes);

  /// No description provided for @walkingMinutes.
  ///
  /// In es, this message translates to:
  /// **'Caminata: ~{minutes} min'**
  String walkingMinutes(int minutes);

  /// No description provided for @waitingMinutes.
  ///
  /// In es, this message translates to:
  /// **'Espera: ~{minutes} min'**
  String waitingMinutes(int minutes);

  /// No description provided for @transferNumber.
  ///
  /// In es, this message translates to:
  /// **'{count} transbordos'**
  String transferNumber(int count);

  /// No description provided for @fareAmount.
  ///
  /// In es, this message translates to:
  /// **'Tarifa estimada: S/ {amount}'**
  String fareAmount(String amount);

  /// No description provided for @walkInstruction.
  ///
  /// In es, this message translates to:
  /// **'Camina ~{meters} m (~{minutes} min) hasta {destination}'**
  String walkInstruction(int meters, int minutes, String destination);

  /// No description provided for @boardInstruction.
  ///
  /// In es, this message translates to:
  /// **'Toma {line} hacia {destination}'**
  String boardInstruction(String line, String destination);

  /// No description provided for @frequencyApprox.
  ///
  /// In es, this message translates to:
  /// **'Pasa cada ~{minutes} min'**
  String frequencyApprox(int minutes);

  /// No description provided for @rideInstruction.
  ///
  /// In es, this message translates to:
  /// **'Viaja {stops} paraderos (~{minutes} min) y baja en {destination}'**
  String rideInstruction(int stops, int minutes, String destination);

  /// No description provided for @waitInstruction.
  ///
  /// In es, this message translates to:
  /// **'Espera estimada: ~{minutes} min'**
  String waitInstruction(int minutes);

  /// No description provided for @bandHoldInstruction.
  ///
  /// In es, this message translates to:
  /// **'Espera adicional por cambio de franja: ~{minutes} min'**
  String bandHoldInstruction(int minutes);

  /// No description provided for @removeSavedTrip.
  ///
  /// In es, this message translates to:
  /// **'Quitar viaje guardado'**
  String get removeSavedTrip;

  /// No description provided for @nearMe.
  ///
  /// In es, this message translates to:
  /// **'Pasan cerca de mí'**
  String get nearMe;

  /// No description provided for @directionSelector.
  ///
  /// In es, this message translates to:
  /// **'Sentido'**
  String get directionSelector;

  /// No description provided for @configureHome.
  ///
  /// In es, this message translates to:
  /// **'Configurar Casa'**
  String get configureHome;

  /// No description provided for @configureWork.
  ///
  /// In es, this message translates to:
  /// **'Configurar Trabajo'**
  String get configureWork;

  /// No description provided for @savedTrips.
  ///
  /// In es, this message translates to:
  /// **'Viajes guardados'**
  String get savedTrips;

  /// No description provided for @savedPlaces.
  ///
  /// In es, this message translates to:
  /// **'Lugares guardados'**
  String get savedPlaces;

  /// No description provided for @delete.
  ///
  /// In es, this message translates to:
  /// **'Borrar'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In es, this message translates to:
  /// **'Editar'**
  String get edit;

  /// No description provided for @favoriteStops.
  ///
  /// In es, this message translates to:
  /// **'Paraderos favoritos'**
  String get favoriteStops;

  /// No description provided for @unset.
  ///
  /// In es, this message translates to:
  /// **'Sin configurar'**
  String get unset;

  /// No description provided for @saved.
  ///
  /// In es, this message translates to:
  /// **'Guardados'**
  String get saved;

  /// No description provided for @savedTripNote.
  ///
  /// In es, this message translates to:
  /// **'Los viajes guardados se recalculan al abrirlos.'**
  String get savedTripNote;

  /// No description provided for @activeTrip.
  ///
  /// In es, this message translates to:
  /// **'Viaje en curso'**
  String get activeTrip;

  /// No description provided for @noActiveTrip.
  ///
  /// In es, this message translates to:
  /// **'No hay un viaje activo.'**
  String get noActiveTrip;

  /// No description provided for @tripNotificationBody.
  ///
  /// In es, this message translates to:
  /// **'Ubicación activa hasta llegar o tocar Terminar. Toca para volver a GoWayki.'**
  String get tripNotificationBody;

  /// No description provided for @alightAlertTitle.
  ///
  /// In es, this message translates to:
  /// **'GoWayki · Prepárate para bajar'**
  String get alightAlertTitle;

  /// No description provided for @alightAlertBody.
  ///
  /// In es, this message translates to:
  /// **'Bájate en el próximo paradero: {name}'**
  String alightAlertBody(String name);

  /// No description provided for @transferAlertTitle.
  ///
  /// In es, this message translates to:
  /// **'GoWayki · Zona de transbordo'**
  String get transferAlertTitle;

  /// No description provided for @transferAlertBody.
  ///
  /// In es, this message translates to:
  /// **'Llegaste a {name}. Revisa el siguiente tramo antes de subir.'**
  String transferAlertBody(String name);

  /// No description provided for @tripCompleted.
  ///
  /// In es, this message translates to:
  /// **'Llegaste a tu destino. Seguimiento terminado.'**
  String get tripCompleted;

  /// No description provided for @tripStopped.
  ///
  /// In es, this message translates to:
  /// **'Seguimiento terminado.'**
  String get tripStopped;

  /// No description provided for @tripTrackingFailed.
  ///
  /// In es, this message translates to:
  /// **'El seguimiento se detuvo. Revisa el GPS y los permisos antes de iniciar otro viaje.'**
  String get tripTrackingFailed;

  /// No description provided for @activeWalk.
  ///
  /// In es, this message translates to:
  /// **'Camina al siguiente punto'**
  String get activeWalk;

  /// No description provided for @activeBoard.
  ///
  /// In es, this message translates to:
  /// **'Espera y sube a {name}'**
  String activeBoard(String name);

  /// No description provided for @activeRide.
  ///
  /// In es, this message translates to:
  /// **'Continúa en {name}'**
  String activeRide(String name);

  /// No description provided for @alightAt.
  ///
  /// In es, this message translates to:
  /// **'Baja en: {name}'**
  String alightAt(String name);

  /// No description provided for @activeDistance.
  ///
  /// In es, this message translates to:
  /// **'Distancia aproximada al siguiente punto: ~{meters} m'**
  String activeDistance(String meters);

  /// No description provided for @remainingStops.
  ///
  /// In es, this message translates to:
  /// **'Paraderos restantes: ~{count}'**
  String remainingStops(int count);

  /// No description provided for @tripLocationUncertain.
  ///
  /// In es, this message translates to:
  /// **'Esperando una ubicación reciente y precisa. La distancia y las alertas pueden no estar disponibles.'**
  String get tripLocationUncertain;

  /// No description provided for @tripAlertFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo emitir una alerta. Revisa las notificaciones del sistema.'**
  String get tripAlertFailed;

  /// No description provided for @confirmBoarded.
  ///
  /// In es, this message translates to:
  /// **'Ya subí'**
  String get confirmBoarded;

  /// No description provided for @confirmAlighted.
  ///
  /// In es, this message translates to:
  /// **'Ya bajé'**
  String get confirmAlighted;

  /// No description provided for @confirmArrived.
  ///
  /// In es, this message translates to:
  /// **'Ya llegué a este punto'**
  String get confirmArrived;

  /// No description provided for @manualStepNote.
  ///
  /// In es, this message translates to:
  /// **'Confirma solo cuando hayas completado el paso. El GPS aproxima tu posición; no detecta el vehículo.'**
  String get manualStepNote;

  /// No description provided for @endTrip.
  ///
  /// In es, this message translates to:
  /// **'Terminar viaje'**
  String get endTrip;

  /// No description provided for @tripPermissionDisclosure.
  ///
  /// In es, this message translates to:
  /// **'Usaremos tu ubicación durante este viaje para indicar el paso actual y avisarte dónde bajar, también al minimizar la app. Android mostrará una notificación persistente. Te pediremos ubicación y notificaciones; el seguimiento termina al llegar, tocar Terminar o cerrar la app desde el sistema. Las alertas son aproximadas y dependen del GPS y de tus ajustes de sonido.'**
  String get tripPermissionDisclosure;

  /// No description provided for @tripPermissionRequired.
  ///
  /// In es, this message translates to:
  /// **'Permite la ubicación para iniciar el viaje.'**
  String get tripPermissionRequired;

  /// No description provided for @tripNotificationsRequired.
  ///
  /// In es, this message translates to:
  /// **'Activa las notificaciones de GoWayki en los ajustes del sistema para iniciar el seguimiento.'**
  String get tripNotificationsRequired;

  /// No description provided for @tripStartVisible.
  ///
  /// In es, this message translates to:
  /// **'Vuelve a GoWayki y toca Iniciar viaje para activar el seguimiento.'**
  String get tripStartVisible;

  /// No description provided for @cancelTripStart.
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get cancelTripStart;

  /// No description provided for @gameSaveFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo guardar el récord o el ajuste del juego.'**
  String get gameSaveFailed;

  /// No description provided for @gameMobileOnly.
  ///
  /// In es, this message translates to:
  /// **'La integración del juego está disponible en Android/iOS. En Windows abre assets/game/index.html en tu navegador.'**
  String get gameMobileOnly;

  /// No description provided for @gameLoadFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo abrir el juego local. Inténtalo de nuevo.'**
  String get gameLoadFailed;

  /// No description provided for @gameBest.
  ///
  /// In es, this message translates to:
  /// **'Récord local: {score} pts'**
  String gameBest(int score);

  /// No description provided for @gameWhileWaiting.
  ///
  /// In es, this message translates to:
  /// **'¿Esperando tu combi? Juega'**
  String get gameWhileWaiting;

  /// No description provided for @authInvalidCredentials.
  ///
  /// In es, this message translates to:
  /// **'Revisa tu correo y contraseña e inténtalo de nuevo.'**
  String get authInvalidCredentials;

  /// No description provided for @authInvalidEmail.
  ///
  /// In es, this message translates to:
  /// **'Escribe un correo válido.'**
  String get authInvalidEmail;

  /// No description provided for @authWeakPassword.
  ///
  /// In es, this message translates to:
  /// **'La contraseña no cumple los requisitos de seguridad. Prueba una más segura.'**
  String get authWeakPassword;

  /// No description provided for @authEmailInUse.
  ///
  /// In es, this message translates to:
  /// **'Ese correo ya tiene una cuenta. Inicia sesión para continuar.'**
  String get authEmailInUse;

  /// No description provided for @authDisabled.
  ///
  /// In es, this message translates to:
  /// **'Esta cuenta está deshabilitada. Contacta con el equipo de GoWayki.'**
  String get authDisabled;

  /// No description provided for @authMethodUnavailable.
  ///
  /// In es, this message translates to:
  /// **'Este método de acceso no está disponible. Prueba otro o continúa como invitado.'**
  String get authMethodUnavailable;

  /// No description provided for @authNetwork.
  ///
  /// In es, this message translates to:
  /// **'No pudimos conectar. Revisa tu conexión e inténtalo de nuevo.'**
  String get authNetwork;

  /// No description provided for @authTooMany.
  ///
  /// In es, this message translates to:
  /// **'Hubo demasiados intentos. Espera un momento antes de volver a probar.'**
  String get authTooMany;

  /// No description provided for @authDifferentProvider.
  ///
  /// In es, this message translates to:
  /// **'Usa el método con el que registraste esa cuenta.'**
  String get authDifferentProvider;

  /// No description provided for @authLocalHelp.
  ///
  /// In es, this message translates to:
  /// **'Continúa sin cuenta. Tus favoritos y viajes se guardarán en este dispositivo.'**
  String get authLocalHelp;

  /// No description provided for @authProfileWarning.
  ///
  /// In es, this message translates to:
  /// **'Tu cuenta está creada; no se pudo guardar el nombre. Puedes seguir usando GoWayki.'**
  String get authProfileWarning;

  /// No description provided for @authResetSent.
  ///
  /// In es, this message translates to:
  /// **'Si existe una cuenta con ese correo, recibirás instrucciones para cambiar tu contraseña. Revisa también el correo no deseado.'**
  String get authResetSent;

  /// No description provided for @authAccountHelp.
  ///
  /// In es, this message translates to:
  /// **'Usa tu cuenta o continúa como invitado. Puedes planificar rutas sin iniciar sesión.'**
  String get authAccountHelp;

  /// No description provided for @authName.
  ///
  /// In es, this message translates to:
  /// **'Tu nombre'**
  String get authName;

  /// No description provided for @authNameInvalid.
  ///
  /// In es, this message translates to:
  /// **'Escribe entre 2 y 60 caracteres.'**
  String get authNameInvalid;

  /// No description provided for @authShowPassword.
  ///
  /// In es, this message translates to:
  /// **'Mostrar contraseña'**
  String get authShowPassword;

  /// No description provided for @authHidePassword.
  ///
  /// In es, this message translates to:
  /// **'Ocultar contraseña'**
  String get authHidePassword;

  /// No description provided for @authPasswordRequired.
  ///
  /// In es, this message translates to:
  /// **'Escribe tu contraseña.'**
  String get authPasswordRequired;

  /// No description provided for @authPasswordLength.
  ///
  /// In es, this message translates to:
  /// **'Usa entre 8 y 128 caracteres al crear tu cuenta.'**
  String get authPasswordLength;

  /// No description provided for @authConfirmPassword.
  ///
  /// In es, this message translates to:
  /// **'Confirma tu contraseña'**
  String get authConfirmPassword;

  /// No description provided for @authPasswordsDiffer.
  ///
  /// In es, this message translates to:
  /// **'Las contraseñas no coinciden.'**
  String get authPasswordsDiffer;

  /// No description provided for @authHaveAccount.
  ///
  /// In es, this message translates to:
  /// **'Ya tengo una cuenta'**
  String get authHaveAccount;

  /// No description provided for @authForgotPassword.
  ///
  /// In es, this message translates to:
  /// **'¿Olvidaste tu contraseña?'**
  String get authForgotPassword;

  /// No description provided for @authGoogle.
  ///
  /// In es, this message translates to:
  /// **'Continuar con Google'**
  String get authGoogle;

  /// No description provided for @authUpgrade.
  ///
  /// In es, this message translates to:
  /// **'Conectar o crear mi cuenta'**
  String get authUpgrade;

  /// No description provided for @syncTitle.
  ///
  /// In es, this message translates to:
  /// **'Tus datos'**
  String get syncTitle;

  /// No description provided for @syncLocal.
  ///
  /// In es, this message translates to:
  /// **'Guardados en este equipo.'**
  String get syncLocal;

  /// No description provided for @syncNeedsSession.
  ///
  /// In es, this message translates to:
  /// **'Inicia sesión para sincronizar tus favoritos y viajes.'**
  String get syncNeedsSession;

  /// No description provided for @syncWaiting.
  ///
  /// In es, this message translates to:
  /// **'Guardados en este equipo. Esperando sincronización…'**
  String get syncWaiting;

  /// No description provided for @syncWorking.
  ///
  /// In es, this message translates to:
  /// **'Sincronizando…'**
  String get syncWorking;

  /// No description provided for @syncDone.
  ///
  /// In es, this message translates to:
  /// **'Sincronizados con tu cuenta.'**
  String get syncDone;

  /// No description provided for @syncUnavailable.
  ///
  /// In es, this message translates to:
  /// **'Guardados en este equipo. No se pudo sincronizar.'**
  String get syncUnavailable;

  /// No description provided for @syncRetry.
  ///
  /// In es, this message translates to:
  /// **'Reintentar sincronización'**
  String get syncRetry;

  /// No description provided for @communityReports.
  ///
  /// In es, this message translates to:
  /// **'Reportes de la comunidad'**
  String get communityReports;

  /// No description provided for @communityLoading.
  ///
  /// In es, this message translates to:
  /// **'Cargando…'**
  String get communityLoading;

  /// No description provided for @communityUnavailable.
  ///
  /// In es, this message translates to:
  /// **'No se pudieron actualizar los reportes.'**
  String get communityUnavailable;

  /// No description provided for @communityCached.
  ///
  /// In es, this message translates to:
  /// **'Sin conexión: los reportes guardados pueden no estar actualizados.'**
  String get communityCached;

  /// No description provided for @communityError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo confirmar el envío. Conservamos el texto para que vuelvas a intentarlo.'**
  String get communityError;

  /// No description provided for @communityLocalOnly.
  ///
  /// In es, this message translates to:
  /// **'El envío de reportes y comentarios no está habilitado en esta versión.'**
  String get communityLocalOnly;

  /// No description provided for @reportProblem.
  ///
  /// In es, this message translates to:
  /// **'Reportar problema'**
  String get reportProblem;

  /// No description provided for @reportType.
  ///
  /// In es, this message translates to:
  /// **'Tipo de problema'**
  String get reportType;

  /// No description provided for @reportDetour.
  ///
  /// In es, this message translates to:
  /// **'Desvío'**
  String get reportDetour;

  /// No description provided for @reportMissingStop.
  ///
  /// In es, this message translates to:
  /// **'El paradero no existe'**
  String get reportMissingStop;

  /// No description provided for @reportStopName.
  ///
  /// In es, this message translates to:
  /// **'Nombre del paradero incorrecto o ausente'**
  String get reportStopName;

  /// No description provided for @reportLineMissing.
  ///
  /// In es, this message translates to:
  /// **'La línea ya no pasa'**
  String get reportLineMissing;

  /// No description provided for @reportNeedsAccount.
  ///
  /// In es, this message translates to:
  /// **'Inicia sesión con una cuenta de correo o Google para reportar y confirmar.'**
  String get reportNeedsAccount;

  /// No description provided for @reportExpired.
  ///
  /// In es, this message translates to:
  /// **'Este reporte ya venció o fue eliminado.'**
  String get reportExpired;

  /// No description provided for @reportNone.
  ///
  /// In es, this message translates to:
  /// **'No hay reportes vigentes para esta ubicación.'**
  String get reportNone;

  /// No description provided for @reportConfirm.
  ///
  /// In es, this message translates to:
  /// **'👍 Sigue así'**
  String get reportConfirm;

  /// No description provided for @reportConfirmed.
  ///
  /// In es, this message translates to:
  /// **'Confirmación guardada.'**
  String get reportConfirmed;

  /// No description provided for @reportAlreadyConfirmed.
  ///
  /// In es, this message translates to:
  /// **'Ya confirmaste este reporte.'**
  String get reportAlreadyConfirmed;

  /// No description provided for @reportLifetime.
  ///
  /// In es, this message translates to:
  /// **'Los reportes se muestran durante 72 horas.'**
  String get reportLifetime;

  /// No description provided for @reportSent.
  ///
  /// In es, this message translates to:
  /// **'Reporte enviado.'**
  String get reportSent;

  /// No description provided for @reportValidation.
  ///
  /// In es, this message translates to:
  /// **'Describe el problema con entre 3 y 500 caracteres.'**
  String get reportValidation;

  /// No description provided for @feedbackIncorrectData.
  ///
  /// In es, this message translates to:
  /// **'Datos incorrectos'**
  String get feedbackIncorrectData;

  /// No description provided for @feedbackMetadataNotice.
  ///
  /// In es, this message translates to:
  /// **'Se enviarán la versión de la app, el modelo del dispositivo y la versión de los datos.'**
  String get feedbackMetadataNotice;

  /// No description provided for @feedbackSendError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo confirmar el envío. Tu comentario sigue aquí para volver a intentarlo.'**
  String get feedbackSendError;

  /// No description provided for @feedbackNeedsSession.
  ///
  /// In es, this message translates to:
  /// **'Inicia sesión o entra como invitado para enviar un comentario.'**
  String get feedbackNeedsSession;

  /// No description provided for @reportSelectLine.
  ///
  /// In es, this message translates to:
  /// **'Selecciona una línea si corresponde'**
  String get reportSelectLine;

  /// No description provided for @accountDeletionPending.
  ///
  /// In es, this message translates to:
  /// **'La eliminación está pendiente. Reintenta desde tu perfil para completarla.'**
  String get accountDeletionPending;

  /// No description provided for @deleteAccount.
  ///
  /// In es, this message translates to:
  /// **'Eliminar mi cuenta'**
  String get deleteAccount;

  /// No description provided for @accountDeletionWarning.
  ///
  /// In es, this message translates to:
  /// **'Se borrarán tus favoritos, viajes, reportes, comentarios, confirmaciones y puntajes de tu cuenta. Esta acción no se puede deshacer.'**
  String get accountDeletionWarning;

  /// No description provided for @accountDeletionGoogle.
  ///
  /// In es, this message translates to:
  /// **'Se abrirá Google para verificar que eres tú. Selecciona la misma cuenta.'**
  String get accountDeletionGoogle;

  /// No description provided for @accountDeletionError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo completar la eliminación. Parte de los datos puede haberse borrado. Reintenta para terminar; la sincronización queda pausada.'**
  String get accountDeletionError;

  /// No description provided for @accountDeleting.
  ///
  /// In es, this message translates to:
  /// **'Eliminando datos y cuenta…'**
  String get accountDeleting;

  /// No description provided for @accountDeleted.
  ///
  /// In es, this message translates to:
  /// **'Cuenta y datos eliminados.'**
  String get accountDeleted;

  /// No description provided for @accountDeletionResume.
  ///
  /// In es, this message translates to:
  /// **'Completar eliminación de cuenta'**
  String get accountDeletionResume;

  /// No description provided for @weeklyRanking.
  ///
  /// In es, this message translates to:
  /// **'Ranking semanal'**
  String get weeklyRanking;

  /// No description provided for @rankingPeriod.
  ///
  /// In es, this message translates to:
  /// **'Semana {week} de {year}'**
  String rankingPeriod(int week, int year);

  /// No description provided for @rankingPublicName.
  ///
  /// In es, this message translates to:
  /// **'Tu nombre de perfil se muestra junto a tu puntaje.'**
  String get rankingPublicName;

  /// No description provided for @rankingLocalOnly.
  ///
  /// In es, this message translates to:
  /// **'Tus récords se guardan en este equipo. El ranking no está habilitado en esta versión.'**
  String get rankingLocalOnly;

  /// No description provided for @rankingPending.
  ///
  /// In es, this message translates to:
  /// **'Hay puntajes guardados en este equipo pendientes de publicar.'**
  String get rankingPending;

  /// No description provided for @rankingUnavailable.
  ///
  /// In es, this message translates to:
  /// **'No se pudo cargar el ranking. Vuelve a intentarlo con conexión.'**
  String get rankingUnavailable;

  /// No description provided for @rankingNoScore.
  ///
  /// In es, this message translates to:
  /// **'Todavía no tienes un puntaje publicado esta semana.'**
  String get rankingNoScore;

  /// No description provided for @rankingOwn.
  ///
  /// In es, this message translates to:
  /// **'Tu puesto: {position} · {score} puntos'**
  String rankingOwn(int position, int score);

  /// No description provided for @rankingEmpty.
  ///
  /// In es, this message translates to:
  /// **'Aún no hay puntajes publicados esta semana.'**
  String get rankingEmpty;

  /// No description provided for @myReports.
  ///
  /// In es, this message translates to:
  /// **'Mis reportes'**
  String get myReports;

  /// No description provided for @myReportsEmpty.
  ///
  /// In es, this message translates to:
  /// **'No tienes reportes guardados.'**
  String get myReportsEmpty;

  /// No description provided for @deleteReport.
  ///
  /// In es, this message translates to:
  /// **'Eliminar reporte'**
  String get deleteReport;

  /// No description provided for @reportDeleted.
  ///
  /// In es, this message translates to:
  /// **'Reporte eliminado.'**
  String get reportDeleted;

  /// No description provided for @reportDeleteError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo eliminar el reporte. Vuelve a intentarlo.'**
  String get reportDeleteError;

  /// No description provided for @cancel.
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get cancel;

  /// No description provided for @accountDeletionMarkerNotice.
  ///
  /// In es, this message translates to:
  /// **'Conservamos una señal vacía de cuenta eliminada, ligada a su identificador técnico, para bloquear sesiones antiguas. No contiene nombre, correo, ubicaciones ni comentarios.'**
  String get accountDeletionMarkerNotice;

  /// No description provided for @updateChecking.
  ///
  /// In es, this message translates to:
  /// **'Buscando actualizaciones…'**
  String get updateChecking;

  /// No description provided for @updateDownloading.
  ///
  /// In es, this message translates to:
  /// **'Descargando y verificando datos…'**
  String get updateDownloading;

  /// No description provided for @updateApplying.
  ///
  /// In es, this message translates to:
  /// **'Aplicando el paquete…'**
  String get updateApplying;

  /// No description provided for @updateRestoring.
  ///
  /// In es, this message translates to:
  /// **'Recuperando el paquete anterior…'**
  String get updateRestoring;

  /// No description provided for @updateCurrent.
  ///
  /// In es, this message translates to:
  /// **'Ya tienes el paquete disponible: versión {version}.'**
  String updateCurrent(int version);

  /// No description provided for @updateComplete.
  ///
  /// In es, this message translates to:
  /// **'Paquete actualizado a la versión {version}.'**
  String updateComplete(int version);

  /// No description provided for @updateTripRunning.
  ///
  /// In es, this message translates to:
  /// **'Finaliza el viaje o la operación actual antes de actualizar.'**
  String get updateTripRunning;

  /// No description provided for @updateNeedsApp.
  ///
  /// In es, this message translates to:
  /// **'Este paquete necesita una versión más reciente de GoWayki.'**
  String get updateNeedsApp;

  /// No description provided for @updateRejected.
  ///
  /// In es, this message translates to:
  /// **'El paquete no superó la verificación. Conservamos los datos anteriores.'**
  String get updateRejected;

  /// No description provided for @updateCancelled.
  ///
  /// In es, this message translates to:
  /// **'Actualización cancelada. Tus datos actuales siguen disponibles.'**
  String get updateCancelled;

  /// No description provided for @updateUnavailable.
  ///
  /// In es, this message translates to:
  /// **'Las actualizaciones no están disponibles en este momento.'**
  String get updateUnavailable;

  /// No description provided for @updateFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo aplicar la actualización. Reintenta; se conserva una copia del paquete anterior.'**
  String get updateFailed;

  /// No description provided for @close.
  ///
  /// In es, this message translates to:
  /// **'Cerrar'**
  String get close;
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
