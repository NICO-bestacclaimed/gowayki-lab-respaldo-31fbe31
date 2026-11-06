# Sección 1B — nombres, transbordos y búsqueda local

Esta sección genera una base SQLite intermedia; no cambia las pantallas ni configura el planificador. La integración Flutter pertenece a 1D y el paquete final y su manifiesto a 1C.

## Un comando para generar

Desde `C:\Proyecto_001\gowayki_lab`, con el entorno aislado ya preparado:

```powershell
C:\Proyecto_001\.tools\city-pack-venv\Scripts\python.exe -B tool/build_city_pack/build.py --enrich
```

Primero regenera los patrones de 1A sin alterar su formato y después produce `tool/build_city_pack/output/enrichment.sqlite` y `enrichment.report.json`. Todas las salidas son regenerables y están excluidas de Git. Sin `--enrich`, el comando de 1A conserva su comportamiento y no necesita Pyosmium.

En otro equipo, prepara primero un entorno virtual local e instala `tool/build_city_pack/requirements.txt`. En este equipo el entorno está en `C:\Proyecto_001\.tools\city-pack-venv`; Python global y las dependencias Flutter no se modificaron. Se utilizaron ruedas binarias de Pyosmium; no hace falta instalar un compilador para esta herramienta.

La entrada PBF predeterminada es `tool/.cache/trufi-review/arequipa.osm.pbf`. Se puede indicar otra con `--osm-pbf RUTA`. Si falta, hay un error: no se consulta silenciosamente otro servidor ni se inventan datos.

## Fuente OSM y reproducibilidad

El PBF proviene de `trufi-association/trufi-arequipa`, revisión `9b60aa5cc46e6b8f2dad63079770279c6cb1feb7`, archivo `Backend-Services/otp/data/arequipa.osm.pbf`.

- Tamaño descargado: 7.753.313 bytes.
- SHA-256: `5d9a5e4295e87dd238b15588c211f4927abe59f98a801ab7d91b30ec58ddd1b2`.
- Fecha de extracto declarada por el commit de origen: 18 de octubre de 2026. El encabezado del PBF no declara fecha de réplica, por lo que se registra la declaración del proveedor sin presentarla como verificación independiente.
- El archivo predeterminado se rechaza si su hash cambia. Otra fuente explícita conserva su propio hash en los metadatos.
- El lector filtra la zona de los paraderos/shapes del proyecto con margen de 0,01 grados. No importa ciegamente todos los objetos del PBF, que incluye referencias fuera de Arequipa.
- Se guardan los hashes de los cinco archivos GTFS/JSON y se comprueba que no cambien entre la generación de patrones y el enriquecimiento.
- SQLite se construye y valida en un archivo temporal hermano; solo después se reemplaza la salida previa. El reporte JSON contiene el SHA-256 de la base resultante.

Se mantienen las atribuciones a OpenStreetMap y la referencia ODbL en los metadatos del archivo. Referencias de procedencia:

- [PBF publicado](https://github.com/trufi-association/trufi-arequipa/blob/9b60aa5cc46e6b8f2dad63079770279c6cb1feb7/Backend-Services/otp/data/arequipa.osm.pbf).
- [Commit que declara la procedencia temporal](https://github.com/trufi-association/trufi-arequipa/commit/1ae94734891fae1bde1051b46e883668e4f86481).
- [Lectura de geometrías con Pyosmium](https://docs.osmcode.org/pyosmium/latest/user_manual/03-Working-with-Geometries/).

## Candidatos GTFS frente a paradas registradas en OSM

Los 6.711 puntos del CSV son candidatos de la fuente GTFS; no se certifican como paraderos físicos inventariados. El generador Trufi declara la creación de puntos sintéticos. No se cambian sus coordenadas ni se sustituyen por el feed más reciente de 227 rutas.

La base distingue `source_kind=gtfs_candidate` y, cuando 1A añada puntos, `source_kind=generated_virtual`. Todos tienen `official_name_verified=0`: disponer de un nombre no prueba su carácter oficial ni la existencia de infraestructura.

Los contadores históricos de `patterns.json` llamados `real_*` significan únicamente «existente en el CSV, no añadido por 1A». Se conservan por compatibilidad con la sección anterior; los nuevos reportes y tablas de 1B usan `gtfs_candidate`. Esto corrige la denominación anterior sin cambiar IDs o patrones.

El lector cuenta por separado nodos con etiquetas de parada OSM. Ese conteo no los convierte en miembros de un patrón. El inventario GeoJSON auxiliar de Trufi contiene 400 objetos con fecha OSM de 28 de octubre de 2026, mientras el PBF procede de otra fecha y criterios; no se fusionaron como si fueran la misma fuente ni se reemplazaron automáticamente los puntos GTFS.

## Política de nombres aceptada

Los nombres originales utilizables se conservan, junto con `original_name` y `name_source=gtfs_source`. Los vacíos, `Innominada`, `Sin nombre`, `S/N` y equivalentes no se consideran nombres resueltos.

Para los puntos que necesitan nombre:

1. Se busca la vía con nombre más cercana mediante una grilla de segmentos. Se descartan nombres OSM que solo sean marcadores de ausencia de nombre.
2. Solo se utiliza una vía situada a un máximo de **50 m** del punto.
3. Un cruce debe compartir un nodo OSM con una vía de nombre distinto y estar a un máximo de **200 m**. Los fragmentos conectados de una misma vía se agrupan; dos calles del mismo nombre en lugares desconectados no se unen.
4. Con ambos criterios se usa `Vía / Cruce`, registrando los IDs de las vías, el nodo compartido y las distancias. Las calles que solo se cruzan geométricamente, sin un nodo compartido, no generan un cruce.
5. Si hay una vía cercana pero no un cruce cercano verificable: `Cerca de [vía] (punto estimado)`.
6. Si tampoco existe una vía cercana: `Punto de subida estimado [identificador]`.

Los dos últimos casos llevan `needs_review=1`. Son la alternativa explícita autorizada por el usuario cuando faltan datos; no son topónimos inventados. `needs_review=0` significa que no se activó esa alternativa, no que el nombre original o derivado esté certificado oficialmente.

El primer diagnóstico encontró 365 casos sin un cruce con nombre y asociaciones a cruces de más de 11 km. Esas asociaciones lejanas no se publican como nombres válidos: ahora se aplican los límites anteriores. Los valores adoptados son un criterio conservador del generador, no un estándar oficial de señalización.

## Transbordos

- Se calculan sobre todos los candidatos conservados, usando el modelo métrico local de 1A.
- La grilla tiene celdas de 400 m. Cada punto solo se compara con candidatos ya visitados en su celda y las ocho vecinas; no se recorre el producto cartesiano completo.
- Se acepta un par si su distancia recta es como máximo 400 m. Se guarda `walk_distance_m = direct_distance_m × 1,3`, que puede llegar a 520 m.
- `transfers` guarda cada par una sola vez, en orden de ID. `transfer_edges` ofrece las dos direcciones y hay índices para consultar ambos extremos.
- `used_in_patterns` permite a los consumidores distinguir puntos asociados a los patrones actuales de los candidatos que todavía no tienen esa asociación.

La fórmula peatonal es una estimación solicitada en el plan. No verifica puentes, accesibilidad, muros o cruces peatonales; no constituye un motor de rutas sobre calles.

## Lugares y FTS5

`places` conserva nombre, categoría, coordenadas, tipo/ID OSM, etiquetas y procedencia de la coordenada. Incluye universidades, institutos, hospitales/clínicas, mercados, centros comerciales, plazas, terminales, municipalidades, colegios, parques, lugares de culto, vías con nombre y barrios/localidades.

Los nodos conservan su ubicación OSM. Las vías/áreas usan un centro de su caja geográfica, marcado como `coordinate_source`: es una ubicación representativa, no una puerta de entrada verificada. Las paradas y semáforos no se clasifican como calles por tener una etiqueta `highway`.

`places_fts` indexa nombres, nombres alternativos y direcciones disponibles en OSM con `unicode61 remove_diacritics 2`. La función `search_places` admite prefijos, combina palabras y trata la puntuación como entrada, sin interpolar SQL. No genera error por búsquedas vacías o símbolos solos; limita el número de resultados.

Ejemplo de consulta de solo lectura, después de generar la base:

```python
import sqlite3
from enrich import search_places
connection = sqlite3.connect('file:tool/build_city_pack/output/enrichment.sqlite?mode=ro', uri=True)
try:
    print(search_places(connection, 'tecsup arequipa'))
finally:
    connection.close()
```

Para importar `enrich` desde otra carpeta, añade primero `tool/build_city_pack` al `sys.path` de tu script; la interfaz de uso normal sigue siendo el comando `build.py --enrich`.

Referencia: [tokenizador Unicode61 de SQLite FTS5](https://www.sqlite.org/fts5.html#unicode61_tokenizer).

## Tablas y validaciones

- `stops`: nombre no vacío, nombre original, coordenadas originales, tipo de candidato, asociación a patrones, procedencia del nombre y evidencia JSON.
- `transfers` y `transfer_edges`: pares y vista dirigida con distancias recta/peatonal.
- `places` y `places_fts`: datos OSM y búsqueda offline.
- `metadata`: procedencia, hashes, modelo de distancia, límites, atribución y resumen de verificación.

Antes de sustituir el resultado, se comprueban integridad SQLite, claves foráneas, ausencia de puntos sin etiqueta válida, consistencia del índice FTS y presencia de TECSUP como instituto buscable. Un fallo mantiene el archivo anterior.

Ejecuta las pruebas desde la raíz:

```powershell
C:\Proyecto_001\.tools\city-pack-venv\Scripts\python.exe -B -m unittest discover -s tool/build_city_pack/tests -v
```

Primero genera 1B: las pruebas de integración comprueban la base real, además de los casos geométricos y SQLite de prueba. Todos los temporales de las pruebas se guardan bajo `output/test-work/` y se eliminan al finalizar.

## Lo que permanece pendiente

El GTFS actual y la ruta CSV sin correspondencia en `network.json` permanecen intactos. No se añadieron pantallas, RAPTOR, Firebase o navegación nueva. El resultado no se llama `pack.sqlite`: el empaquetado, configuración y manifiesto de 1C, y su consumo en Flutter de 1D, todavía están pendientes.

Las cifras finales de esta ejecución se guardan en `output/enrichment.report.json`; deben consultarse allí y en el punto de control, sin confundir el diagnóstico inicial con el resultado validado.

## Resultado verificado — 6 de noviembre de 2026

| Medición | Resultado |
| --- | --- |
| Candidatos GTFS conservados, con coordenadas originales | 6.711 |
| Nombres originales conservados | 5.250 |
| Nombres derivados de vía y cruce cercanos | 181 |
| Etiquetas de vía cercana, explícitamente estimadas | 123 |
| Etiquetas de punto estimado con identificador | 1.157 |
| Casos marcados para revisión | 1.280 |
| Puntos sin etiqueta válida | 0 |
| Pares de transbordo únicos | 85.154 |
| Aristas dirigidas disponibles en la vista | 170.308 |
| Comparaciones de distancia realizadas por la grilla | 206.157 |
| Comparaciones de un recorrido completo de todos los pares | 22.515.405 |
| Lugares indexados con FTS5 | 11.582 |
| Tamaño de la base intermedia | 11.714.560 bytes |
| Pruebas Python del conjunto 1A + 1B | 56 aprobadas, 0 fallidas |

Se verificaron todos los pares del resultado, los límites de nombres, las coordenadas originales, las claves foráneas y el índice. `tecsup arequipa` y `tecsup arequípa` encuentran el instituto OSM `way/409177970`, sin sustituirlo por una ubicación demo. También hay pruebas de puntuación/consultas inválidas, búsquedas por prefijo, cruces sin conexión topológica, nombres lejanos y conservación de la base anterior ante fallos.

La revisión añadió una protección para rechazar `--output` si apunta al mismo archivo que `--osm-pbf`, antes de escribirlo. Su prueba de regresión comprueba que los bytes de la fuente permanezcan intactos.

SQLite `quick_check`, claves foráneas y la verificación FTS terminaron correctamente. El hash de la base se volvió a comprobar después de las pruebas:

```text
340a4b3316059ec176a8923d6b9229995bfb95520e1f78c31b8b30a3c4604bfd
```

El JSON de patrones de 1A mantuvo su hash `0954355ef6596eac6c51d13f253cc692ef12f827e14a4ac8de9a333ea1255269`. Los archivos versionados de Flutter, GTFS, Android, iOS y dependencias de la app permanecen sin cambios.

### Percances y límites que siguen vigentes

- La indisponibilidad inicial de Overpass se resolvió mediante el PBF publicado y fijado por hash; esta ejecución no depende de una consulta a esos servidores.
- La falta de nombres/cruces se resolvió con el criterio alternativo autorizado por el usuario. Los 1.280 casos marcados siguen pendientes de revisión de datos; no se ocultó su incertidumbre para satisfacer el criterio de nombres no vacíos.
- La distancia peatonal es una estimación por factor, sin validar barreras ni accesibilidad.
- Las coordenadas de áreas pueden representar un centro geográfico y no una entrada.
- La ruta CSV `17684887` sigue fuera del catálogo de sentidos. No se inventó una correspondencia; su tratamiento sigue pendiente para el empaquetado.
- Este resultado valida el generador y la base intermedia. Todavía no valida el consumo de estos datos desde una pantalla de Flutter; eso corresponde a 1D y a las partes de UI posteriores.

La sección 1B queda completada con la adaptación de nombres aceptada. No se inició 1C ni se creó un commit de cierre de la Parte 1.
