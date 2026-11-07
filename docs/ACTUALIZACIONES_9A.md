# Parte 9A: actualización del paquete y Hosting local

## Comportamiento implementado

Ajustes permite buscar actualizaciones. Con Firebase consulta `cities/arequipa` desde el servidor y lee `dataVersion`, `dataSha256`, `dataBytes`, `dataUrl` y `minAppVersion`. El modo local informa que el servicio no está disponible; conserva todas las funciones offline.

La URL debe usar HTTPS. Solo las pruebas permiten HTTP de loopback. Los redireccionamientos vuelven a validarse. La descarga está limitada por tamaño, tiempo y número de redireccionamientos. El manifiesto debe coincidir con la versión, SHA y bytes anunciados; incluye exactamente `pack.sqlite` y `routes.geojson`. Se verifican ambos hashes, integridad SQLite, claves foráneas, FTS5 y consultas de líneas, puntos del mapa y red del planificador antes de activar.

Las versiones viven en directorios inmutables separados. Un puntero pequeño cambia por renombrado después de escribir y vaciar el archivo; `previous.json` conserva la referencia anterior. Los lectores abiertos no pierden su archivo. Se vuelven a crear servicios y proveedores al activar; si falla la recarga, se restaura el puntero anterior y se vuelve a abrir. Al reiniciar se valida el puntero, luego la copia anterior y por último el paquete incluido. No se rebaja la versión incluida en el APK ni se acepta otro hash para una misma versión incluida. Una revisión publicada debe incrementar la versión de datos.

No se actualiza durante un viaje activo o que está iniciando, ni durante la eliminación de cuenta. La interfaz bloquea otras acciones durante la operación y permite cancelar comprobación/descarga. Se conserva la sesión local de invitado y Firebase mantiene su sesión nativa. Las preferencias y la sincronización usan sus almacenes existentes. Las geometrías del mapa se consultan desde SQLite, por lo que la recarga también renueva las capas de rutas y paraderos.

Las versiones anteriores se conservan; no hay recolección automática de directorios antiguos. Las descargas interrumpidas por cierre del proceso pueden dejar un directorio temporal sin activar; no reemplazan el paquete vigente. Los hashes detectan corrupción; la confianza en el origen depende de HTTPS, del proyecto Firebase y sus reglas administrativas.

## Hosting preparado, sin despliegue

Fuentes: `tool/hosting/`. Salida local ignorada por Git: `hosting/`. Preparación desde la raíz:

```powershell
C:\Proyecto_001\.tools\city-pack-venv\Scripts\python.exe -B tool/prepare_hosting.py --base-url https://gowayki-lab.web.app
```

Ese origen es una propuesta de configuración, no una URL cuya publicación se haya verificado. El generador comprueba los assets, copia la versión y genera páginas de descarga, privacidad y términos. `build/hosting/cities.arequipa.json` contiene el fragmento para el documento de ciudad; no escribe Firestore. Para una futura distribución puede recibir `--release-apk build/app/outputs/flutter-apk/app-release.apk` después de verificar el APK. No se publica un APK debug como release.

El usuario confirmó que responsable y correo todavía no están definidos. `tool/hosting/legal.json` mantiene campos nulos, estado `draft` y revisión pendiente. Las páginas muestran su condición de borrador, carecen de indexación y los enlaces legales de la app permanecen desactivados. La comprobación local `node tool/check_hosting.mjs`, configurada como predeploy, rechaza estos borradores. Para publicar hace falta completar y revisar los textos y preparar un candidato aprobado; no basta cambiar una bandera sin revisar su contenido. Esta sección no autoriza ni ejecuta un despliegue.

El borrador describe las coordenadas en datos privados, reportes visibles durante 72 horas sin borrado automático, nombre público del ranking y la marca técnica vacía por UID tras eliminar una cuenta. No inventa responsable, correo, plazos legales ni certificación de cumplimiento.

## Verificación y límites

Pruebas con el paquete real copiado y una revisión simulada v3: descarga/activación/reinicio, lector anterior usable, reversión, SHA anunciado incorrecto, payload corrupto, truncado, versión mínima, HTTPS/redirección insegura, cancelación y rechazo durante viaje. La prueba de la aplicación completa comprueba la recarga y la conservación del invitado. El hash y la versión 2 de los assets originales permanecen intactos.

No se ha creado la base Firestore real, desplegado reglas/Hosting ni probado una actualización pública en Android. Los APK se volvieron a generar y verificar en 9B/9C; el informe de Parte 9 y los JSON de 9C contienen las evidencias actuales. Los APK e informes de 8E corresponden a ese punto anterior.

Resultado: 199 pruebas Flutter de la suite completa aprobadas y análisis sin incidencias. Evidencias locales: `.tools/logs/parte9A-all-tests.log` y `.tools/logs/parte9A-analyze.log` en `C:\Proyecto_001`. Preparación de Hosting verificada y rechazo de publicación del borrador comprobado sin conectarse a Firebase.
