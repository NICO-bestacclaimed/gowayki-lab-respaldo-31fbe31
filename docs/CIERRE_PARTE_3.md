# Cierre de la Parte 3 — navegación, identidad y configuración

Implementación 3A–3D completada. El usuario autorizó continuar entre secciones salvo conflicto y confirmó que por ahora las pruebas se realizan en Windows. No se certifican ejecución ni rendimiento en teléfono.

## Resultado

- Repositorios Riverpod sustituibles en pruebas y recursos asociados a su ámbito; eliminado ServiceLocator estático.
- Navegación go_router con Explorar, Rutas, Favoritos y Perfil. Las 98 líneas proceden del SQLite; favoritos locales persistentes y estados vacíos reales.
- Splash durante la carga del paquete, logo original y onboarding de tres pantallas con las 15 ilustraciones suministradas. Las 16 copias conservan sus hashes originales. Bienvenida solo la primera vez; explicación de ubicación antes de solicitar el permiso, con salida sin concederlo.
- Ajustes locales: Arequipa como única ciudad instalada; idioma español de Perú/inglés/sistema mediante 124 recursos ARB; tema claro/oscuro/sistema; acceso peatonal automático o límite explícito de 400/800/1.000/1.500 m; evitar transbordos; aviso por sonido/vibración/desactivado. Las escrituras simultáneas conservan los cambios.
- Adaptación de preferencias para el núcleo del planificador: un límite explícito fija tanto acceso como ampliación, y evitar transbordos permite un solo abordaje. Su conexión con la pantalla final de resultados corresponde a la Parte 5; los avisos se ejecutarán en la Parte 6.
- Versión y fecha del paquete instalado, botón de actualización deshabilitado hasta la Parte 9, atribuciones OpenStreetMap/OpenMapTiles con enlaces reales.
- El usuario confirmó que privacidad y términos aún no existen. Se mantienen desactivados, con aviso; pueden configurarse con `--dart-define=PRIVACY_URL=...` y `--dart-define=TERMS_URL=...`. Solo se aceptan URL HTTP/HTTPS válidas. No se publicaron documentos legales.
- Componentes compartidos de vacío, error, GPS apagado, permiso, sin resultados, fuera de servicio y skeleton sin animación permanente. Se usan en carga de líneas y ajustes.

## Verificación

- `flutter analyze`: sin observaciones.
- `flutter test`: 63 aprobadas, cero fallidas. Incluyen navegación, persistencia, onboarding, permisos simulados, traducción inmediata, modo oscuro, ajustes, estados reutilizables, integridad de arte y las pruebas anteriores del paquete/planificador.
- `flutter build apk --debug`: correcto. APK local de 240.903.110 bytes, SHA-256 `76c9655869bf68a2d9793d5d346df15f70d03b9b7a0fabaa9ff51f706386505f`.
- `tool/verify_apk.py`: manifiesto y datos revisión 2, 16 imágenes, ausencia de GTFS antiguo y bibliotecas SQLite ARM/ARM64/x64 verificadas contra hashes oficiales antes del recorte de símbolos y contra la salida recortada de Gradle. FTS5 presente en las tres. Evidencia en `docs/VERIFICACION_APK_PARTE_3.json`.
- Gradle detenido al finalizar. No se hizo push ni despliegue.

## Percances y límites

Se corrigieron la ordenación de una lista inmutable en el selector de combis, la superficie Material de sus filas y las esperas de inicialización/guardado observadas en el reloj simulado de las pruebas. Las pruebas finales pasan.

Persisten los avisos de compatibilidad futura de plugins Firebase/Kotlin, acceso nativo Java y metadatos del SDK Android; no impidieron compilar. No se cambiaron versiones por esos avisos.

El mapa y la pantalla anterior de viajes siguen pendientes de las Partes 4 y 5, respectivamente; el modo oscuro de cartografía se implementa en la Parte 4. No se añadieron login nuevo, Firebase remoto ni juego. La interfaz de resultados anterior conserva datos de demostración identificados como tales. iOS no se compiló en Windows y el permiso real, el mapa en modo avión y el rendimiento Android aún necesitan un dispositivo.

## Continuación

Parte 4A: mapa base, overzoom, estilo oscuro y documentación de regeneración. No existe archivo/URL PMTiles ni Hosting configurado; se consultó al usuario si ya dispone de URL o si se prioriza Android. No se inventará una dirección de servidor.
