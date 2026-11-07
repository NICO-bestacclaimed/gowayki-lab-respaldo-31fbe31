# Cierre de la Parte 9 · GoWayki

Estado: implementación y verificación local completadas, incluidos dos APK release firmados. Validación remota y en dispositivos pendiente. Sin publicación ni push.

## Cambios y comprobaciones

- 9A: comprobación de versión remota, versión mínima de app, descarga HTTPS con límites, verificación de ambos archivos y SQLite/FTS, activación por puntero y reversión. Bloqueo durante viajes y eliminación de cuenta. Pruebas reales con revisión simulada v3 y rechazo de hashes/payloads incorrectos; assets originales siguen en v2.
- Hosting local generado con paquete/manifiesto y páginas de descarga, privacidad y términos. Responsable y contacto pendientes, sin inventarlos; borradores no publicados y predeploy bloqueado. No se escribió el documento remoto de ciudad.
- 9B: Analytics/Crashlytics integrados, recolección desactivada en builds actuales, eventos propios sin parámetros personales y errores Dart depurados. No se envían credenciales ni texto del usuario. Los SDK tienen metadatos técnicos propios y su recepción real no está certificada.
- App Distribution documentado con notas y lista de testers por archivo. No se subió ningún binario ni se envió ninguna invitación.
- 9C: firma release local con RSA 3072 y PKCS12 fuera de Git, propiedades privadas ignoradas, sin fallback a la firma debug. Nombre GoWayki y versión 1.0.0+1. Revisión final sin TODO/stub/nombres antiguos ni promesas de seguimiento de vehículos en las pantallas.
- Android elimina ACCESS_BACKGROUND_LOCATION, READ_PHONE_STATE, AD_ID y permisos de AdServices; conserva servicio de ubicación en primer plano y notificaciones. La revisión del APK inspecciona el manifiesto fusionado y lista todos los permisos heredados, no solo el archivo fuente.
- iOS: nombre GoWayki, bundle suministrado, textos de ubicación, modo de viaje y recolección desactivada revisados estáticamente. Destino mínimo iOS 15. Swift Package Manager y variable para Analytics sin soporte publicitario documentados. No compilado en Windows.

Pruebas: 203 Flutter completas, 18 dirigidas de observabilidad/actualización/juego y cuatro de observabilidad tras el ajuste final; análisis sin incidencias. Se conservan las 52 pruebas previas de reglas/protocolo y Auth en emuladores locales (no cambiaron las reglas). El APK debug Firebase de 9B compiló y verificó datos, mapa, ilustraciones, juego, SQLite FTS5 y recursos Firebase. Los JSON de cada punto documentan el artefacto comprobado, no certifican builds posteriores.

## Firma y artefactos

La clave local está en `C:\Proyecto_001\.tools\signing\gowayki-upload.p12`; las contraseñas están en `C:\Proyecto_001\gowayki_lab\android\key.properties`. Ambos deben preservarse y protegerse; no están en Git ni en los ZIP de código. Solo las huellas públicas aparecen en `docs/ANDROID_RELEASE_SIGNING.json`. La generación es idempotente y no sustituyó una clave existente. Es una candidata local de firma de subida; no se inscribió en Google Play ni se eligió una identidad legal a partir del nombre del certificado.

APK offline verificado: `build/app/outputs/flutter-apk/app-release-offline.apk`. APK Firebase verificado: `build/app/outputs/flutter-apk/app-release-firebase.apk`. Ambos pasaron verificación de firma, manifiesto, versión, nombre, datos, mapa, arte, juego y SQLite FTS5. La variante Firebase también cotejó sus recursos con la configuración suministrada. Las firmas difieren de debug; no se desinstaló ni modificó una app existente en el equipo o teléfono. Los símbolos quedan en `build/symbols/android/` (offline) y `build/symbols/android-firebase/` (Firebase); no se subieron automáticamente.

## Incidentes resueltos y advertencias

- La validación SQLite de descargas capturaba objetos de red en una clausura de isolate. Se trasladó a una función independiente y pasaron descarga/activación/reinicio/reversión y UI completa.
- El aviso global de resultado intentaba usar un tooltip sin Overlay ancestro. Se corrigió y quedó cubierto por una prueba de aplicación completa.
- Las versiones mayores nuevas de observabilidad requerían otro firebase_core. Se eligieron versiones compatibles sin migrar el resto de Firebase.
- La primera configuración release tenía una referencia ambigua a java.util.Properties en el DSL de Gradle. Se corrigió mediante import explícito; la clave no se reemplazó.
- La revisión nativa detectó permisos AdServices heredados de Analytics y se eliminaron para el release.
- Persisten avisos de KGP, XML de SDK y APIs Java obsoletas de dependencias. Están documentados; no equivalen a errores de funcionalidad probados ni justifican afirmar que las versiones futuras compilarán sin mantenimiento.

Prueba adicional de Hosting: emulador exclusivo en 127.0.0.1:5005 con proyecto demo; páginas, CSS, encabezados de seguridad, caché inmutable del paquete, manifiesto y descarga del APK offline aprobados. Se corrigió un problema de glob del emulador Windows usando patrones regex compatibles con barras de ambos sistemas. Servidor y Gradle quedaron detenidos. La comprobación predeploy sigue rechazando los borradores legales.

## Pendientes de lanzamiento

1. Definir responsable y correo, revisar/aprobar privacidad y términos, y configurar URL reales. Mantener los borradores sin publicar hasta entonces.
2. Crear Firestore Standard en el proyecto real y revisar/desplegar reglas e índices. Cargar metadatos/datos reales. El seed de pruebas sigue limitado al emulador.
3. Registrar la SHA-1 release `14:89:4E:B1:D0:53:93:C8:9B:1B:45:3E:56:17:43:1A:85:4F:6D:C2` en Firebase y actualizar el archivo Android antes de validar Google con esta firma; si Play vuelve a firmar, registrar también su certificado.
4. Comprobar Auth, sincronización, reportes, ranking y eliminación en el proyecto real, con la app y reglas finalmente desplegadas. Los emuladores no sustituyen esa comprobación.
5. Probar Android físico: mapa y modo avión, GPS, servicio/notificaciones, alarmas, WebView/sonido/vibración y rendimiento en gama media. Prueba visual de juego aplazada por el usuario.
6. Compilar/firmar y probar iOS en Mac y dispositivo Apple. Revisar símbolos/dSYM al habilitar observabilidad.
7. Revisar la ficha de tienda, icono de lanzamiento, licencias, políticas y declaraciones de datos antes de cualquier publicación. Habilitar observabilidad solo después de revisar su información/recepción y conservación; las builds actuales la mantienen apagada.
8. Autorizar y ejecutar por separado Hosting, reglas/datos y distribución a testers. No se ha realizado ninguna publicación externa ni push de Git.

Los pasos locales y comandos están en README, `docs/ACTUALIZACIONES_9A.md` y `docs/OBSERVABILIDAD_9B.md`. Estos pendientes son límites conocidos y entradas externas; no hay credenciales ni datos legales inventados para omitirlos.

Fuentes oficiales: [release Android en Flutter](https://docs.flutter.dev/deployment/android), [release iOS en Flutter](https://docs.flutter.dev/deployment/ios), [App Distribution CLI](https://firebase.google.com/docs/app-distribution/android/distribute-cli). Las verificaciones y resultados descritos provienen de las pruebas/artefactos locales de este proyecto.
