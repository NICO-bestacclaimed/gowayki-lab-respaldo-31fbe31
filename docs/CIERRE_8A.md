# Punto de control 8A — configuración Firebase y reglas

Estado: verificado en Windows para esta sección. La Parte8 completa sigue en curso. Los nuevos archivos OAuth con sufijo(1) se detectaron al final de la sección y se incorporan al iniciar8B.

## Hecho

Configuraciones iniciales reales de Android/iOS validadas para gowayki-lab, integradas en sus rutas y opciones Dart. Plugin Google Services4.5.0 y recurso Xcode configurados. firebase.json/.firebaserc, reglas, índices, seed local derivado del pack real y herramientas de prueba fijadas. No se publicaron datos ni reglas al proyecto real.

## Verificación

- Flutter analyze: No issues found.
- Flutter test: 133 aprobadas, incluidas3 de configuración y plataformas.
- Firestore Emulator: 28 pruebas aprobadas; lectura/escritura privada por uid, reportes públicos y creación no anónima, rechazo de uid/tipos/longitudes/coordenadas manipulados, confirmación atómica exactamente+1, voto duplicado y reporte expirado rechazados, feedback de solo creación sin lectura cliente y ranking con límites y récord creciente.
- Script independiente de seed probado en demo-gowayki-lab; no contiene una URL ficticia de actualización.
- APK USE_FIREBASE=true: 233298356 bytes; SHA-256 `e04ed5475d8614e81a943a43859e8f2d4cfe91915e52e76ae80bd22e9d4e694e`. Conservado como build/app/outputs/flutter-apk/app-debug-firebase.apk.
- APK USE_FIREBASE=false: 270919188 bytes; SHA-256 `2bd27a8a3e64d3983e174d638fd19a29709b06a3520273878592e5d3c05ef7b8`. Es el app-debug.apk predeterminado.
- Ambos APK: datos, mapa,18 archivos de juego y SQLite FTS5 verificados. Recursos nativos Firebase coinciden con el cliente suministrado. Manifest sin ACCESS_BACKGROUND_LOCATION.
- Emuladores y daemon Gradle detenidos tras las pruebas.

## Percances y pendientes

El análisis se ralentizó al encontrar ejemplos Dart dentro de node_modules de Firebase CLI. Se excluyó esa carpeta de herramientas, preservando el análisis de toda la app. Los rechazos PERMISSION_DENIED de la suite son resultados esperados de los casos negativos y no fallos de las pruebas. Persisten avisos de compatibilidad futura KGP/Java/SDK y de APIs de dependencias nativas; las compilaciones concluyeron correctamente.

El seed actual se limita al emulador. No se verificó autenticación real, estado de proveedores, base Firestore del proyecto, despliegue, sincronización, reportes o eliminación de cuenta: pertenecen a8B–8E. iOS y ejecución física Android siguen sin validar. La prueba visual del minijuego permanece aplazada por el usuario. Los detalles y contratos están en FIREBASE_8A.md.
