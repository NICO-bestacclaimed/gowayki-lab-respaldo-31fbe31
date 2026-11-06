# Generador del paquete de Arequipa — sección 1A

Herramienta Python para inferir los patrones ordenados de paraderos de las líneas existentes. Esta sección no genera SQLite ni modifica la app, sus assets o los archivos de origen. No descarga OSM, calcula viajes ni configura Firebase.

## Requisito y comando de ejecución

Python 3.10 o posterior, sin paquetes externos. En este equipo se verificó con Python 3.14.

Desde la raíz del repositorio, ejecuta un único comando:

```powershell
python tool/build_city_pack/build.py
```

Funciona también desde otra carpeta si se proporciona la ruta del script: las rutas predeterminadas se resuelven respecto a su ubicación, no al directorio actual de la terminal.

El resultado se escribe en `tool/build_city_pack/output/patterns.json`. El script muestra cantidades, tamaño y SHA-256. `output/` está excluido de Git y se puede regenerar con el mismo comando. Primero valida todo el documento y después sustituye el resultado mediante un archivo temporal en la misma carpeta; si falla la lectura o validación, conserva la salida anterior y devuelve un código distinto de cero.

Opciones disponibles: `--input-dir RUTA` y `--output RUTA`. No se permite escribir la salida dentro del directorio de datos de entrada. Estas opciones servirán al trasladar los crudos en 1C; 1C traslada los CSV a esa carpeta, conservando sus bytes.

## Fuentes y alcance

Se leen `routes.txt`, `trips.txt`, `stops.txt`, `shapes.txt` y `network.json` desde `tool/data/raw/`.

- El catálogo de líneas y sentidos es `network.json`: actualmente 98 líneas y 191 sentidos. No se presupone que todas las líneas tengan regreso.
- Para cada sentido, `route_id` enlaza con `trips.txt`; sus `shape_id` deben identificar un único shape original. Los 192 route_id actuales tienen un solo shape cada uno, aunque algunos tengan varios trips.
- La geometría se obtiene de `shapes.txt`, ordenando por `shape_pt_sequence`. No se utiliza la geometría simplificada del JSON para decidir la proximidad de un paradero.
- IDs repetidos, referencias desconocidas, geometrías degeneradas y rutas con shapes ambiguos provocan error; no se elige un shape arbitrariamente.
- La ruta CSV `17684887` no está en el catálogo JSON. Se informa en `summary.unmapped_route_ids` y se imprime una advertencia; sus 775 puntos siguen intactos en el origen. No se inventa una línea ni un sentido para incorporarla. Cualquier decisión sobre esa discrepancia debe preceder a una ampliación del catálogo o al empaquetado final.

Los patrones son una **inferencia geométrica**, porque no hay `stop_times.txt`. La proximidad al trazado no demuestra que un vehículo tenga permitido parar en ese punto o que un paradero de otra calzada sea accesible. Este resultado no añade horarios ni observaciones de servicio.

## Modelo de distancia

Las coordenadas se convierten a un plano equirectangular local en metros, con radio esférico de 6.371.008,8 m y origen en el centro de los límites de los shapes utilizados. Se guardan el modelo y su origen en `distance_model` para que los consumidores puedan interpretar las distancias.

Este es un modelo métrico local aproximado para Arequipa, no una proyección elipsoidal ni una distancia sobre la red de calles. Los umbrales y las pruebas de esta herramienta usan ese mismo sistema de metros. La tabla de distancias peatonales y su factor 1,3 pertenecen a 1B, no a esta sección.

Se conserva la coordenada original de cada paradero real. Cada aparición en un patrón guarda por separado su punto proyectado sobre el shape y la distancia lateral al trazado. Así no se desplazan físicamente los datos de origen para hacer que parezcan coincidir con una ruta.

## Algoritmo

1. Crea una grilla espacial de paraderos con celdas de 100 m. Por cada segmento del shape consulta solo las celdas de su caja ampliada en 35 m.
2. Proyecta cada candidato al segmento, incluyendo sus extremos. Admite una distancia lateral de hasta 35 m.
3. Agrupa las proyecciones de un mismo paradero sobre segmentos consecutivos y conserva la más cercana. Una visita posterior en un bucle puede mantenerse si está separada en segmentos y distancia recorrida; no se elimina una visita válida solo por repetir un ID físico.
4. Ordena las visitas por distancia acumulada desde el comienzo del shape. Descarta visitas separadas por menos de 60 m de la última retenida. Las igualdades se resuelven de forma determinista por distancia lateral e ID.
5. Si quedan menos de cinco visitas reales, propone virtuales cada 400 m a lo largo del trazado y en los extremos. Si hay al menos cinco, rellena únicamente los huecos mayores de 800 m. También examina los huecos entre los extremos del shape y el primer/último paradero.
6. Conserva siempre los paraderos reales frente a un virtual cercano y descarta virtuales situados a menos de 60 m de otro punto retenido. Un hueco apenas mayor de 800 m no fuerza un virtual a un metro de un paradero real.
7. Verifica el orden, los límites de chainage, la separación mínima, el umbral lateral y la ausencia de huecos remanentes superiores a 800 m antes de escribir.

El criterio de duplicado de 60 m se aplica a la **distancia recorrida sobre el patrón**, no a la proximidad entre dos pasos muy separados de un bucle. La tolerancia de cálculo es de un micrómetro antes de serializar; las distancias se guardan con seis decimales.

Los virtuales tienen IDs estables derivados del patrón y de su distancia acumulada, `is_virtual=true` y `name=null`. Sus nombres se resolverán con OSM en 1B; no se inventan topónimos. En un trazado muy corto, colocar puntos cada 400 m no garantiza obtener cinco paraderos: se conserva la regla de espaciado, sin fabricar puntos adicionales para alcanzar una cantidad.

## Formato intermedio

`patterns.json` contiene:

- `schema_version`, `city_code` y `stage`: formato 1, Arequipa, `1A_patterns`.
- `distance_model` y `rules`: unidades, proyección y umbrales aplicados.
- `source_sha256`: hash de cada uno de los cinco archivos de entrada.
- `summary`: cantidades, patrones inicialmente escasos, huecos y rutas fuera del catálogo.
- `stops`: paraderos únicos con ID, nombre de origen, latitud, longitud e indicador de virtual. Los paraderos reales sin uso en este resultado permanecen en `stops.txt`.
- `patterns`: ID de línea, sentido, ruta y shape, destino, color de la línea, longitud y visitas ordenadas. Cada visita contiene `stop_id`, `distance_m`, `offset_m`, `shape_latitude` y `shape_longitude`.

El resultado no contiene fecha variable ni rutas absolutas. Con las mismas entradas y versión del algoritmo, la serialización, los IDs y el hash de salida son reproducibles. El manifiesto versionado del paquete final corresponde a 1C.

## Pruebas

Para ejecutar las pruebas del generador desde la raíz:

```powershell
python -B -m unittest discover -s tool/build_city_pack/tests -v
```

Son 29 pruebas: proyección con resultados calculados a mano; extremos y vértices repetidos; límites de 35, 60, 400 y 800 m; bucles y dos sentidos; grilla con coordenadas negativas; virtuales en patrones escasos y huecos interiores/extremos; entradas inválidas y preservación del resultado anterior; cobertura de todo el catálogo real, orden, separación y pertenencia de los puntos proyectados a los segmentos originales; hashes y regeneración determinista.

Los archivos temporales de las pruebas se crean bajo `output/test-work/`, dentro del proyecto, y se eliminan al finalizar cada prueba. Las pruebas no dependen de Flutter ni de una conexión de red.

## Resultado verificado el 6 de noviembre de 2026

| Medición | Resultado |
| --- | --- |
| Líneas del catálogo | 98 |
| Patrones / sentidos | 191 |
| Candidatos del CSV, excluida la cabecera | 6.711 |
| Candidatos distintos utilizados tras proyección y deduplicación | 6.128 |
| Apariciones de candidatos del CSV en los patrones | 27.258 |
| Paraderos virtuales generados con estos datos | 0 |
| Mínimo de visitas de candidatos en un patrón | 55 |
| Mayor distancia lateral al shape | 34,797121 m |
| Mayor hueco, incluidos los extremos | 724,348267 m |
| Patrones inicialmente con menos de cinco visitas | 0 |
| Patrones con huecos iniciales superiores a 800 m | 0 |
| Visitas repetidas al mismo paradero dentro de bucles | 50 |
| Tamaño del JSON | 4.244.813 bytes |
| Pruebas | 29 aprobadas, 0 fallidas |

Que no se generen virtuales con el dataset actual es consecuencia de sus valores medidos, no de omitir el mecanismo de relleno. Las pruebas sintéticas sí activan y verifican esa rama.

SHA-256 del resultado observado:

```text
0954355ef6596eac6c51d13f253cc692ef12f827e14a4ac8de9a333ea1255269
```

## Pendientes para otras secciones

- 1B: completada con nombres de OSM verificables o etiquetas estimadas autorizadas; transbordos y lugares con FTS5. Hay casos de datos marcados para revisión; consulta `README-1B.md`.
- 1C: completada; geometrías, configuración, SQLite y manifiesto publicados; ruta sin asociación preservada y crudos trasladados.
- 1D: repositorio Flutter implementado; consulta `../../docs/PAQUETE_OFFLINE.md` para instalación, consultas y pruebas.

La sección 1A no altera las pantallas, el planificador, la navegación, los assets o Firebase. No se crea un commit de cierre de la Parte 1 hasta completar sus secciones y verificaciones.

## Continuación 1B y corrección de terminología

La sección 1B se ejecuta mediante el mismo script con `--enrich`; consulta [README-1B.md](README-1B.md) para el entorno aislado, la fuente PBF fijada, los límites y la base intermedia con transbordos/FTS5.

Los puntos del CSV no son paraderos físicos certificados. Donde esta documentación y los campos históricos `real_*` de 1A dicen «real», se debe interpretar «existente en la fuente CSV, no añadido por esta herramienta». La nueva tabla de 1B los identifica como `gtfs_candidate` y nunca afirma que su nombre sea oficial. Esta precisión no cambia IDs, coordenadas ni el JSON regenerable de patrones.

## Continuación 1C

`--pack` genera el paquete completo. Consulta [README-1C.md](README-1C.md) para geometrías, configuración editable, manifiesto y resguardo. Las entradas predeterminadas son ahora `tool/data/raw/`; el formato y los IDs de los patrones de 1A no cambian.

## Consumo Flutter — 1D

La app usa SQLite para líneas y búsqueda FTS. El catálogo `network.json` se conserva como entrada en `tool/data/raw/` y ya no se empaqueta en assets. Documentación del lector y comandos: [PAQUETE_OFFLINE.md](../../docs/PAQUETE_OFFLINE.md).
