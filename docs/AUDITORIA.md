# Auditoría base de GoWayki

## 1. Alcance y estado

- Fecha: 6 de noviembre de 2026 (America/Lima).
- Sección: Parte 0, sección 0A del plan `gowayki_prompt_chat_codex.md`.
- Repositorio local: `C:\Proyecto_001\gowayki_lab`.
- Base examinada: `51709c9` — `Initial commit: gowayki_lab`.
- Antes de la auditoría, Git no presentaba cambios en archivos versionados.
- Esta sección solo incorpora este documento. No modifica código, dependencias, datos, permisos ni configuración del proyecto. No incluye la limpieza 0B ni funciones nuevas.

La base es una maqueta Flutter de transporte público de Arequipa: interfaces, datos locales de líneas y un mapa empaquetado. Compila para Android y supera su prueba de arranque, pero todavía no tiene el paquete SQLite, un planificador calculado sobre la red, búsqueda completa, ubicación real conectada a la interfaz ni los flujos de producto de las partes posteriores.

## 2. Verificaciones y límites

| Comprobación | Resultado | Alcance real |
| --- | --- | --- |
| `flutter analyze --no-pub` | Sin problemas, salida 0; ejecutado en 0A | Análisis Dart y reglas activas en `analysis_options.yaml`. Android, iOS y build están excluidos del analizador. |
| `flutter test --no-pub` | 1 prueba aprobada, 0 fallidas; ejecutado en 0A | Solo comprueba el arranque y el texto del splash. No valida todas las pantallas, mapa, permisos o viajes. |
| `flutter build apk --debug --no-pub` | APK generado durante la preparación anterior, con el mismo código base | No se repitió la compilación en esta auditoría documental. No equivale a una prueba de funcionamiento en teléfono. |
| `flutter doctor -v` | Flutter, Android y red correctos en la preparación anterior | No había dispositivo conectado. No se ha validado visualmente la app, el modo avión ni el rendimiento en teléfono. |
| Integridad MBTiles | `PRAGMA quick_check` devuelve `ok`, conexión SQLite de solo lectura | Integridad del contenedor; no demuestra que el mapa se dibuje correctamente en MapLibre. |
| CSV/JSON | Recuento, claves referenciadas y coordenadas de `network.json` comprobados en lectura | No se ha construido la proyección de paraderos ni calculado rutas de transporte. |
| iOS | Archivos inspeccionados | No compilado: el equipo de trabajo es Windows y no dispone de Xcode. |

Entorno observado: Flutter estable 3.47.9 y Dart 3.13.7. `pubspec.yaml` declara Dart `^3.11.0`, pero `pubspec.lock` exige Dart `>=3.13.0 <4.0.0` y Flutter `>=3.44.0`. Una instalación antigua que solo satisfaga el YAML no basta para reproducir el lock actual.

El SDK Flutter, el SDK Android local, las cachés y el perfil de VS Code se prepararon en `C:\Proyecto_001\.tools`. Java se utiliza desde la instalación existente de Android Studio, sin modificarla. Las instrucciones de uso están en `C:\Proyecto_001\LEEME-ENTORNO.md`.

## 3. Estructura

Se encontraron 42 archivos Dart en `lib/`, 9 pantallas repartidas en 8 funcionalidades y 1 archivo de pruebas.

| Carpeta/archivo | Estado observado |
| --- | --- |
| `lib/main.dart` | Inicializa Flutter y `ServiceLocator`. Solo inicializa Firebase con `USE_FIREBASE=true`; el valor predeterminado es `false`. |
| `lib/app.dart` | `MaterialApp`, Material 3 a través del tema claro, y `AppRoot` como inicio. Sin configuración de localización ni tema oscuro. |
| `lib/app/features/` | Splash, onboarding, acceso, explorar, planificador, perfil/menú, ajustes y comentarios. |
| `lib/app/common/ui/` | Layouts de autenticación y mapa; no contiene todavía el conjunto completo de estados reutilizables. |
| `lib/app/router/` | Máquina de fases y un `Navigator` anidado; no usa `go_router`. |
| `lib/domain/repositories/` | Siete contratos: autenticación, ciudades, comentarios, búsqueda, preferencias, red y viajes. No hay núcleo de planificación puro. |
| `lib/core/models/` | Modelos sencillos de usuario, ciudad, lugar, comentario, opción de viaje y línea/sentido. |
| `lib/data/` | Implementaciones demo y cuatro adaptadores Firebase, coordinados por el localizador estático. |
| `lib/infra/` | Lectura de `network.json` y copia del paquete del mapa al almacenamiento de la aplicación. |
| `lib/shared/theme/` | Colores, espaciados y tema claro. |
| `assets/gtfs/` | Cuatro archivos CSV de origen y `network.json`, todos empaquetados como assets. |
| `assets/map/` | MBTiles, estilo y nueve archivos de glifos. |
| `android/`, `ios/` | Proyectos nativos existentes. No hay proyecto web en la raíz. |
| `test/widget_test.dart` | Una prueba del splash en modo demo. |

No se encontraron instrucciones `AGENTS.md` aplicables en la raíz del repositorio ni en `C:\Proyecto_001`. No se inspeccionaron ni modificaron instrucciones de dependencias externas como parte del proyecto.

## 4. Estado de las pantallas

| Pantalla | Implementación actual | Diferencia con el plan |
| --- | --- | --- |
| Splash | Icono Material de mascota y texto; espera aproximada de 900 ms. | No usa el logo real ni carga un paquete SQLite. |
| Onboarding | Tres diapositivas con iconos y persistencia de la marca de visto. | El segundo título promete información que la app no obtiene. Debe limpiarse en 0B. No están las 15 ilustraciones ni la explicación previa del permiso. |
| Acceso | Correo, contraseña, registro e invitado; campos precargados con datos demo. | Faltan validación completa, Google, recuperación, vinculación y mensajes traducidos de error. Firebase conserva marcadores de configuración. |
| Explorar | Mapa, búsqueda sobre un catálogo de cinco lugares y selector de líneas/sentidos. | La ubicación del usuario no está conectada. El botón de ubicación vuela a una coordenada fija y `myLocationEnabled` es `false`. Sin paraderos cercanos ni búsqueda FTS. |
| Planificador | Origen fijo y dos opciones devueltas por el repositorio demo. | Los 38/52 minutos son constantes, no resultados calculados. No hay RAPTOR, tarifas, horas de salida/llegada, geometría del itinerario ni tiempos identificados como aproximados en la tarjeta. |
| Perfil/menú | Nombre/correo de la sesión, accesos a ajustes y comentarios, y cierre de sesión. | Sin gestión completa de cuenta, favoritos, reportes, juego o ranking. |
| Ajustes | Ciudad e idioma guardados en preferencias. | Elegir inglés no cambia los textos: faltan ARB, delegados y aplicación del locale. Sin tema oscuro, preferencias del planificador o alarma. |
| Comentarios | Formulario con validación mínima y adaptador demo/Firebase. | En demo, `submit` solo espera: no guarda ni envía. Aun así, la UI comunica envío; requiere una experiencia honesta antes de producto final. |

Evidencias principales: `lib/app/features/onboarding/presentation/screens/onboarding_screen.dart:26`, `lib/app/features/planner/presentation/screens/planner_screen.dart:20`, `lib/data/demo/demo_repositories.dart:82`, `lib/data/demo/demo_repositories.dart:136`, `lib/app/features/explorer/presentation/screens/explorer_screen.dart:149` y `lib/app/features/explorer/presentation/widgets/explorer_map.dart:274`.

## 5. ServiceLocator y repositorios

`ServiceLocator.init` recibe `useFirebase`, obtiene `SharedPreferences` y asigna campos `static late final`.

- Búsqueda y planificación se asignan siempre a implementaciones demo, incluso con Firebase activado. La red se carga siempre desde `network.json`.
- En modo demo, autenticación y ciudad son de demostración; ciudad/idioma se guardan con `SharedPreferences`; los comentarios no se conservan.
- Con Firebase, se sustituyen autenticación, ciudades, preferencias y comentarios, pero no existe todavía una sincronización de favoritos o viajes.
- Los campos globales no son sustituibles mediante providers y no admiten una segunda inicialización sobre la misma instancia de ejecución. Esto limita el aislamiento de pruebas y puede producir una reasignación de `late final` al ampliar la suite. Es un riesgo deducido del código; no se añadió una prueba nueva en 0A.
- `AppRoot` consulta `currentUser` al abandonar el splash; no se suscribe a `observeSession` para gobernar la navegación.
- La futura migración a Riverpod corresponde a 3A. No se cambió ninguna API en esta auditoría.

`AssetGtfsNetworkRepository` lee un asset, decodifica y construye los modelos en `Isolate.run`, y conserva el `Future` en `_cache`. No valida un esquema/versionado del paquete; un fallo cacheado no tiene una vía explícita de reintento. Los modelos de sentido guardan geometría `[lat, lon]`, no una secuencia de paraderos, distancias acumuladas ni horarios.

## 6. Mapa offline y compatibilidad

`OfflineMapPackage` importa directamente `dart:io` y utiliza `path_provider` y `AssetManifest`.

1. Obtiene el directorio de soporte de la aplicación y un subdirectorio `map`.
2. Si coincide el marcador `.version`, reutiliza el directorio sin verificar la presencia o el hash de todos sus archivos.
3. Si cambia la versión, borra el directorio anterior antes de copiar el nuevo.
4. Copia los assets y escribe el marcador al final.
5. Lee `style.json` y sustituye `{MAP_DIR}` por la ruta local.

Riesgos: la dependencia directa de `dart:io` requiere una implementación alternativa/importación condicional para web; una copia interrumpida pierde la instalación anterior; no hay actualización atómica, comprobación SHA-256 ni reversión. Son pendientes de 4A y 9A, no cambios de 0A.

Datos medidos de `arequipa.mbtiles`:

| Propiedad | Valor |
| --- | --- |
| Tamaño | 3.444.736 bytes |
| Teselas | 395 |
| Zoom almacenado | 0 a 14 |
| Formato/compresión declarados | PBF / gzip |
| Límites declarados `[oeste,sur,este,norte]` | `[-71.72,-16.6,-71.4,-16.26]` |
| Versión OpenMapTiles declarada | 3.16.0 |
| Planetiler declarado | 0.10.2 |
| Fecha de construcción declarada | 2026-03-28T14:35:36.815Z |
| Fecha de réplica OSM declarada | 2026-02-20T21:20:45Z |

Las fechas y versiones anteriores proceden de los metadatos del archivo; no son una verificación externa de la actualidad de sus datos.

Hay 12 capas vectoriales: aeroway, boundary, landcover, landuse, mountain_peak, park, place, transportation, transportation_name, water, water_name y waterway. No aparecen `poi` ni `housenumber` en los metadatos del tileset. El estilo tiene 28 capas y no referencia capas ausentes del esquema declarado.

El estilo usa `mbtiles://{MAP_DIR}/arequipa.mbtiles`, glifos `file://{MAP_DIR}/fonts/{fontstack}/{range}.pbf` y atribución a OpenMapTiles/OpenStreetMap. No declara sprites. Incluye Noto Sans Regular, Bold e Italic con los rangos 0–255, 256–511 y 8192–8447. No hay estilo oscuro ni alternativa web. El overzoom hasta z18 y el dibujo en modo avión siguen sin verificar en dispositivo.

## 7. Auditoría de GTFS y network.json

Los recuentos CSV excluyen la fila de cabecera y se obtuvieron con `csv.DictReader`, no contando líneas del archivo.

| Archivo | Registros | Tamaño | Observaciones |
| --- | --- | --- | --- |
| `routes.txt` | 192 | 14.689 bytes | Seis columnas; referencias de los trips y de los sentidos existentes válidas. |
| `trips.txt` | 240 | 6.768 bytes | `trip_id`, `route_id`, `service_id`, `shape_id`; sin referencias a rutas/shapes ausentes. |
| `shapes.txt` | 91.050 puntos, 192 shapes únicos | 3.418.594 bytes | Geometría de origen; no se alteró ni simplificó en 0A. |
| `stops.txt` | 6.711 | 375.625 bytes | 1.461 nombres `Innominada`, cero nombres vacíos y cero IDs duplicados. |
| `network.json` | 98 líneas agrupadas, 191 sentidos | 307.964 bytes | 11.527 puntos de geometría; IDs de línea únicos, coordenadas finitas y válidas `[lat, lon]`, al menos dos puntos por sentido. |

Diferencias respecto a las cifras indicadas en el plan:

- Los 6.712 del prompt corresponden al número de filas si se incluye la cabecera; hay 6.711 registros de paraderos.
- `network.json` contiene 98 sentidos de ida y 93 de vuelta: 93 líneas con dos sentidos y 5 con uno. No deben darse por supuestos dos sentidos por línea.
- Las cinco líneas con un solo sentido de ida tienen nombres `3`, `S`, `7-04`, `Simon Bolivar Horario` y `Simon Bolivar AntiHorario`. No se inventó un regreso.
- Una ruta CSV no figura como sentido en el JSON: `17684887`, nombre corto `C`, nombre largo `Custer C : La isla → Angeles del sur Zona A`, color `DBD9D1`. Se comprobó la diferencia de conjuntos; no se determinó ni corrigió su causa.

No hay `stop_times.txt`, `calendar.txt`, `calendar_dates.txt`, `agency.txt` ni `frequencies.txt`. Por tanto, estos archivos no constituyen un feed completo para reconstruir horarios publicados. Tampoco existe una relación ordenada entre cada patrón de línea y sus paraderos. La proyección geométrica y los supuestos explícitos de velocidades/frecuencias de las partes 1 y 2 serán necesarios; no se han calculado en esta sección.

No existen todavía `assets/city/arequipa/pack.sqlite`, `manifest.json`, tablas FTS, transbordos precalculados ni un generador de paquete. No se movieron los crudos fuera de assets.

## 8. Dependencias para el plan completo

Las versiones presentes son las resueltas en `pubspec.lock`, no versiones consultadas en un catálogo remoto. No se recomienda actualizar masivamente ni añadir paquetes por anticipado en 0B. Las alternativas SQLite requieren elegir una solución cuando se implemente la parte 1; no instalar todas.

| Necesidad del plan | Estado actual | Parte correspondiente |
| --- | --- | --- |
| Material 3 | Ya se usa con Flutter; tema claro. | 3C para temas completos |
| Riverpod (`flutter_riverpod`) | Ausente. | 3A |
| Navegación (`go_router`) | Ausente. | 3A |
| Ubicación (`geolocator`) | Presente, 14.1.2; no se importa desde `lib/`. | 3B, 4C, 6 |
| SQLite (`sqlite3`/`drift` o `sqflite`) | Ninguno presente. Faltan esquema, copia/versionado y consultas FTS. | 1D |
| MapLibre (`maplibre_gl`) | Presente, 0.27.1. | 4 |
| Directorios (`path_provider`) | Presente, 2.1.6. | 1D, 4, 9 |
| Preferencias (`shared_preferences`) | Presente, 2.5.6. | 3, 5, 7 |
| Localización (`flutter_localizations` del SDK, ARB/generación) | Sin configuración ni archivos ARB. | 3C |
| WebView (`webview_flutter`) | Ausente; tampoco hay assets del juego. | 7 |
| Compartir (`share_plus`) | Ausente. | 5 |
| Notificaciones (`flutter_local_notifications`) | Ausente. Falta elegir e implementar el mecanismo del servicio de ubicación en primer plano. | 6 |
| Firebase Core / Auth / Firestore | Presentes: 4.15.2 / 6.7.1 / 6.10.2. Configuración real pendiente. | 8 |
| Google (`google_sign_in`, si se adopta para el flujo nativo) | Ausente. | 8B |
| Firebase Crashlytics / Analytics | `firebase_crashlytics` y `firebase_analytics` ausentes. | 8, 9 |
| Hosting / App Distribution | Sin configuración completa ni scripts de distribución. Son herramientas/configuración, no una dependencia Dart obligatoria de la app. | 9 |
| Pruebas y lint | `flutter_test` del SDK y `flutter_lints` 6.0.0 presentes. | Ampliar por cada parte |

No se encontró Cloud Functions ni se requiere incorporarlo al plan. El nivel Spark de un proyecto remoto no puede comprobarse desde estos archivos y no se ha supuesto configurado.

## 9. Riesgos y pendientes, sin implementar

| Prioridad | Hallazgo y evidencia | Tratamiento previsto |
| --- | --- | --- |
| Alta | Mensaje incorrecto del segundo onboarding (`onboarding_screen.dart:26`) y tiempos demo sin indicador de aproximación (`planner_screen.dart:76`). | Limpieza de textos en 0B; cálculo y sustitución de datos de demostración en 2 y 5. |
| Alta | Los datos carecen de secuencias de paraderos y horarios; un sentido CSV no está en el JSON. | Investigar sin inventar datos al construir el paquete en 1. Registrar cualquier decisión antes de alterar la representación acordada. |
| Alta | Búsqueda y viajes siempre demo; el catálogo contiene ubicaciones repetidas y minutos constantes (`data/demo/demo_repositories.dart`). | Sustituir por consultas al paquete y planificador en 1, 2, 4 y 5. |
| Alta | Ubicación fija en el botón del mapa y el origen del viaje. `geolocator` instalado no implica GPS conectado. | Permisos y ubicación del usuario en 3B/4C; seguimiento solo durante el viaje en 6. |
| Alta | Instalación del mapa destructiva antes de completar la copia, con validación solo del marcador de versión (`offline_map_package.dart:31–35`). | Compatibilidad y pruebas de mapa en 4; sustitución atómica, hash y reversión en 9. |
| Alta | `firebase_options.dart` usa marcadores; faltan archivos nativos, reglas y emuladores. `firebase.json` menciona `mobility-lab-tecsup`, mientras las opciones Dart declaran `gowayki-lab-tecsup`. | Mantener demo. Antes de la parte 8, pedir el proyecto y los archivos reales; no inventar credenciales ni elegir un proyecto remoto. |
| Alta | `FirestorePreferencesRepository` escribe `profiles/{uid}`, diferente al esquema `users/{uid}/**` pedido en el plan. | Alinear repositorios, migración y reglas conjuntamente en 8; no publicar reglas incompatibles con las rutas existentes. |
| Alta | Android usa firma debug incluso en el tipo release (`android/app/build.gradle.kts`); iOS conserva nombre/bundle de `mobilityLab`. | Identidad, firma y revisión de lanzamiento en 9C. No se generó ni utilizó una firma de producción. |
| Media | iOS no contiene descripciones de uso de ubicación; Android solo declara Internet y ubicación aproximada/precisa, sin servicio de ubicación o permiso de notificaciones. No hay permiso de ubicación en segundo plano. | Configurar los permisos de 3B/6 y verificar iOS en macOS. |
| Media | `ServiceLocator` global, no reiniciable; navegación sin providers ni enrutador declarativo. | 3A, conservando contratos salvo necesidad justificada. |
| Media | Idioma persistido sin aplicarse, solo tema claro, sin estados de error completos; `PlannerScreen` no distingue error de carga y puede mantener el indicador indefinidamente. | 3C/3D y las pantallas de 4/5. |
| Media | El APK nativo genera advertencias en dependencias sobre KGP, APIs Java y lectura de metadatos SDK. | Registrar la línea base; revisar compatibilidad cuando una parte necesite actualizar paquetes. No son fallos del análisis Dart ni justifican actualizar todo ahora. |
| Media | Falta logo real y las 15 ilustraciones requeridas; assets actuales solo incluyen mapa y GTFS. | Pedir los archivos al llegar a 3B/7A. No generarlos ni sustituirlos por imágenes inventadas. |
| Media | Cobertura limitada a un smoke test. Faltan pruebas de datos, planificación, mapa, almacenamiento, reglas y flujos en dispositivo. | Incorporar únicamente las pruebas pertinentes a cada parte y distinguir mediciones de PC de las de un teléfono. |

## 10. Punto de control 0A (registro histórico)

Al cerrar la sección 0A, se entregó este documento y su punto de control. En ese momento la Parte 0 todavía no estaba terminada y no se creó un commit de cierre. El resultado posterior de 0B consta en la sección 11.

Tras recibir `CONTINÚA`, la sección 0B debe limitarse a limpiar los textos que prometen funciones inexistentes, identificar los tiempos como estimados, evaluar solo dependencias imprescindibles y comprobar análisis, pruebas y compilación Android. No debe implementar Riverpod/go_router, reescribir pantallas ni alterar GTFS. No se ha detectado una dependencia nueva necesaria para la limpieza de textos por sí sola.

El trabajo de las partes 1–9 permanece pendiente. La falta de ilustraciones o de configuración Firebase no bloquea esta auditoría documental; sí deberá resolverse antes de las secciones que las necesitan.

## 11. Cierre de la sección 0B y de la Parte 0

Fecha: 6 de noviembre de 2026. Las secciones anteriores conservan los hallazgos de la auditoría 0A; esta sección registra la limpieza posterior.

### Cambios realizados

- El segundo título del onboarding ahora dice `Rutas sin conexión`. Su descripción habla de consultar recorridos sin conexión y evita detalles internos de implementación.
- El origen fijo del planificador se muestra como `Origen de demostración`, en lugar de aparentar una posición obtenida del usuario.
- Las opciones se identifican como `Opciones de demostración` y sus duraciones llevan el indicador `~`.
- Se modificaron cinco cadenas en dos pantallas. No se cambió estructura visual, navegación, APIs ni lógica de cálculo.
- No se añadieron dependencias: la limpieza no requiere paquetes nuevos. `pubspec.yaml` y `pubspec.lock` permanecen intactos.
- No se modificaron datos GTFS, mapa, repositorios ni modelos. Los datos demo existentes siguen siendo demo; no se presentaron como cálculos de la futura red.

### Criterios de aceptación verificados

| Criterio | Resultado y evidencia |
| --- | --- |
| Expresiones prohibidas ausentes de `lib/` y de assets de texto | Cumplido: búsqueda insensible a mayúsculas con `rg`, cero coincidencias; excluidos únicamente los binarios MBTiles y PBF. |
| Tiempos visibles identificados como aproximados | Cumplido: la cadena de duración del planificador usa `~${o.durationMinutes} min`; la búsqueda de unidades de tiempo no encontró otra duración de viaje visible que requiriera limpieza. |
| Análisis sin advertencias | Cumplido: `flutter analyze --no-pub`, sin problemas, salida 0. |
| Pruebas existentes | Cumplido: `flutter test --no-pub`, 1 aprobada y 0 fallidas, salida 0. |
| Compilación Android después de la limpieza | Cumplido: `flutter build apk --debug --no-pub`, salida 0; APK debug generado. Gradle tardó 54,4 s. |
| Sin funciones nuevas, migración de navegación o cambios en GTFS | Cumplido: revisión del diff; solo dos archivos Dart con cambios de textos y este documento. |
| Integridad del diff | Cumplido: `git diff --check` sin incidencias. |

La compilación nativa mantiene las advertencias previas de compatibilidad KGP de dependencias Firebase y de lectura de metadatos SDK. No hubo errores de compilación ni advertencias del analizador Dart. No se actualizaron paquetes ajenos al alcance para eliminar avisos de sus herramientas.

Los registros de esta verificación quedaron dentro de `C:\Proyecto_001\.tools\logs\`: `parte0-analyze.log`, `parte0-test.log` y `parte0-build-android.log`. El APK está en `build/app/outputs/flutter-apk/app-debug.apk` dentro del repositorio.

### Límites y prueba manual

No se ha recorrido la interfaz en un dispositivo ni se ha compilado iOS en macOS. La prueba automatizada existente solo cubre el splash: no demuestra el funcionamiento completo del mapa, permisos o viajes. Estos límites no se confunden con los criterios de compilación y limpieza de la Parte 0.

Para comprobarlo manualmente, abre `C:\Proyecto_001\Abrir-VSCode.cmd`, conecta un teléfono Android con depuración USB y ejecuta `flutter run` en la terminal preparada. En una instalación nueva, la segunda diapositiva debe mostrar `Rutas sin conexión`. En modo demo, selecciona un destino y abre las opciones de viaje: deben mostrar el origen y las opciones como demostración, y los minutos con `~`. Para revisar el onboarding, usa una instalación de prueba nueva: el callback opcional `Volver` de la pantalla de acceso no está conectado en el flujo actual.

### Pendientes para otras partes

Se mantienen los pendientes de las secciones 4–9: paquete SQLite y relación de paraderos, discrepancia de una ruta CSV/JSON, planificador calculado, ubicación real, ilustraciones, arquitectura y navegación, traducciones y temas, mapa probado en dispositivo, juego y configuración real de Firebase. No se implementaron en 0B. Se mantienen también los avisos de herramientas nativas para revisar cuando corresponda actualizar sus dependencias.

La Parte 0 cumple sus criterios específicos. Su cierre se guarda en un commit local; no se hace push. El trabajo debe detenerse hasta que el usuario indique la siguiente parte.
