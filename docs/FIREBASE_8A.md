> Documento histórico del punto8A. El contrato final, incluidas las excepciones de eliminación y el marcador técnico, está en [CIERRE_PARTE8.md](CIERRE_PARTE8.md).

# Firebase — configuración y reglas 8A

## Configuración recibida y validada

Proyecto real: gowayki-lab. Android: pe.edu.tecsup.gowayki_lab. iOS: pe.edu.tecsup.mobilityLab. Ambos clientes pertenecen al mismo proyecto y número de remitente. Se copiaron los archivos originales a android/app/google-services.json e ios/Runner/GoogleService-Info.plist, conservando los originales de C:\Proyecto_001. Sus hashes y los identificadores públicos están en FIREBASE_CONFIG_8A.json. Las opciones Dart se generan de esos archivos mediante tool/configure_firebase.py, sin crear aplicaciones remotas ni inventar valores.

Android usa Google Services4.5.0 en settings.gradle.kts y app/build.gradle.kts; los SDK nativos siguen administrados por los plugins FlutterFire existentes. iOS incluye el plist como recurso del target Runner; iOS15 ya era el mínimo del proyecto. No se puede compilar Xcode desde este Windows.

USE_FIREBASE=false sigue siendo el valor predeterminado. 8A prepara configuración y reglas; no completa las pantallas ni repositorios de autenticación, sincronización y reportes de 8B–8E. Una compilación con USE_FIREBASE=true verifica el código, no una sesión real ni el estado de los servicios del proyecto.

## Reglas y contrato

- cities/{cityCode}: lectura pública; administración fuera de la app.
- users/{uid}/**: solo el mismo usuario autenticado puede leer/escribir sus documentos y subcolecciones.
- reports/{id}: lectura pública, creación por cuenta no anónima con uid propio, ciudad Arequipa, tipo conocido, descripción3–500 caracteres, coordenadas numéricas válidas, createdAt del servidor y contador inicial0. Los campos opcionales stopId/lineId se limitan a128 caracteres. El texto y autor del reporte no se modifican desde la app; borrar exige ser el autor.
- Confirmar un reporte usa una operación atómica: aumentar confirmations en exactamente1 y crear reports/{id}/confirmations/{uid} con el uid propio y fecha del servidor. Los dos lados comprueban el estado posterior mediante getAfter. No se puede volver a confirmar ni borrar/editar el marcador para votar otra vez. Se rechazan confirmaciones de reportes con más de72h.
- La visibilidad de reportes durante72h se implementa en8D consultando createdAt con el corte temporal; las reglas mantienen su lectura pública. No existe borrado automático, TTL ni Cloud Function configurados.
- feedback/{id}: solo creación por autenticados, incluidos invitados. uid propio, kind de bug/idea/incorrect_data/other, mensaje3–2000, ciudad, fecha del servidor, versión de app, modelo del dispositivo y versión de datos. Ningún cliente puede leer, actualizar o borrar feedback. El repositorio/UI heredado se adaptará al contrato al implementar8D; no se declara verificado con el servicio real en8A.
- leaderboards/{arequipa_YYYY-Www}/scores/{uid}: lectura pública, creación por el uid propio, puntaje entero0–5000, duración1000–120000ms y límite razonable por duración. Actualizar exige aumentar el récord y conservar createdAt; uid ajeno, puntaje igual/menor y campos adicionales se rechazan. Se permite al propietario borrar su registro para su eliminación de cuenta. Esto no equivale a un sistema antitrampas: el juego es local y no tiene verificador de partidas en servidor.
- Las colecciones no declaradas se deniegan.

Los índices compuestos de reportes y ranking están en firestore.indexes.json. La eliminación completa de una cuenta y la retención de marcadores/feedback deben resolverse al implementar8E, conservando las restricciones anteriores; esta etapa no afirma haber completado esa función.

## Pruebas aisladas

Herramientas dentro de tool/firebase/node_modules, con package-lock.json fijado: Firebase CLI15.35.0, rules-unit-testing6.0.0 y Firebase JS13.2.0. Node24.21.0; JDK25. Firestore Emulator1.22.0. El análisis Dart excluye las plantillas de esos paquetes Node.

```powershell
. C:\Proyecto_001\Entorno.ps1
# Desde C:\Proyecto_001\gowayki_lab
$env:npm_config_cache='C:\Proyecto_001\.tools\npm-cache'
npm ci --prefix tool/firebase --no-fund --no-audit
.\tool\test_firebase.ps1
.\tool\test_firebase.ps1 -SeedOnly
```

El wrapper usa host127.0.0.1, proyecto demo-gowayki-lab, puertos locales y cachés en .tools. No inicia sesión. El seed independiente exige FIRESTORE_EMULATOR_HOST de loopback y proyecto demo-, por lo que no escribe datos en el proyecto real. Toma versión, hash, tamaño y fecha del manifest instalado; el centro es el punto medio de sus límites, identificado como installed_pack_bbox_midpoint. No publica una URL de actualización inexistente.

La consola muestra PERMISSION_DENIED en los casos de rechazo intencionales; el resultado final de la suite determina si son los esperados. El seed, las reglas y la propiedad de datos se prueban contra Firestore Emulator, no con mocks de reglas.

## Pendiente de Google para8B

Los archivos iniciales no incluyen el cliente web OAuth Android ni CLIENT_ID/REVERSED_CLIENT_ID iOS. El usuario indicó «Lo haré y te aviso» tras recibir los pasos de activación. Huella SHA-1 pública del APK debug de este entorno:

9F:B3:3A:A3:24:E4:F5:79:9B:67:AF:B7:C7:A9:5B:E4:78:E4:14:9F

Agregarla en Firebase, habilitar proveedor Google y volver a descargar ambos archivos. Después volver a ejecutar tool/configure_firebase.py y validar su contenido antes de conectar Google Sign-In. Correo/contraseña y anónimo también deben habilitarse para usar esos métodos en el proyecto real. No se deduce que los proveedores estén habilitados por la mera presencia de archivos.

## Alcance del punto de control

No se desplegaron reglas, índices, Hosting ni el seed al proyecto real; no se crearon usuarios reales. firebase.json declara Hosting para la etapa posterior y no se publicó una página de ejemplo ni una URL inventada. La prueba visual del juego sigue aplazada por el usuario. GPS, notificaciones, audio, WebView y rendimiento Android físicos siguen pendientes; iOS requiere macOS/Xcode.

Fuentes primarias: [configuración Flutter](https://firebase.google.com/docs/flutter/setup), [Google Services](https://firebase.google.com/docs/android/google-services-plugin-and-file), [pruebas de reglas](https://firebase.google.com/docs/rules/unit-tests), [operaciones atómicas](https://firebase.google.com/docs/firestore/manage-data/transactions#data_validation_for_atomic_operations), [Google Sign-In](https://firebase.google.com/docs/auth/flutter/federated-auth).
