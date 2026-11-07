// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'GoWayki';

  @override
  String get explore => 'Explorar';

  @override
  String get routes => 'Rutas';

  @override
  String get favorites => 'Favoritos';

  @override
  String get profile => 'Perfil';

  @override
  String get retry => 'Reintentar';

  @override
  String get settings => 'Ajustes';

  @override
  String get help => 'Ayuda y comentarios';

  @override
  String get signOut => 'Cerrar sesión';

  @override
  String get signIn => 'Iniciar sesión';

  @override
  String get guest => 'Invitado';

  @override
  String get menu => 'Menú';

  @override
  String get back => 'Volver';

  @override
  String get continueAction => 'Continuar';

  @override
  String get bootstrapError => 'No pudimos preparar los datos de Arequipa.';

  @override
  String get linesError => 'No pudimos cargar las líneas.';

  @override
  String get favoritesEmpty =>
      'Aún no tienes líneas favoritas. Guarda una desde Rutas.';

  @override
  String get linesEmpty => 'No hay líneas en el paquete actual.';

  @override
  String get removeFavorite => 'Quitar de favoritos';

  @override
  String get addFavorite => 'Guardar en favoritos';

  @override
  String get saveFailed => 'No se pudo guardar el cambio. Inténtalo otra vez.';

  @override
  String get noSession => 'No hay sesión iniciada.';

  @override
  String get localGuestHelp =>
      'Puedes explorar rutas y guardar favoritos en este dispositivo.';

  @override
  String get locationTitle => 'Tu ubicación, tú decides';

  @override
  String get locationExplanation =>
      'GoWayki puede usar tu ubicación para sugerir puntos de subida cercanos y ayudarte a iniciar un viaje desde tu posición.';

  @override
  String get locationOptional =>
      'El permiso es opcional. Puedes continuar sin ubicación.';

  @override
  String get locationDenied =>
      'El permiso no se concedió. Puedes continuar y cambiarlo más adelante.';

  @override
  String get locationPermanent =>
      'El permiso está desactivado en los ajustes de la aplicación.';

  @override
  String get openSettings => 'Abrir ajustes';

  @override
  String get waitMoment => 'Un momento…';

  @override
  String get allowLocation => 'Permitir ubicación';

  @override
  String get continueWithoutLocation => 'Continuar sin ubicación';

  @override
  String get continueFailed => 'No pudimos continuar. Inténtalo otra vez.';

  @override
  String get permissionFailed =>
      'No pudimos solicitar el permiso. Puedes continuar sin ubicación.';

  @override
  String get permissionSettingsHelp =>
      'Abre los ajustes de la aplicación para cambiar el permiso.';

  @override
  String get deviceSettingsHelp =>
      'Puedes cambiar el permiso desde los ajustes del dispositivo.';

  @override
  String get onboardFind => 'Encuentra tu combi';

  @override
  String get onboardFindBody =>
      'Explora las líneas de Arequipa y reconoce tu micro.';

  @override
  String get onboardAlight => 'Sabe dónde bajar';

  @override
  String get onboardAlightBody =>
      'Consulta los puntos del recorrido y los transbordos de tu viaje.';

  @override
  String get onboardTime => 'Llega a tiempo (tiempos estimados)';

  @override
  String get onboardTimeBody =>
      'Compara alternativas con tiempos aproximados de caminata, espera y viaje.';

  @override
  String get skip => 'Omitir';

  @override
  String get start => 'Comenzar';

  @override
  String get next => 'Siguiente';

  @override
  String get preparing => 'Preparando Arequipa…';

  @override
  String get line => 'Línea';

  @override
  String get allDirections => 'Todas';

  @override
  String get outbound => 'Ida';

  @override
  String get inbound => 'Vuelta';

  @override
  String get whereTo => '¿Adónde vas?';

  @override
  String get searchExamples => 'Prueba “TECSUP”, “Plaza” o “Mall”';

  @override
  String get directions => 'Cómo llegar';

  @override
  String get buses => 'Combis';

  @override
  String get searchLine => 'Buscar línea o combi…';

  @override
  String get noResults => 'Sin resultados';

  @override
  String get mapError => 'No se pudo cargar el mapa sin conexión.';

  @override
  String get feedbackMinimum => 'Escribe al menos 3 caracteres.';

  @override
  String get feedbackSent => 'Gracias. Comentario enviado.';

  @override
  String get feedbackBug => 'Bug';

  @override
  String get feedbackIdea => 'Idea';

  @override
  String get feedbackOther => 'Otro';

  @override
  String get message => 'Mensaje';

  @override
  String get send => 'Enviar';

  @override
  String get genericError =>
      'No pudimos completar la acción. Inténtalo otra vez.';

  @override
  String get planTrip => 'Planificar viaje';

  @override
  String get brandTagline => 'Tu ciudad, más cerca';

  @override
  String get email => 'Correo';

  @override
  String get password => 'Contraseña';

  @override
  String get createAccount => 'Crear cuenta';

  @override
  String get guestEntry => 'Entrar como invitado';

  @override
  String get firebaseActive => 'Firebase Auth activo';

  @override
  String get localDemo => 'Modo demo · sin Firebase';

  @override
  String get pageUnavailable => 'Esta página no está disponible.';

  @override
  String get backExplore => 'Volver a Explorar';

  @override
  String get chooseDestination => 'Selecciona un destino desde Explorar.';

  @override
  String get city => 'Ciudad';

  @override
  String get activeCity => 'Ciudad activa';

  @override
  String get language => 'Idioma';

  @override
  String get systemDefault => 'Sistema';

  @override
  String get spanish => 'Español (Perú)';

  @override
  String get english => 'English';

  @override
  String get appearance => 'Apariencia';

  @override
  String get theme => 'Tema';

  @override
  String get lightTheme => 'Claro';

  @override
  String get darkTheme => 'Oscuro';

  @override
  String get plannerPreferences => 'Preferencias de viaje';

  @override
  String get maxWalking => 'Caminata máxima hasta un paradero';

  @override
  String get avoidTransfers => 'Evitar transbordos';

  @override
  String get alarmType => 'Aviso de bajada';

  @override
  String get alarmSound => 'Sonido';

  @override
  String get alarmVibration => 'Vibración';

  @override
  String get alarmOff => 'Desactivado';

  @override
  String get offlineData => 'Datos sin conexión';

  @override
  String get checkUpdate => 'Buscar actualización';

  @override
  String get updatesLater =>
      'Las actualizaciones del paquete estarán disponibles próximamente.';

  @override
  String get about => 'Acerca de';

  @override
  String get privacy => 'Privacidad';

  @override
  String get terms => 'Términos';

  @override
  String get legalUnavailable =>
      'Los documentos legales estarán disponibles cuando se publiquen.';

  @override
  String get openLinkFailed => 'No se pudo abrir el enlace.';

  @override
  String get osmAttribution => '© Colaboradores de OpenStreetMap · ODbL';

  @override
  String get openMapTilesAttribution =>
      'OpenMapTiles · cartografía sin conexión';

  @override
  String get emptyTitle => 'Todavía no hay elementos.';

  @override
  String get gpsOffTitle => 'Activa la ubicación del dispositivo';

  @override
  String get gpsOffBody => 'Activa el GPS para encontrar puntos cercanos.';

  @override
  String get permissionTitle => 'Permiso de ubicación necesario';

  @override
  String get permissionBody =>
      'Puedes permitir la ubicación o continuar eligiendo los puntos del viaje.';

  @override
  String get noResultsBody =>
      'Prueba con otro punto o cambia las preferencias del viaje.';

  @override
  String get outsideTitle => 'Fuera del área de servicio';

  @override
  String get outsideBody => 'El paquete actual contiene rutas de Arequipa.';

  @override
  String get errorTitle => 'No pudimos cargar la información';

  @override
  String get errorBody =>
      'Inténtalo otra vez. Tus datos guardados se conservan.';

  @override
  String towards(String destination) {
    return 'hacia $destination';
  }

  @override
  String outboundTo(String destination) {
    return 'Ida → $destination';
  }

  @override
  String inboundTo(String destination) {
    return 'Vuelta → $destination';
  }

  @override
  String directionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sentidos',
      one: '1 sentido',
    );
    return '$_temp0';
  }

  @override
  String tripStats(int minutes, int transfers) {
    String _temp0 = intl.Intl.pluralLogic(
      transfers,
      locale: localeName,
      other: '$transfers transbordos',
      one: '1 transbordo',
    );
    return '~$minutes min · $_temp0';
  }

  @override
  String walkingLimit(int meters) {
    return 'Hasta $meters m';
  }

  @override
  String automaticWalking(int initial, int fallback) {
    return 'Automático ($initial–$fallback m)';
  }

  @override
  String dataVersion(int version) {
    return 'Versión de datos: $version';
  }

  @override
  String dataBuiltAt(String date) {
    return 'Paquete compilado el $date';
  }

  @override
  String get nearbyStops => 'Paraderos cerca de ti';

  @override
  String get estimatedName => 'Nombre estimado · pendiente de revisión';

  @override
  String get home => 'Casa';

  @override
  String get work => 'Trabajo';

  @override
  String get goHere => 'Ir aquí';

  @override
  String get leaveHere => 'Salir desde aquí';

  @override
  String get selectedPoint => 'Punto elegido en el mapa';

  @override
  String get origin => 'Origen';

  @override
  String get destination => 'Destino';

  @override
  String get choosePoints => 'Elegir puntos del viaje';

  @override
  String get usePoints => 'Usar estos puntos';

  @override
  String get swapPoints => 'Intercambiar origen y destino';

  @override
  String get myLocation => 'Mi ubicación';

  @override
  String get recent => 'Recientes';

  @override
  String get places => 'Lugares';

  @override
  String get stops => 'Paraderos';

  @override
  String get streets => 'Calles';

  @override
  String get chooseStop => 'Selecciona un paradero de esta línea';

  @override
  String get showRoutes => 'Mostrar rutas';

  @override
  String get hideRoutes => 'Ocultar rutas';

  @override
  String approxWalk(int meters) {
    return '~$meters m a pie';
  }

  @override
  String get leaveNow => 'Salir ahora';

  @override
  String get leaveAt => 'Salir a una hora';

  @override
  String get arriveBy => 'Llegar antes de una hora';

  @override
  String get fastest => 'Más rápida';

  @override
  String get fewestTransfers => 'Menos transbordos';

  @override
  String get leastWalking => 'Menos caminata';

  @override
  String get noTransfers => 'Sin transbordo';

  @override
  String get noService => 'Sin servicio en la hora elegida';

  @override
  String get walkOnly => 'Alternativa a pie';

  @override
  String get walkingEstimate => 'Caminata aproximada · trazado orientativo';

  @override
  String get details => 'Ver detalle';

  @override
  String get saveTrip => 'Guardar viaje';

  @override
  String get share => 'Compartir';

  @override
  String get startTrip => 'Iniciar viaje';

  @override
  String get intermediateStops => 'Paraderos intermedios';

  @override
  String get estimatedTimes => 'Todos los tiempos son estimados';

  @override
  String optionNumber(int number) {
    return 'Opción $number';
  }

  @override
  String minutesApprox(int minutes) {
    return '~$minutes min';
  }

  @override
  String walkingMinutes(int minutes) {
    return 'Caminata: ~$minutes min';
  }

  @override
  String waitingMinutes(int minutes) {
    return 'Espera: ~$minutes min';
  }

  @override
  String transferNumber(int count) {
    return '$count transbordos';
  }

  @override
  String fareAmount(String amount) {
    return 'Tarifa estimada: S/ $amount';
  }

  @override
  String walkInstruction(int meters, int minutes, String destination) {
    return 'Camina ~$meters m (~$minutes min) hasta $destination';
  }

  @override
  String boardInstruction(String line, String destination) {
    return 'Toma $line hacia $destination';
  }

  @override
  String frequencyApprox(int minutes) {
    return 'Pasa cada ~$minutes min';
  }

  @override
  String rideInstruction(int stops, int minutes, String destination) {
    return 'Viaja $stops paraderos (~$minutes min) y baja en $destination';
  }

  @override
  String waitInstruction(int minutes) {
    return 'Espera estimada: ~$minutes min';
  }

  @override
  String bandHoldInstruction(int minutes) {
    return 'Espera adicional por cambio de franja: ~$minutes min';
  }

  @override
  String get removeSavedTrip => 'Quitar viaje guardado';

  @override
  String get nearMe => 'Pasan cerca de mí';

  @override
  String get directionSelector => 'Sentido';

  @override
  String get configureHome => 'Configurar Casa';

  @override
  String get configureWork => 'Configurar Trabajo';

  @override
  String get savedTrips => 'Viajes guardados';

  @override
  String get savedPlaces => 'Lugares guardados';

  @override
  String get delete => 'Borrar';

  @override
  String get edit => 'Editar';

  @override
  String get favoriteStops => 'Paraderos favoritos';

  @override
  String get unset => 'Sin configurar';

  @override
  String get saved => 'Guardados';

  @override
  String get savedTripNote => 'Los viajes guardados se recalculan al abrirlos.';

  @override
  String get activeTrip => 'Viaje en curso';

  @override
  String get noActiveTrip => 'No hay un viaje activo.';

  @override
  String get tripNotificationBody =>
      'Ubicación activa hasta llegar o tocar Terminar. Toca para volver a GoWayki.';

  @override
  String get alightAlertTitle => 'GoWayki · Prepárate para bajar';

  @override
  String alightAlertBody(String name) {
    return 'Bájate en el próximo paradero: $name';
  }

  @override
  String get transferAlertTitle => 'GoWayki · Zona de transbordo';

  @override
  String transferAlertBody(String name) {
    return 'Llegaste a $name. Revisa el siguiente tramo antes de subir.';
  }

  @override
  String get tripCompleted => 'Llegaste a tu destino. Seguimiento terminado.';

  @override
  String get tripStopped => 'Seguimiento terminado.';

  @override
  String get tripTrackingFailed =>
      'El seguimiento se detuvo. Revisa el GPS y los permisos antes de iniciar otro viaje.';

  @override
  String get activeWalk => 'Camina al siguiente punto';

  @override
  String activeBoard(String name) {
    return 'Espera y sube a $name';
  }

  @override
  String activeRide(String name) {
    return 'Continúa en $name';
  }

  @override
  String alightAt(String name) {
    return 'Baja en: $name';
  }

  @override
  String activeDistance(String meters) {
    return 'Distancia aproximada al siguiente punto: ~$meters m';
  }

  @override
  String remainingStops(int count) {
    return 'Paraderos restantes: ~$count';
  }

  @override
  String get tripLocationUncertain =>
      'Esperando una ubicación reciente y precisa. La distancia y las alertas pueden no estar disponibles.';

  @override
  String get tripAlertFailed =>
      'No se pudo emitir una alerta. Revisa las notificaciones del sistema.';

  @override
  String get confirmBoarded => 'Ya subí';

  @override
  String get confirmAlighted => 'Ya bajé';

  @override
  String get confirmArrived => 'Ya llegué a este punto';

  @override
  String get manualStepNote =>
      'Confirma solo cuando hayas completado el paso. El GPS aproxima tu posición; no detecta el vehículo.';

  @override
  String get endTrip => 'Terminar viaje';

  @override
  String get tripPermissionDisclosure =>
      'Usaremos tu ubicación durante este viaje para indicar el paso actual y avisarte dónde bajar, también al minimizar la app. Android mostrará una notificación persistente. Te pediremos ubicación y notificaciones; el seguimiento termina al llegar, tocar Terminar o cerrar la app desde el sistema. Las alertas son aproximadas y dependen del GPS y de tus ajustes de sonido.';

  @override
  String get tripPermissionRequired =>
      'Permite la ubicación para iniciar el viaje.';

  @override
  String get tripNotificationsRequired =>
      'Activa las notificaciones de GoWayki en los ajustes del sistema para iniciar el seguimiento.';

  @override
  String get tripStartVisible =>
      'Vuelve a GoWayki y toca Iniciar viaje para activar el seguimiento.';

  @override
  String get cancelTripStart => 'Cancelar';

  @override
  String get gameSaveFailed =>
      'No se pudo guardar el récord o el ajuste del juego.';

  @override
  String get gameMobileOnly =>
      'La integración del juego está disponible en Android/iOS. En Windows abre assets/game/index.html en tu navegador.';

  @override
  String get gameLoadFailed =>
      'No se pudo abrir el juego local. Inténtalo de nuevo.';

  @override
  String gameBest(int score) {
    return 'Récord local: $score pts';
  }

  @override
  String get gameWhileWaiting => '¿Esperando tu combi? Juega';

  @override
  String get authInvalidCredentials =>
      'Revisa tu correo y contraseña e inténtalo de nuevo.';

  @override
  String get authInvalidEmail => 'Escribe un correo válido.';

  @override
  String get authWeakPassword =>
      'La contraseña no cumple los requisitos de seguridad. Prueba una más segura.';

  @override
  String get authEmailInUse =>
      'Ese correo ya tiene una cuenta. Inicia sesión para continuar.';

  @override
  String get authDisabled =>
      'Esta cuenta está deshabilitada. Contacta con el equipo de GoWayki.';

  @override
  String get authMethodUnavailable =>
      'Este método de acceso no está disponible. Prueba otro o continúa como invitado.';

  @override
  String get authNetwork =>
      'No pudimos conectar. Revisa tu conexión e inténtalo de nuevo.';

  @override
  String get authTooMany =>
      'Hubo demasiados intentos. Espera un momento antes de volver a probar.';

  @override
  String get authDifferentProvider =>
      'Usa el método con el que registraste esa cuenta.';

  @override
  String get authLocalHelp =>
      'Continúa sin cuenta. Tus favoritos y viajes se guardarán en este dispositivo.';

  @override
  String get authProfileWarning =>
      'Tu cuenta está creada; no se pudo guardar el nombre. Puedes seguir usando GoWayki.';

  @override
  String get authResetSent =>
      'Si existe una cuenta con ese correo, recibirás instrucciones para cambiar tu contraseña. Revisa también el correo no deseado.';

  @override
  String get authAccountHelp =>
      'Usa tu cuenta o continúa como invitado. Puedes planificar rutas sin iniciar sesión.';

  @override
  String get authName => 'Tu nombre';

  @override
  String get authNameInvalid => 'Escribe entre 2 y 60 caracteres.';

  @override
  String get authShowPassword => 'Mostrar contraseña';

  @override
  String get authHidePassword => 'Ocultar contraseña';

  @override
  String get authPasswordRequired => 'Escribe tu contraseña.';

  @override
  String get authPasswordLength =>
      'Usa entre 8 y 128 caracteres al crear tu cuenta.';

  @override
  String get authConfirmPassword => 'Confirma tu contraseña';

  @override
  String get authPasswordsDiffer => 'Las contraseñas no coinciden.';

  @override
  String get authHaveAccount => 'Ya tengo una cuenta';

  @override
  String get authForgotPassword => '¿Olvidaste tu contraseña?';

  @override
  String get authGoogle => 'Continuar con Google';

  @override
  String get authUpgrade => 'Conectar o crear mi cuenta';

  @override
  String get syncTitle => 'Tus datos';

  @override
  String get syncLocal => 'Guardados en este equipo.';

  @override
  String get syncNeedsSession =>
      'Inicia sesión para sincronizar tus favoritos y viajes.';

  @override
  String get syncWaiting =>
      'Guardados en este equipo. Esperando sincronización…';

  @override
  String get syncWorking => 'Sincronizando…';

  @override
  String get syncDone => 'Sincronizados con tu cuenta.';

  @override
  String get syncUnavailable =>
      'Guardados en este equipo. No se pudo sincronizar.';

  @override
  String get syncRetry => 'Reintentar sincronización';

  @override
  String get communityReports => 'Reportes de la comunidad';

  @override
  String get communityLoading => 'Cargando…';

  @override
  String get communityUnavailable => 'No se pudieron actualizar los reportes.';

  @override
  String get communityCached =>
      'Sin conexión: los reportes guardados pueden no estar actualizados.';

  @override
  String get communityError =>
      'No se pudo confirmar el envío. Conservamos el texto para que vuelvas a intentarlo.';

  @override
  String get communityLocalOnly =>
      'El envío de reportes y comentarios no está habilitado en esta versión.';

  @override
  String get reportProblem => 'Reportar problema';

  @override
  String get reportType => 'Tipo de problema';

  @override
  String get reportDetour => 'Desvío';

  @override
  String get reportMissingStop => 'El paradero no existe';

  @override
  String get reportStopName => 'Nombre del paradero incorrecto o ausente';

  @override
  String get reportLineMissing => 'La línea ya no pasa';

  @override
  String get reportNeedsAccount =>
      'Inicia sesión con una cuenta de correo o Google para reportar y confirmar.';

  @override
  String get reportExpired => 'Este reporte ya venció o fue eliminado.';

  @override
  String get reportNone => 'No hay reportes vigentes para esta ubicación.';

  @override
  String get reportConfirm => '👍 Sigue así';

  @override
  String get reportConfirmed => 'Confirmación guardada.';

  @override
  String get reportAlreadyConfirmed => 'Ya confirmaste este reporte.';

  @override
  String get reportLifetime => 'Los reportes se muestran durante 72 horas.';

  @override
  String get reportSent => 'Reporte enviado.';

  @override
  String get reportValidation =>
      'Describe el problema con entre 3 y 500 caracteres.';

  @override
  String get feedbackIncorrectData => 'Datos incorrectos';

  @override
  String get feedbackMetadataNotice =>
      'Se enviarán la versión de la app, el modelo del dispositivo y la versión de los datos.';

  @override
  String get feedbackSendError =>
      'No se pudo confirmar el envío. Tu comentario sigue aquí para volver a intentarlo.';

  @override
  String get feedbackNeedsSession =>
      'Inicia sesión o entra como invitado para enviar un comentario.';

  @override
  String get reportSelectLine => 'Selecciona una línea si corresponde';
}
