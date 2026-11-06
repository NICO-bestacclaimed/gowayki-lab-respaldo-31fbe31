# Sección 1C — paquete offline de Arequipa

## Generación completa

Desde `C:\Proyecto_001\gowayki_lab`, con el entorno de 1B y el PBF fijado ya disponibles:

```powershell
C:\Proyecto_001\.tools\city-pack-venv\Scripts\python.exe -B tool/build_city_pack/build.py --pack
```

Un solo comando reconstruye 1A, 1B y 1C. Conserva las opciones anteriores: sin flags genera patrones; `--enrich` añade únicamente la base intermedia de 1B. `--config RUTA` selecciona otro archivo compatible de configuración y `--assets-dir RUTA` permite una salida alternativa dentro del proyecto.

Entradas: `tool/data/raw/` y el PBF en `tool/.cache/trufi-review/`. La caché no se versiona. Las copias de los crudos conservan los SHA-256 de los archivos originales. La herramienta no sustituye el GTFS por el feed más reciente de Trufi.

Salidas en `assets/city/arequipa/`:

- `pack.sqlite`: nombres, candidatos, lugares y FTS5, transbordos, ciudades, líneas, rutas, shapes, patrones, secuencias de puntos y configuración.
- `routes.geojson`: una geometría por ruta de origen, con `route_color` normalizado a `#RRGGBB` y su condición de disponibilidad de patrón.
- `manifest.json`: ciudad, esquema, versión, fecha UTC de construcción, tamaño y SHA-256 de los archivos, build ID y procedencia.

La fecha del manifiesto es la de construcción, no una certificación de actualidad del mapa. El PBF conserva su fecha declarada y los hashes en la procedencia.

## Geometrías

Se aplica Douglas-Peucker iterativo en el plano métrico de 1A, con tolerancia configurable de 8 m. Se comprueba la desviación de los puntos originales entre cada pareja de vértices conservados. La salida usa GeoJSON `LineString` con coordenadas `[longitud, latitud]`.

Los extremos y el orden se conservan, incluidos los trazados cerrados. La simplificación no cambia las distancias acumuladas que ya usan los patrones: cada shape incluye `vertex_distances_json`, con la distancia original correspondiente a cada vértice retenido. El futuro recorte de itinerarios debe utilizar esa correspondencia y no reinterpretar las distancias originales como longitudes de la polilínea simplificada.

Se conserva la geometría de las 192 rutas de origen. Las 98 líneas y 191 patrones del catálogo son los únicos habilitados para asociación de recorridos. La ruta `17684887` no se elimina: aparece en `routes`, en GeoJSON y en `manifest.excluded_from_routing`, con `pattern_available=0` y sin línea/sentido inventados.

## Configuración editable

La fuente es `tool/build_city_pack/config/arequipa.json`. El paquete contiene una tabla `config` por ciudad, con valores JSON, y `line_fares` para sobrescribir la tarifa de una línea. Las pruebas modifican únicamente una copia de la base para comprobar que esos valores se pueden editar.

| Franja | Velocidad del modelo |
| --- | --- |
| 05–07 | 22 km/h |
| 07–09 | 14 km/h |
| 09–12 | 18 km/h |
| 12–14 | 15 km/h |
| 14–17 | 18 km/h |
| 17–20 | 13 km/h |
| 20–23 | 22 km/h |
| 23–05 | Sin servicio: `speed_kmh=null` |

También se guardan las frecuencias pedidas por tipo de periodo: punta 6 min, valle 10 min y noche 15 min; caminata 75 m/min; acceso inicial máximo 800 m y ampliación a 1.500 m; tarifa predeterminada S/ 1,00 en PEN, con sobrescrituras por línea opcionales.

El plan no identifica las horas que delimitan cada tipo de frecuencia. Esta sección almacena los tres valores, sin inventar ese calendario; el mapeo por horas debe fijarse antes de utilizarlo en el planificador de la Parte 2. Las velocidades y frecuencias son parámetros del modelo solicitados por el usuario, no mediciones de circulación ni horarios certificados.

Al distribuir una revisión del paquete, incrementa `data_version` y regenera el manifiesto. `build_id` y SHA-256 identifican el archivo exacto incluso durante iteraciones locales de una misma versión.

## Integridad y publicación local

El empaquetador abre la base de enriquecimiento en modo de solo lectura y la copia mediante SQLite backup. No reconstruye a mano ni pierde el índice FTS existente. Las tablas nuevas tienen claves foráneas e índices para consultar los puntos de cada patrón y los patrones de cada punto.

Primero se generan y validan los archivos en `tool/build_city_pack/output/package-stage/`. Se comprueban datos de origen, correspondencia de distancias, claves foráneas, búsqueda de TECSUP, integridad SQLite y hashes/tamaños del manifiesto. Solo entonces se sustituyen los archivos de destino; el manifiesto se publica al final. El lector de 1D deberá verificarlo antes de instalar un paquete.

Los archivos crudos de cuatro CSV se retiran de assets únicamente después de verificar el paquete y sus pruebas. `assets/gtfs/network.json` se conserva temporalmente: es el catálogo procesado que todavía usa la pantalla actual del mapa, no un CSV crudo. Existe una copia idéntica en `tool/data/raw/network.json` para el generador. La retirada de esa compatibilidad corresponde a 1D cuando el repositorio de la app lea SQLite.

## Pruebas

Después de generar:

```powershell
C:\Proyecto_001\.tools\city-pack-venv\Scripts\python.exe -B -m unittest discover -s tool/build_city_pack/tests -v
```

Las pruebas de 1C cubren tolerancia de simplificación, bucles y extremos, distancias originales por vértice, colores y orden de coordenadas, franjas horarias sin solapes ni huecos, ausencia de servicio nocturno, valores configurados, edición de tarifa por línea, conservación de todas las rutas y patrones, búsquedas sin tildes, claves foráneas y rechazo de paquetes alterados.

No implementa RAPTOR, pantallas, Firebase ni el repositorio Flutter de 1D.

## Resguardo ante una interrupción

`docs/ESTADO_TRABAJO.json` indica la etapa, la última comprobación y el siguiente paso seguro. Incluye una copia de respaldo previa al traslado de crudos, bajo `C:\Proyecto_001\.tools\backups\`.

La cuota de cinco horas no es visible para la herramienta. Ante un aviso observado o una señal del usuario, se debe terminar o cancelar de forma segura la operación en curso, actualizar ese registro y detenerse hasta recibir una indicación de continuar. Antes de retomar, se comprueban los hashes del manifiesto y el estado de Git; no se da por finalizada una verificación que quedó pendiente.

## Resultado verificado de 1C

- SQLite: 16.142.336 bytes (16,14 MB decimales); GeoJSON: 419.377 bytes.
- 98 líneas, 191 patrones y 192 geometrías de rutas de origen.
- 91.050 vértices originales reducidos a 13.596; desviación máxima medida de 7,997162 m.
- 75 pruebas Python correctas; `flutter analyze --no-pub` sin problemas; `flutter test --no-pub`: 1 prueba de arranque correcta.
- `flutter build apk --debug --no-pub` correcto. Se verificaron dentro del APK los hashes del SQLite y GeoJSON, el manifiesto y el catálogo temporal; los cuatro CSV crudos ya no están empaquetados.
- Las cinco entradas de `tool/data/raw/` y los cuatro CSV respaldados coinciden con sus SHA-256 originales.

Persisten avisos de compatibilidad futura de Firebase/Kotlin, acceso nativo de Java y versiones de metadatos del SDK Android. No impidieron esta compilación. Esta validación no incluye ejecución en un teléfono, compilación iOS ni consumo del SQLite por la app: el lector pertenece a la sección 1D.

Los 1.280 nombres estimados pendientes de revisión y la ruta sin asociación en el catálogo siguen identificados; empaquetar los datos no certifica físicamente los puntos de subida. Antes de la Parte 2 debe acordarse el calendario de franjas de frecuencia.

Al finalizar esta sección se conserva un respaldo verificado de todos los cambios locales no ignorados en `C:\Proyecto_001\.tools\backups\parte1C-verified-*.zip`, junto al respaldo previo al traslado. `docs/ESTADO_TRABAJO.json` registra su ruta exacta y los pasos de reanudación. No se inicia 1D hasta recibir CONTINÚA.

## Actualización posterior — 1D

La compatibilidad temporal descrita arriba finalizó en 1D: la app ya consume SQLite y `assets/gtfs/network.json` se retiró del empaquetado. Su copia original sigue en `tool/data/raw/`. Consulta `docs/PAQUETE_OFFLINE.md` para el estado actual; las cifras y verificaciones anteriores corresponden al punto de control 1C.
