# GoWayki · Arequipa

Aplicación Flutter de consulta y planificación con MapLibre, mapa MBTiles y paquete SQLite offline. Incluye búsqueda FTS5, recorridos y fichas, favoritos, viaje activo con alarma de bajada y Wayki Combi. Firebase añade acceso, sincronización, reportes comunitarios, ayuda y ranking semanal.

Los tiempos, frecuencias, tarifas y caminatas son estimaciones. No hay GPS de buses; los tiempos se estiman por frecuencia. Los candidatos de paradero requieren validación física. La ubicación del viaje corresponde al propio dispositivo. El alcance web/PMTiles se aplazó por decisión del usuario; el trabajo actual se centra en Android/iOS nativo.

## Entorno en Windows

Todo el proyecto, cachés y herramientas locales se encuentran bajo `C:\Proyecto_001`. Abrir `C:\Proyecto_001\gowayki_lab` en VS Code y ejecutar desde esa raíz:

```powershell
. C:\Proyecto_001\Entorno.ps1
flutter pub get
flutter analyze
flutter test
```

Flutter y Dart están en `.tools/flutter`, Android SDK en `.tools/android-sdk` y el entorno Python en `.tools/city-pack-venv`, bajo `C:\Proyecto_001`. El script configura sus cachés locales. Java se utiliza desde la instalación existente de Android Studio. Windows permite desarrollar, probar lógica/UI y compilar APK; no certifica la ejecución nativa de MapLibre, WebView, GPS y alarmas en Android/iOS. Para ejecutar el producto usar un dispositivo Android identificado con `flutter devices` o un Mac con simulador/dispositivo iOS.

```powershell
flutter run -d ID_DISPOSITIVO --dart-define=USE_FIREBASE=false
flutter run -d ID_DISPOSITIVO --dart-define=USE_FIREBASE=true --dart-define=ENABLE_OBSERVABILITY=false
```

Sustituir `ID_DISPOSITIVO` por el identificador real. El modo local es el predeterminado y conserva mapa, búsqueda y planificación sin Firebase; ofrece invitado local y no simula autenticación por correo, envíos de ayuda ni publicaciones remotas.

## Datos y regeneración

El paquete actual es esquema 1, versión de datos 2: 98 líneas, 191 patrones y 6.128 puntos utilizados. Los archivos originales y su procedencia están documentados en `tool/build_city_pack/` y en los informes de las partes. Se conservan 1.280 nombres estimados y una ruta sin correspondencia de sentido queda deshabilitada para el planificador. El fondo MBTiles y el paquete de transporte tienen procedencias/fechas propias.

```powershell
C:\Proyecto_001\.tools\city-pack-venv\Scripts\python.exe -B tool/build_city_pack/build.py --pack
C:\Proyecto_001\.tools\city-pack-venv\Scripts\python.exe -B -m unittest discover -s tool/build_city_pack/tests -v
C:\Proyecto_001\.tools\city-pack-venv\Scripts\python.exe -B tool/build_map_manifest.py --check
```

La regeneración requiere las fuentes y el PBF fijados, con sus hashes. Al preparar una revisión distribuible, incrementar `data_version` en `tool/build_city_pack/config/arequipa.json`; una misma versión debe identificar un solo build. No reemplazar fuentes GTFS o el mapa sin revisar sus correspondencias. Atribución: [OpenStreetMap contributors, ODbL](https://www.openstreetmap.org/copyright).

## Firebase

Proyecto `gowayki-lab`; Android `pe.edu.tecsup.gowayki_lab`; iOS `pe.edu.tecsup.mobilityLab`. Son aplicaciones distintas del mismo proyecto y conservan los identificadores suministrados. `tool/configure_firebase.py --require-google` valida los archivos nativos integrados, las opciones Dart y OAuth; no descarga un SDK de iOS a mano ni usa una cuenta de servicio.

Authentication integra correo/contraseña, Google y anónimo. Google requiere las huellas de cada certificado distribuido. La huella debug fue facilitada; el certificado release local está en `docs/ANDROID_RELEASE_SIGNING.json` y su SHA-1 ya se registró en Firebase en la parte 10; `google-services.json` se actualizó y pasó `tool/configure_firebase.py --require-google`. Falta validar Google en dispositivo con esa firma. Si Google Play firma el APK, registrar también la huella del certificado de firma de Play.

La base Cloud Firestore `(default)` de `gowayki-lab` ya está creada en edición Standard y modo Native. Por autorización del usuario se desplegaron las reglas probadas y los cinco índices ya están `READY`. La verificación remota confirmó que el contenido de las reglas activas coincide exactamente con el archivo local. Los metadatos reales de `cities/arequipa` ya se crearon y se verificaron por lectura posterior; conservan versión, tamaño y hash reales. La URL de descarga se retiró cuando el usuario hizo privado el repositorio; falta un origen público autorizado. Ver `docs/FIREBASE_PARTE10.json`. Queda probar los flujos en dispositivo. No confundir las comprobaciones de configuración con una validación funcional completa de la app.

```powershell
.\tool\test_firebase.ps1 -IncludeAuth
.\tool\test_firebase.ps1 -SeedOnly
```

Estos comandos se restringen a emuladores loopback y proyecto `demo-gowayki-lab`; no despliegan ni necesitan credenciales de administración. La instalación local de herramientas usa `tool/firebase/package-lock.json` y `npm ci` con el entorno activado. Reglas: propietarios en datos privados; reportes reales y confirmaciones únicas; feedback solo creación; ranking acotado; excepción de borrado de cuenta con reducción exacta de confirmaciones. Tras borrar una cuenta se conserva una marca técnica privada y vacía por UID para impedir recreación con tokens antiguos. Detalles y límites: `docs/CIERRE_PARTE8.md`.

Para volver a desplegar cambios revisados, con una sesión autorizada de la CLI:

```powershell
$env:XDG_CONFIG_HOME='C:\Proyecto_001\.tools\firebase-config'
$env:XDG_CACHE_HOME='C:\Proyecto_001\.tools\firebase-cache'
node tool/firebase/node_modules/firebase-tools/lib/bin/firebase.js deploy --project gowayki-lab --only firestore:rules,firestore:indexes
```

Ese comando modifica el proyecto remoto. El primer despliegue de reglas e índices se ejecutó con autorización del usuario el 2026-11-07; la comprobación y su respaldo se registran en `docs/FIRESTORE_DESPLIEGUE.json`. El seed incluido permanece limitado al emulador y no debe apuntarse a producción. La sesión autorizada de la CLI está en el directorio de configuración indicado; si en otro entorno se necesita iniciarla, usar `login --interactive` sin compartir códigos ni tokens por el chat. `node tool/verify_firestore_live.cjs` comprueba reglas e índices mediante consultas de solo lectura con esas mismas variables.

## Actualización y Hosting

Ajustes compara `cities/arequipa` con el paquete instalado. Descarga por HTTPS, respeta la versión mínima de app, comprueba tamaños/SHA-256, SQLite/FTS y consultas de mapa/planificador. Activa por puntero a un directorio inmutable; ante fallo restaura la copia anterior. Bloquea el cambio durante viajes o eliminación de cuenta. Conserva versiones anteriores sin limpieza automática. Ver `docs/ACTUALIZACIONES_9A.md`.

```powershell
C:\Proyecto_001\.tools\city-pack-venv\Scripts\python.exe -B tool/prepare_hosting.py --base-url https://gowayki-lab.web.app
```

El origen es una propuesta, no una publicación verificada. Genera `hosting/` y `build/hosting/cities.arequipa.json` sin escribir Firestore. Los textos fuente están en `tool/hosting/`. Los borradores incluyen a sharon trujillo y sharon.trujillo@tecsup.edu.pe, suministrados por el usuario. Privacidad y términos siguen pendientes de revisión y publicación; la comprobación predeploy bloquea ese candidato. Los botones legales permanecen desactivados hasta disponer de URL reales revisadas, configurables mediante `PRIVACY_URL` y `TERMS_URL`.

El comando futuro de Hosting es `firebase deploy --project gowayki-lab --only hosting`, usando la CLI local del proyecto. Requiere completar/revisar los textos y preparar un candidato aprobado. No hay despliegue ni descarga pública. El generador puede adjuntar un APK de release verificado mediante `--release-apk build/app/outputs/flutter-apk/app-release.apk`.

## Observabilidad y distribución

Analytics/Crashlytics están preparados y desactivados por defecto; no se envían UID, nombres, correo, coordenadas, consultas ni texto libre en los eventos propios. Los eventos usan nombres fijos; los errores Dart pasan por un filtro de códigos/trazas. Activación futura: Firebase + móvil + release + `ENABLE_OBSERVABILITY=true`, después de revisar políticas y configuración. No se incluyen subidas automáticas de mappings/símbolos en el build. Los SDK pueden manejar identificadores técnicos y metadatos propios; su revisión de privacidad y recepción real está pendiente.

`docs/OBSERVABILIDAD_9B.md` documenta los eventos, límites, símbolos y el comando de App Distribution con `--release-notes-file` y `--testers-file`. No se ha subido un binario ni enviado invitaciones a testers. Las notas están en `docs/release-notes.txt`; la lista real de correos debe mantenerse fuera de Git.

## Compilar Android e iOS

```powershell
flutter build apk --debug --dart-define=USE_FIREBASE=false
flutter build apk --debug --dart-define=USE_FIREBASE=true --dart-define=ENABLE_OBSERVABILITY=false
C:\Proyecto_001\.tools\city-pack-venv\Scripts\python.exe -B tool/create_release_keystore.py
flutter build apk --release --dart-define=USE_FIREBASE=false --dart-define=ENABLE_OBSERVABILITY=false --split-debug-info=build/symbols/android
```

La clave local se conserva en `C:\Proyecto_001\.tools\signing\gowayki-upload.p12`; sus contraseñas están en `android/key.properties`, ignorado por Git. El generador no reemplaza una configuración existente. Respaldar y proteger ambos archivos: perder la clave impide actualizar instalaciones firmadas con ella. Es una candidata local para firma de subida, sin alta en Google Play ni aprobación como clave de producción. La firma release difiere de debug: Android no permite actualizar una instalación con otra firma. Antes de cualquier cambio de instalación, preservar los datos necesarios; no se ha desinstalado nada automáticamente.

```powershell
C:\Proyecto_001\.tools\city-pack-venv\Scripts\python.exe -B tool/verify_apk.py --apk build/app/outputs/flutter-apk/app-release.apk --variant release
C:\Proyecto_001\.tools\city-pack-venv\Scripts\python.exe -B tool/verify_apk_permissions.py --apk build/app/outputs/flutter-apk/app-release.apk
C:\Proyecto_001\.tools\city-pack-venv\Scripts\python.exe -B tool/verify_release.py
```

El APK se genera en `build/app/outputs/flutter-apk/`. Verificar cada artefacto antes de distribuirlo. Para Firebase en release, usar `USE_FIREBASE=true` y completar los requisitos remotos. El nombre de distribución, firma y permisos se registran en los JSON de verificación; los informes históricos corresponden a su punto de control.

iOS requiere macOS/Xcode y firma Apple. El proyecto conserva su bundle ID y destino mínimo iOS 15. Con Swift Package Manager, usar el SDK Analytics sin soporte publicitario al resolver/compilar:

```sh
FIREBASE_ANALYTICS_WITHOUT_ADID=true flutter build ios --release --no-codesign --dart-define=USE_FIREBASE=false --dart-define=ENABLE_OBSERVABILITY=false
```

Ese comando sirve para comprobar una compilación sin firma en Mac; no genera una distribución instalable aprobada. Archivo/IPA y dSYM necesitan la configuración real del equipo Apple. No se ha compilado iOS desde Windows.

## Juego y validación física pendiente

Wayki Combi ocupa 67.045 bytes con 15 sprites pequeños; los originales se conservan. Es Canvas/JS puro, sin recursos de red, y el WebView restringe navegación al archivo instalado. `node tool/test_game.mjs` comprueba la lógica; `python tool/verify_game.py` verifica los archivos y el límite de 150 KB. La prueba visual abriendo `assets/game/index.html` se aplazó por petición del usuario. Windows no certifica audio/vibración, modo avión ni WebView móvil.

Pendientes físicos: fluidez de mapa, GPS, notificación persistente, alarmas y permisos Android/iOS, rendimiento menor de 400 ms en Android de gama media, autenticación/sincronización y recepción de observabilidad reales. La medición Windows AOT de 28 muestras tuvo mediana 152,709 ms y máximo 393,125 ms; no equivale al criterio Android.

Código y pruebas se organizan en `lib/domain`, `lib/infra`, `lib/app`, `lib/shared`, `lib/l10n` y `test`. `docs/ESTADO_TRABAJO.json` indica el último punto verificado. El código y su historial están en [GitHub](https://github.com/NICO-bestacclaimed/gowayki-lab-respaldo-31fbe31), y los respaldos anteriores están en la release `respaldo-31fbe31`. Hosting y App Distribution siguen sin publicar. Las reglas e índices de Firestore sí se desplegaron con autorización del usuario.
