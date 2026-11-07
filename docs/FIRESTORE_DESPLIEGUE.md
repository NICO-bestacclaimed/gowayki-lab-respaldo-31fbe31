# Primer despliegue real de Firestore

Verificado el 2026-11-07, tras la autorización del usuario para empezar por reglas e índices y completar el acceso de la CLI mediante Google en el navegador.

- Proyecto: `gowayki-lab`; base `(default)`; Firestore Native, edición Standard.
- Las reglas compilaron en el servidor y quedaron publicadas. El contenido activo coincide por SHA-256 con `firestore.rules`.
- Los cinco índices compuestos configurados en `firestore.indexes.json` quedaron en estado `READY`: cuatro para reportes y uno para ranking.
- No había índices compuestos ni excepciones de campos previas que eliminar. Se guardó una copia de las reglas remotas anteriores y de la configuración/índices antes de desplegar.
- La autorización quedó en la configuración local de la CLI bajo `C:\Proyecto_001\.tools\firebase-config`. No se guardan cuentas, tokens ni credenciales en este comprobante o en Git. Las opciones adicionales de Gemini y recolección de uso de CLI se mantuvieron desactivadas.

El comprobante técnico está en `FIRESTORE_DESPLIEGUE.json`; contiene reglaset, hash, índices, estado, fecha UTC y ruta del respaldo anterior. La construcción de índices tardó unos minutos; el primer límite de espera terminó con construcción pendiente y la consulta posterior confirmó los cinco listos, sin volver a desplegar ni modificar datos.

La ejecución se limitó a reglas e índices. No se creó `cities/arequipa`, ninguna cuenta de Authentication ni documentos de aplicación. Tampoco se desplegó Hosting, distribuyó un APK ni cambió la configuración de proveedores de acceso. Las reglas conservan el alcance ya probado en emuladores: datos privados por propietario, reportes y confirmaciones validados, feedback sin lectura de cliente, ranking limitado y eliminación de cuenta con marcador técnico privado.

La comprobación administrativa no valida todavía los flujos desde el APK. El siguiente paso es inicializar los metadatos reales de ciudad; luego registrar la firma release para Google y probar la aplicación en dispositivo según corresponda.

Para repetir únicamente la comprobación de lectura, activar el entorno y las variables de configuración de la CLI indicadas en README y ejecutar `node tool/verify_firestore_live.cjs`. Usa las bibliotecas de la versión local fijada de firebase-tools; no crea índices, publica reglas ni lee/escribe documentos de usuario.
