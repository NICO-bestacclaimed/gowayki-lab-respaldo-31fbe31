# Cierre de la Parte8 — Firebase

Estado: código y pruebas locales de8A–8E completados en Windows. No equivale a validación de producción ni de ejecución física.

## Implementación

- Configuración Android/iOS real de gowayki-lab; OAuth suministrado por el usuario, opciones Dart y retorno de Google en iOS. Sin credenciales de ejemplo ni cuentas ficticias en formularios.
- Correo/contraseña, registro, recuperación, Google, invitado anónimo y vinculación conservando UID. Colisión con una cuenta Google existente resuelta con acceso a esa cuenta y migración local de los favoritos del invitado.
- Biblioteca por UID con copia local primero: Casa/Trabajo, lugares, paraderos, líneas, viajes guardados y máximo30 recientes activos. Revisión por elemento, borrados conservados como marcas, transacciones que rechazan revisiones antiguas y barrera de primera lectura del servidor. Cachés de cuentas reales separadas del invitado.
- Reportes con5 tipos, relación con paradero/línea/punto real, visibilidad72h en mapa/fichas y confirmación única por cuenta real. Ayuda con4 tipos y metadatos mínimos de versión/modelo/datos. Sin envío simulado ni éxito sin confirmación del servidor.
- Perfil con foto/nombre/correo de sesión, Arequipa, reportes propios, récord local, cierre y eliminación de cuenta. Ranking top20 semanal ISO de Arequipa (UTC-05), puesto propio con empates y cola local de puntajes para reintentar al recuperar conexión.

## Eliminación de cuenta y excepción de seguridad

Se reautentica antes de iniciar el borrado. El acceso/cierre de sesiones y la eliminación comparten un bloqueo de mutaciones de Auth: el SDK nativo de borrado trabaja sobre el usuario actual de la app. La limpieza mantiene fija la identidad verificada hasta completar los pasos locales. Google cancelado o contraseña incorrecta no inician el borrado.

Se pausa de forma persistente la sincronización, se drenan las escrituras en curso y se retiran las cachés personales/cola de puntajes de esa UID. Se eliminan feedback propio sin habilitar su lectura, confirmaciones propias con contador-1 exacto, reportes propios, puntajes de todas las semanas registradas, preferencias/biblioteca/estado privados y raíz users/{uid}; después Auth. Las referencias privadas se crean atómicamente y no pueden borrarse por separado durante el uso normal. Un reporte padre ya eliminado permite retirar su confirmación huérfana. Los lotes de feedback son pequeños para respetar los límites de lectura de reglas.

Excepción elegida para evitar resurrecciones: se conserva **deletedAccounts/{uid}, un documento vacío e inmutable**. Su identificador técnico permite bloquear escrituras de tokens antiguos después del borrado. No contiene nombre, correo, ubicación, reportes, comentarios ni puntajes. No se afirma que desaparezca todo identificador técnico de Firestore. La confirmación del producto explica esta conservación mínima; el usuario delegó la opción óptima para resolver el borrado y continuar con seguridad. El marcador es privado: solo su propia sesión puede consultarlo y ningún cliente puede modificarlo o eliminarlo.

Firestore y Auth no comparten una transacción. Si un paso falla, la app informa que la eliminación quedó incompleta y permite reintentar, manteniendo pausadas las subidas. También puede continuar después de sellar Firestore si falló el borrado de Auth. Otras instalaciones pueden conservar su caché local; sus tokens antiguos no pueden volver a crear contenido en Firestore. No se implementa borrado remoto del almacenamiento físico de un teléfono desconectado.

## Reglas/protocolos verificados

52 pruebas de emuladores aprobadas:47 de reglas/protocolo y5 de Authentication. Incluyen:

- Acceso privado por UID, rechazo de UID ajena, anónimo limitado a lo permitido y rechazo de subcolecciones no previstas.
- Reportes públicos, autor real, límites/tipos/coordenadas/tiempo, línea obligatoria en «ya no pasa», contador+1 emparejado, doble confirmación rechazada y vencimiento de confirmación.
- Feedback sin lectura cliente, campos/longitudes/metadatos validados y referencias privadas obligatorias/inalterables.
- Ranking público, dueño, tope/duración, récord mayor, referencia de cada semana, top20 y posición por puntuaciones estrictamente superiores.
- Excepción de borrado limitada a cuenta en eliminación: contador-1 y borrado emparejado de marcador/referencia; rechazo de decremento falso, incompleto, negativo o ajeno; reportes expirados/huérfanos; referencias huérfanas de feedback.
- Limpieza de25 feedbacks, preferencias, favoritos, reportes, confirmaciones y varias semanas de ranking, conservando otra cuenta. Interrupción y reanudación sin duplicar decrementos.
- Marcador vacío obligatorio al retirar la raíz, sin campos personales ni posibilidad de falsificación/edición/borrado. Una sesión antigua no puede recrear usuarios, biblioteca, reportes, feedback o puntajes.
- SDK Auth real de emulador: vinculación correo/Google conserva UID/favorito; colisión Google, recuperación local, contraseña incorrecta y eliminación Firestore+Auth conservando otra cuenta.

## Validación de app y Android

Suite completa de189 pruebas Flutter aprobada. Después de añadir el marcador final pasaron20 pruebas dirigidas de identidad, perfil, ranking y eliminación. Análisis final sin incidencias. Se verificaron colas offline, reconocimientos antiguos, cambios de cuenta, semanas ISO/año y cambio de semana al estar abierta la pantalla, cancelación/contraseña incorrecta, fallos parciales y espera de subidas personales/de ranking en curso.

Ambos APK debug finales, USE_FIREBASE=true/false, compilados. Datos reales, mapa, imágenes, juego y SQLite FTS5 verificados; recursos Firebase/cliente web coinciden con los archivos del usuario. Manifest sin ACCESS_BACKGROUND_LOCATION, READ_PHONE_STATE ni AD_ID. Los JSON VERIFICACION_APK_8E_* y VERIFICACION_PERMISOS_8E_* registran los artefactos finales. Las rutas app-debug.apk y app-debug-firebase.apk siempre contienen la última compilación; los JSON anteriores son comprobaciones históricas. Gradle y emuladores detenidos.

## Pendiente y percances

Cloud Firestore real aún no creado; el usuario autorizó continuar con emuladores. No se desplegaron reglas/índices/seed ni se crearon o borraron usuarios del proyecto real. Faltan proveedores/flujo Google y correo comprobados en dispositivo, sincronización/reportes/ranking/borrado reales entre teléfonos, GPS/notificaciones/sonido/vibración/MapLibre/WebView físicos, rendimiento Android de gama media e iOS con macOS/Xcode. La prueba visual del minijuego sigue aplazada por el usuario.

Los fallos detectados y corregidos fueron esperas de proveedores, proyecciones que no publicaban el estado a tiempo, temporizadores de contenedores de prueba sin cerrar, navegación de test que debía desplazar el perfil ampliado y la carrera entre escrituras pendientes/cambio de sesión/borrado. La señal de seguridad se añadió al comprobar que un token antiguo podría recrear datos tras retirar la raíz. Persisten avisos de compatibilidad futura KGP/Java/metadatos SDK, sin fallos de compilación actuales.

Próximo: Parte9. El usuario confirmó que responsable/correo de privacidad y términos aún no están definidos; mantener borradores sin publicar. Las URL legales siguen configurables y deshabilitadas. No se han publicado Hosting, distribución ni commits remotos.

Fuentes primarias: [Auth Flutter](https://firebase.google.com/docs/auth/flutter/manage-users), [transacciones](https://firebase.google.com/docs/firestore/manage-data/transactions), [reglas](https://firebase.google.com/docs/rules/unit-tests). La firma nativa delete(pigeonDefault) se revisó en firebase_auth_platform_interface9.1.0 instalado.
