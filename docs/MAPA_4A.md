# Parte 4A — mapa base offline

El archivo existente `assets/map/arequipa.mbtiles` se conserva byte por byte, SHA-256 `36ac8fe067161b6bd2bd2a0209e01f72883b71db5db662804f976c1a4ccffe80`. SQLite declara 395 mosaicos, zoom 0–14, límites -71.72,-16.6,-71.4,-16.26, OpenMapTiles 3.16.0, Planetiler 0.10.2 y fecha OSM 2026-02-20. Esa cartografía tiene una fecha distinta del extracto de rutas y lugares usado para el paquete de ciudad.

## Implementado

Se explicitan maxzoom=14 y límites de la fuente, y la cámara permite 0–18. El motor debe reutilizar los mosaicos padres al acercar más allá de 14. La prueba verifica que el padre z14 de una vista z18 del centro de Arequipa contiene datos; no sustituye la inspección visual en Android.

Los estilos claro y oscuro comparten fuentes locales MBTiles y glifos, sin dependencias HTTP. Cambiar el tema recarga el estilo y las capas. Las respuestas de cargas antiguas se descartan. Los errores de preparación ofrecen reintento y un mensaje traducido.

Se reemplazó la instalación destructiva de una carpeta única por builds inmutables identificados por el hash del manifiesto, staging y publicación mediante rename. Los archivos se verifican por tamaño y SHA-256; se serializan llamadas y se toma bloqueo de archivo. Se conservan versiones previas y copias dañadas para diagnóstico. Solo se elimina staging propio con verificación del directorio padre. Los hashes detectan corrupción; no certifican autenticidad de una fuente remota.

`tool/build_map_manifest.py --check` verifica los 12 archivos; sin `--check`, regenera el manifiesto después de una modificación revisada de estilos, mapa o glifos. Las dos variantes de estilo y las fuentes forman un único build.

Pruebas del mapa: carga de ambos estilos, fuentes locales, manifiesto completo, concurrencia, reparación de corrupción, rechazo de rutas fuera de carpeta y conservación de la copia previa ante fallo.

## Regenerar con POI y números (documentado; no ejecutado)

El tileset actual NO declara las capas `poi` ni `housenumber`. Overzoom no crea esos detalles. Para una futura regeneración se usa el perfil OpenMapTiles completo, sin excluir capas. Se puede fijar Planetiler v0.10.2 y guardar su jar oficial bajo `.tools/planetiler/planetiler.jar`, registrando previamente su SHA-256. No se descargó ni ejecutó Planetiler durante esta sección.

Desde el repositorio, con `C:\Proyecto_001\Entorno.ps1` activado, y tras preparar el jar y las fuentes auxiliares:

```powershell
& "$env:JAVA_HOME\bin\java.exe" -Xmx2g -jar C:\Proyecto_001\.tools\planetiler\planetiler.jar `
  --osm-path=C:\Proyecto_001\gowayki_lab\tool\.cache\trufi-review\arequipa.osm.pbf `
  --download `
  --bounds=-71.72,-16.6,-71.4,-16.26 `
  --maxzoom=14 `
  --tmpdir=C:\Proyecto_001\.tools\planetiler\tmp `
  --output=C:\Proyecto_001\.tools\planetiler\arequipa-full.mbtiles
```

El comando escribe una salida aparte. `--download` permite obtener las fuentes auxiliares; la primera ejecución puede descargar alrededor de 1 GB. El presupuesto de memoria debe adaptarse al equipo. Verificar metadata/json y muestras de las capas `poi`/`housenumber`, integridad SQLite, cobertura y glifos antes de reemplazar un asset. Para mostrarlas también harían falta sus capas de estilo. No se promete que el comando haya sido ejecutado o produzca los mismos datos que el MBTiles anterior.

Referencias primarias: [Planetiler y argumentos](https://github.com/onthegomap/planetiler), [versión fijable 0.10.2](https://github.com/onthegomap/planetiler/releases/tag/v0.10.2), [capas del perfil OpenMapTiles](https://github.com/openmaptiles/planetiler-openmaptiles/blob/main/src/main/java/org/openmaptiles/generated/OpenMapTilesSchema.java).

## Alcance confirmado: MapLibre offline

La sección pide una alternativa web con imports condicionales y PMTiles desde Hosting. No hay archivo PMTiles, URL publicada ni configuración real de Hosting: firebase.json conserva identificadores de ejemplo. Tampoco se ha convertido el acceso al paquete SQLite nativo para navegador. No se añadió una URL inventada ni un proveedor externo de demostración.

El usuario respondió «Que use el maplibre Offline». Se interpreta como priorización de la aplicación nativa con el mapa local existente y aplazamiento de la alternativa web/Hosting. Se continúa con 4B sin inventar servicios. La compilación web no se declara compatible ni verificada. Un eventual archivo remoto PMTiles requeriría soporte HTTP Range y CORS: [documentación primaria](https://docs.protomaps.com/pmtiles/cloud-storage).

En Windows se validan datos y lógica; MapLibre nativo, modo avión, cambios rápidos de tema, z18 sin zonas en blanco y fluidez al desplazar el mapa requieren ejecución en Android. No se realizó esa medición visual ni se declara un FPS.

## Verificación final

68 pruebas Flutter aprobadas, análisis sin observaciones, APK debug compilado. Se verificaron datos revisión 2, 16 imágenes, 12 recursos de mapa y bibliotecas SQLite en tres ABI. Evidencia: `docs/VERIFICACION_APK_4A.json`. El verificador contempla la codificación URI de los espacios en las rutas de glifos del APK. Gradle detenido. No se hizo push. La inspección visual en Android sigue pendiente.
