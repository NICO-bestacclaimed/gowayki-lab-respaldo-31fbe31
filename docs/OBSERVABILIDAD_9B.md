# Parte 9B: observabilidad y distribución

## Integración local

Se incorporan `firebase_analytics 12.6.1` y `firebase_crashlytics 5.4.1`, compatibles con `firebase_core 4.15.2`, sin cambiar las versiones de Auth/Firestore ya verificadas. Android incorpora el complemento Crashlytics Gradle 3.0.8; la subida automática de mappings y símbolos nativos está desactivada en todos los tipos de build. No se ejecutó `flutterfire configure` contra la nube ni se modificaron aplicaciones remotas.

Analytics y Crashlytics están desactivados por defecto en Android e Info.plist. Android no incluye AD_ID, desactiva identificadores publicitarios y no inicializa Firebase mediante FirebaseInitProvider: Dart lo hace solo con `USE_FIREBASE=true`. iOS desactiva IDFV y la captura automática de pantallas. El backend deja sin identificador de usuario los SDK y no agrega propiedades de cuenta. Cuando está desactivado, se descartan los informes de Crashlytics pendientes. Esto no borra informes ya recibidos por el servidor.

La activación preparada exige simultáneamente Firebase, Android/iOS, release y `ENABLE_OBSERVABILITY=true`. Las builds actuales mantienen esa bandera en `false`; su activación se deja para después de completar/revisar privacidad y condiciones del lanzamiento. El modo local y las plataformas sin soporte no construyen el backend Dart. Si la configuración del SDK falla, la app usa una implementación silenciosa.

Los únicos eventos propios son `gowayki_app_ready`, `city_update_applied`, `city_update_rejected` y `game_completed`. No reciben mapas de parámetros ni texto libre: la interfaz acepta únicamente valores de un enum. No incluyen UID, correo, nombres, búsquedas, lugares, coordenadas, rutas, reportes, puntajes o mensajes del formulario. Los errores Dart propios usan códigos fijos y trazas reducidas a archivos del paquete y números de línea; no se envía el mensaje original ni sus datos adicionales. Los manejadores de errores Flutter y asíncronos solo se instalan cuando la observabilidad está habilitada. Un fallo del SDK no convierte una acción de producto en un error.

La depuración de trazas reduce el detalle disponible, sobre todo en release. Los SDK pueden generar identificadores técnicos y metadatos de dispositivo/sesión y los fallos nativos tienen su propio contenido. Por tanto, esta integración no declara que toda la telemetría sea anónima ni que los eventos automáticos del SDK tengan exactamente la misma forma que los eventos propios. Su recepción, retención y declaraciones de privacidad/Data safety deben revisarse antes de activar.

## iOS y símbolos

El proyecto usa Swift Package Manager. El plugin instalado admite el paquete sin soporte publicitario mediante `FIREBASE_ANALYTICS_WITHOUT_ADID=true` en el entorno que resuelve/compila paquetes. En un Mac, usar esa variable al compilar. No se añadió un script de subida automática de dSYM: no hay despliegue autorizado ni compilación Mac verificada. La configuración y la recepción de informes deben probarse en un dispositivo de ensayo antes de activar observabilidad en producción.

## App Distribution: comando preparado, no ejecutado

Primero habilitar App Distribution para la aplicación correcta desde la consola, autenticar la CLI con la cuenta del equipo, verificar APK/firma y preparar una lista real de testers fuera de Git. `--app` es el identificador Firebase de Android, no el package name. Ejemplo desde la raíz, después de revisar el artefacto y con autorización para distribuir:

```powershell
node tool/firebase/node_modules/firebase-tools/lib/bin/firebase.js appdistribution:distribute build/app/outputs/flutter-apk/app-release.apk --app 1:959294066022:android:3ab035e603ff2ab4998ca7 --project gowayki-lab --release-notes-file docs/release-notes.txt --testers-file C:\Proyecto_001\.tools\distribution\testers.txt
```

Ese comando sube el binario y envía invitaciones; no debe usarse como una comprobación local. No se ha creado una lista de correos, autenticado la CLI, invitado personas ni subido una versión. Para símbolos Flutter de una compilación que use `--split-debug-info`, conservar el directorio y subirlo por separado a la misma app con `firebase crashlytics:symbols:upload --app <ID_FIREBASE> <DIRECTORIO_SIMBOLOS>` tras autorización. Los mappings R8 y dSYM requieren su procedimiento nativo correspondiente; no asumir que este comando los sustituye.

## Verificación

Pruebas dirigidas de observabilidad, actualización e integración del juego: 18 aprobadas. Cubren condiciones de activación, backend ausente en modo local, eventos fijos, eliminación de texto/rutas privadas/URLs de las trazas y fallos del SDK sin propagación. Las pruebas usan implementaciones sustitutas y no envían telemetría. Compilación y permisos se registran en los JSON de verificación de 9B; recepción real en las consolas y funcionamiento físico siguen sin comprobarse.

Fuentes oficiales consultadas: [Crashlytics para Flutter](https://firebase.google.com/docs/crashlytics/flutter/get-started), [recolección optativa de errores](https://firebase.google.com/docs/crashlytics/flutter/customize-crash-reports), [control de Analytics en Android](https://firebase.google.com/docs/analytics/android/configure-data-collection), [App Distribution con CLI](https://firebase.google.com/docs/app-distribution/android/distribute-cli). Las decisiones de desactivar recolección, depurar trazas y mantener la publicación pendiente corresponden a esta implementación.

Resultado final local: 203 pruebas Flutter completas y cuatro dirigidas tras el ajuste de recuperación, análisis sin incidencias y APK debug con Firebase compilado. Assets, hashes, SQLite FTS5, recursos Firebase y permisos verificados; Gradle detenido. Persisten advertencias de KGP de los plugins y XML de SDK, sin impedir la compilación.
