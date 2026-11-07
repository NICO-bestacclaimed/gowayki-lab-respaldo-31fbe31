# Cierre de la Parte 7 — Wayki Combi

Estado: PARCIAL en aceptación. Código, pruebas automatizadas y APK verificados; navegador visual y equipo físico pendientes. El usuario autorizó posponer la prueba del navegador: «se puede realizar la prueba despues?». No se declara completada esa validación.

## Implementación

Runner Canvas de tres carriles, pasajeros +10, monedas S/1, conos, baches y autos, tres vidas e invulnerabilidad breve tras chocar. Velocidad creciente, hasta 90 segundos activos, pausa/reinicio, teclado A/D y flechas, botones y deslizamiento. Pausa al ocultar página o minimizar app. Misti y sillar dibujados en Canvas; sin fuentes, librerías ni audios descargados. Sonido sintetizado opcional.

Las 15 ilustraciones suministradas se usan como sprites derivados de 96×96, recortados por transparencia y reducidos localmente con Pillow 13.0.0, calidad WebP45. Los originales se preservan y sus hashes se verifican. Selector con desbloqueo por récord personal cada 25 puntos; ningún pago ni ranking remoto.

Peso total sin comprimir, contando HTML+CSS+JS y TODOS los sprites: **67045 bytes**, en 18 archivos; límite estricto de 150000 bytes. Las 15 copias gráficas suman 47734 bytes. No se excluyeron imágenes compartidas para aparentar un tamaño menor.

Flutter usa webview_flutter4.14.1, loadFlutterAsset y canal GoWayki. Recibe puntaje/duración al terminar, preferencias de sonido y eventos hápticos; rechaza mensajes inválidos, desmesurados o de tipos incorrectos. Récord y sonido persistidos con escrituras serializadas, conservando el máximo anterior. Flutter envía nombre, récord, idioma y configuración de vibración. Perfil y Viaje en curso abren la pantalla real en Android/iOS; Windows permite abrir index.html manualmente. El seguimiento activo conserva su servicio al abrir el juego.

CSP bloquea red y recursos externos; el delegado WebView solo admite navegar al index local del bundle. No se realizó envío de datos a Firebase ni a terceros.

## Evidencia

- flutter analyze --no-pub: No issues found.
- flutter test --no-pub: 130 aprobadas, incluidas 4 nuevas del canal/persistencia.
- node --check assets/game/game.js: correcto.
- node tool/test_game.mjs: 8 pruebas aprobadas de carriles, colisiones, puntajes, pausa, límite de tiempo, velocidad y reinicio.
- tool/verify_game.py: peso,15 sprites, archivos locales, ausencia de referencias remotas y hashes de originales correctos.
- APK debug: 241992563 bytes; SHA-256 `04272f3b869eec1d057d9f5184ef63e2fafeea3fd8570b57bfce768c7a6e6fb7`.
- APK: 18 archivos del juego iguales a los del proyecto; datos versión2,16 gráficos originales,12 archivos del mapa y SQLite FTS5 en3 ABI correctos. Permisos del viaje conservados y ACCESS_BACKGROUND_LOCATION ausente.
- Gradle detenido al finalizar.

## Percances y límites

El navegador integrado rechazó file:// por su política de URL. Se cerró la tarea de CUA con ese resultado y no se intentó eludir la restricción mediante otros navegadores, CDP o cargas remotas. El usuario pospuso la comprobación manual. Por ello NO se verificaron visualmente Canvas, selector, controles y sonido del navegador; las pruebas de lógica no sustituyen esa comprobación.

La integración nativa compila, pero no se ha ejecutado en Android/iOS: carga WebView, mensajes reales de su canal, modo avión, audio y vibración físicos pendientes. iOS no compila en este Windows. Las restricciones de sonido/haptics del sistema prevalecen.

Se corrigió la configuración durante partida para que cambiar un ajuste no abra una superposición sin pausar. Se añadieron subpasos de colisión para cuadros lentos, validación de almacenamiento corrupto, gestos compatibles con iOS antiguo y protección contra callbacks de cargas reemplazadas. No se afirma que estas correcciones se hayan probado visualmente.

## Prueba manual aplazada

Abrir C:\Proyecto_001\gowayki_lab\assets\game\index.html en el navegador. Verificar carga de las15 combis, bloqueos por récord, empezar, mover con flechas/A/D y botones, recoger pasajeros/monedas, chocar, pausar/continuar, cambiar pestaña y reiniciar. Terminar partida, recargar y comprobar récord. Repetir tamaño de ventana pequeño. En Android/iOS repetir desde Perfil y Viaje en curso, en modo avión y comprobando que las alertas del viaje siguen disponibles.

Para regenerar sprites: instalar tool/game-requirements.txt en el entorno local y ejecutar tool/build_game_sprites.py. Para verificar: node tool/test_game.mjs, Python tool/verify_game.py y tool/verify_apk.py tras un build nuevo. No se hizo push ni despliegue.

## Siguiente bloqueo — Parte8

No se inició Firebase: faltan android/app/google-services.json y ios/Runner/GoogleService-Info.plist en toda la carpeta autorizada, y firebase_options.dart contiene REEMPLAZAR_API_KEY/APP_ID/SENDER_ID. firebase.json y las opciones también nombran proyectos diferentes; no se eligió uno por suposición. Hace falta la configuración real del mismo proyecto para continuar. Se conserva USE_FIREBASE=false.

La regla adoptada del archivo gowayki_prompt_chat_codex.md, Parte8, exige: «si no existe google-services.json / GoogleService-Info.plist o proyecto Firebase, haz STOP inmediato y dímelo. No inventes credenciales». Se detiene aquí el avance funcional y se guarda este punto de control.
