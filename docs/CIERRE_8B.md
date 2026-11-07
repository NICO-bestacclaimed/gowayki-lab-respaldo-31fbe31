# Punto de control 8B — autenticación

Implementados correo/contraseña, registro validado sin credenciales precargadas, recuperación de contraseña, Google y acceso anónimo. La conversión del invitado vincula credenciales conservando su UID. Si Google ya pertenece a otra cuenta, se inicia esa sesión; la integración de datos locales corresponde a 8C. Errores localizados es/en, cancelación silenciosa de Google y modo local sin cuentas ficticias.

Los archivos OAuth nuevos suministrados por el usuario están integrados: cliente web en Android, clientes/URL de retorno de Google en iOS. El importador valida proyecto, aplicaciones, sufijos y URL inversa; no crea credenciales ni realiza llamadas a la nube.

Verificación: 149 pruebas Flutter aprobadas; análisis limpio tras corregir un aviso de estilo. 32 pruebas de emulador (28 reglas y4 autenticación): vinculación anónimo→correo/Google conserva UID y favorito privado, cambia el proveedor del token y habilita reportes; colisión con cuenta Google existente, contraseña incorrecta, recuperación y cierre de sesión. 9 pruebas del adaptador y7 de formulario incluidas en Flutter. APK Android con Firebase compilado; recursos del proyecto y cliente web coinciden con la configuración proporcionada; datos/mapa/juego/SQLite comprobados. Daemon Gradle detenido.

Pendientes reales: el usuario confirmó proveedores habilitados, pero aún no creó Cloud Firestore. Se continúa con emuladores y se aplaza la comprobación en nube. Interfaz nativa Google, correo recibido, iOS y ejecución física Android no se han probado. El APK de esta sección usa USE_FIREBASE=true; la regresión de modo local pasó en tests y ambos modos se recompilarán al completar la siguiente integración.

Decisión autorizada por el usuario: durante la eliminación de cuenta se borrarán sus comentarios y confirmaciones, ajustando los contadores afectados con una excepción estricta a las reglas de8A. Se implementará en8E; no se eliminó ninguna cuenta real.
