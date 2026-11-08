# Verificación Firebase con dispositivo

Estado: pendiente de ejecución funcional. Una configuración válida y pruebas con
dobles de repositorio no acreditan acceso, sincronización ni borrado en el servicio.

Proyecto: `gowayki-lab`. Android: `pe.edu.tecsup.gowayki_lab`.
La SHA-1 release `14:89:4E:B1:D0:53:93:C8:9B:1B:45:3E:56:17:43:1A:85:4F:6D:C2`
se registró el 2026-11-08. Configuración Android descargada y verificada con
`python tool/configure_firebase.py --require-google`.

Ejecutar en dispositivo con `USE_FIREBASE=true` y `ENABLE_OBSERVABILITY=false`.
Para validar Google release, usar la firma registrada, no sustituirla por debug.
Usar cuentas de prueba propias y registrar fecha, dispositivo, versión, resultado
y evidencia sin credenciales ni datos personales en Git.

| Flujo | Pasos y resultado esperado | Estado |
| --- | --- | --- |
| Correo | Crear cuenta, salir, entrar; contraseña incorrecta y recuperación; errores comprensibles sin perder estado | Pendiente |
| Google | Entrar y salir en release; cancelar selector; comprobar cuenta elegida y retorno a la app | Pendiente |
| Invitado | Crear sesión anónima y favoritos; reiniciar y comprobar persistencia | Pendiente |
| Vincular invitado | Vincular correo y Google por separado; conservar favoritos y UID; probar credencial ya vinculada sin perder datos | Pendiente |
| Favoritos | Añadir/quitar en dispositivo A; comprobar en B con la misma cuenta; cortar red, reconectar; cambiar cuenta y verificar aislamiento | Pendiente |
| Reportes | Crear reporte de prueba, confirmar desde otra cuenta una sola vez, retirar confirmación; verificar errores sin red | Pendiente |
| Ayuda | Enviar mensaje de prueba; comprobar recepción autorizada y mensaje de éxito; no duplicar envíos al reintentar | Pendiente |
| Ranking | Publicar puntaje, comprobar nombre visible y semana; puntaje menor no sustituye récord; comparar con otra cuenta | Pendiente |
| Borrado | Reautenticar, borrar una cuenta de prueba; verificar Auth y datos propios; contadores consistentes y marcador técnico vacío; reintentar tras interrupción | Pendiente |
| Actualización | Leer `cities/arequipa`; v2 no descarga sobre v2; comprobar HTTPS, hash y tamaño antes de una futura versión | Pendiente |

No borrar usuarios existentes ni crear reportes de prueba públicos sin coordinar
la cuenta, el dispositivo y la limpieza de esos datos. No cambiar reglas para
hacer pasar una prueba. Corregir solo fallos reproducidos y repetir el caso.
