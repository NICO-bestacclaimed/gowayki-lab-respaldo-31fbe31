# Repositorio offline de Arequipa — sección 1D

La aplicación instala el paquete incluido en assets en su almacenamiento privado y abre SQLite en modo de solo lectura. `ServiceLocator.cityPack` expone las consultas; `ServiceLocator.transit` usa ese mismo repositorio para las líneas del mapa, y `ServiceLocator.places` adapta los resultados FTS al contrato de búsqueda existente. Funciona con `USE_FIREBASE=false`.

## Instalación y consultas

La implementación está en `lib/infra/city_pack/`, el contrato en `lib/domain/repositories/city_pack_repository.dart` y los modelos independientes de Flutter en `lib/domain/models/city_pack_models.dart`.

1. Lee y valida el manifiesto: Arequipa, esquema 1, versión positiva, nombres de archivo permitidos, tamaños y SHA-256.
2. Busca la copia en `<applicationSupport>/city/arequipa/<version>-<sha256>/` y verifica sus archivos. Si coincide, no vuelve a copiar payloads.
3. Si falta o está corrupta, copia a un directorio temporal privado, comprueba tamaños y hashes, integridad SQLite, referencias y consulta FTS5.
4. Publica el directorio validado mediante renombrado. Conserva las demás versiones y resguarda una copia local corrupta con sufijo `.invalid-...`; no la modifica mientras está abierta.
5. Abre `pack.sqlite` en modo de solo lectura. Las llamadas de instalación se serializan en el isolate; además se toma un bloqueo de archivo del sistema. La inicialización de la app se realiza desde su isolate principal.

La comprobación de hashes se ejecuta fuera del isolate de interfaz. Las consultas SQLite son locales y síncronas internamente, expuestas por el contrato asíncrono; el planificador de la Parte 2 tendrá su propio isolate. La carga del repositorio ocurre antes de `runApp`; la presentación de la carga en splash corresponde a la Parte 3.

Consultas disponibles:

- `lines()`: 98 líneas con los sentidos del catálogo y geometría simplificada compatible con el mapa existente `[latitud, longitud]`.
- `stops(limit:, offset:)`, `stop(id)`: candidatos/virtuales con procedencia y revisión pendiente explícitas.
- `patternsForLine(lineId)`, `patternStops(patternId)`: patrones y visitas ordenadas; un mismo punto puede aparecer varias veces en un bucle.
- `shape(shapeId)`: coordenadas GeoJSON `[longitud, latitud]` y correspondencia con las distancias originales de cada vértice.
- `transfersFrom(stopId)`: aristas peatonales dirigidas calculadas por factor, no una ruta peatonal validada.
- `searchPlaces(query, limit:)`: prefijos FTS5, sin distinción de tildes, con tokens entre comillas y parámetros SQL.
- `configuration()`, `fareForLine(lineId)`: configuración del modelo y tarifa con sobrescritura por línea o valor predeterminado.
- `close()`: cierra el handle; las consultas posteriores fallan de forma explícita.

Los IDs inexistentes producen `null` o una lista vacía según el contrato. Se limitan las consultas de paraderos a 1.000 por página y de búsqueda a 100 resultados, 512 caracteres y 12 tokens. No se expone SQL arbitrario.

## Preparación para versiones

`SqliteCityPackRepository.manifest` identifica el paquete instalado. `compareVersion(candidate)` diferencia misma versión/hash, revisión posterior, revisión anterior y mismo número con un build diferente. Rechaza esquemas o ciudades incompatibles al interpretar el manifiesto. Para una revisión distribuida debe incrementarse `data_version`.

Esta sección instala únicamente el paquete incluido en la app. No descarga ni aplica actualizaciones de red; el origen remoto, la compatibilidad de app, la autenticidad y la reversión de actualizaciones son alcance de la Parte 9. Un SHA-256 detecta corrupción, pero no autentica por sí solo un manifiesto remoto.

El lector anterior y `assets/gtfs/network.json` se retiraron una vez comprobada la lectura SQLite. Los cinco originales permanecen sin cambios en `tool/data/raw/`; el generador usa esas copias. El respaldo local del lector y catálogo retirados está en `C:\Proyecto_001\.tools\backups\parte1D-legacy-reader\`.

## Dependencias

Versiones verificadas: `sqlite3 3.9.0`, `crypto 3.0.8`, `path 1.9.1`; `path_provider` ya formaba parte del proyecto. Se conserva `pubspec.lock` para reproducibilidad. SQLite se distribuye con la app mediante los hooks nativos del paquete; no requiere instalar un servidor.

Documentación primaria consultada: [sqlite3](https://pub.dev/packages/sqlite3/versions/3.9.0), [crypto](https://pub.dev/packages/crypto/versions/3.0.8). La validación del host utiliza el motor nativo y su índice FTS5, sin sustituir SQLite por un mock.

## Cómo verificar

Desde `C:\Proyecto_001\gowayki_lab`, con el entorno activado por `C:\Proyecto_001\Entorno.ps1`:

```powershell
C:\Proyecto_001\.tools\city-pack-venv\Scripts\python.exe -B -m unittest discover -s tool/build_city_pack/tests -v
C:\Proyecto_001\Flutter.cmd analyze --no-pub
C:\Proyecto_001\Flutter.cmd test --no-pub --reporter expanded
C:\Proyecto_001\Flutter.cmd build apk --debug --no-pub
```

La suite Flutter cubre instalación del asset real, reutilización sin recopia, todos los 191 patrones con secuencias y distancias ordenadas, conversión de coordenadas para el mapa, TECSUP real, búsqueda con/sin tildes, consultas inválidas, configuración y tarifas, transbordos simétricos, comparación de versiones, manifiestos incompatibles, instalaciones concurrentes en el mismo isolate, rechazo de hashes alterados, conservación de la copia válida, reparación local y cierre de recursos.

La comprobación literal `arequipa` → `Arequípa` utiliza una copia temporal con un registro de prueba identificado como `test:accent`. Nunca modifica el paquete de producción ni inventa un lugar dentro de los assets publicados. También se comparan las búsquedas reales `Ejercito` y `Ejército`.

En un Android conectado, ejecutar `C:\Proyecto_001\Flutter.cmd run --dart-define=USE_FIREBASE=false`, abrir el explorador, buscar `TECSUP Arequipa` y abrir las líneas. Esa revisión manual sigue pendiente hasta disponer del dispositivo. No se certifica compilación iOS desde Windows.

## Percance de descarga nativa y solución local

El primer build Android de 1D falló al resolver `github.com` desde el hook nativo. La URL oficial sí era accesible desde PowerShell. Se precargaron los binarios oficiales ARM, ARM64 y x64 en la caché ignorada `.dart_tool/hooks_runner/shared/sqlite3/build/`, comprobando cada SHA-256 contra `sqlite3-3.9.0/lib/src/hook/asset_hashes.dart`. Una descarga x64 se interrumpió y terminó correctamente en el único reintento de esa descarga.

El procedimiento se conserva en `tool/prepare_sqlite_android.ps1`, fijado a SQLite 3.9.0. Para el mismo problema de red, ejecutarlo desde PowerShell antes del build; no modifica el paquete de dependencias ni evita las comprobaciones de hashes del hook. Tras limpiar `.dart_tool`, se deberá descargar de nuevo si el proceso de compilación sigue sin acceso a GitHub.

También se regeneró `.dart_tool/package_config.json` con `C:\Proyecto_001\Entorno.ps1` activado y se comprobó que `sqlite3` resuelve en `C:\Proyecto_001\.tools\pub-cache`. El archivo generado había apuntado a la caché de usuario; no se debe confiar en una ruta previa al cambiar dependencias o al abrir el proyecto desde otro perfil de VS Code. El workspace preparado es `C:\Proyecto_001\Gowayki.code-workspace`.

## Cierre verificado

Sección 1D y Parte 1 completadas: 12 pruebas Flutter correctas, análisis sin observaciones y APK Android debug generado. Se comprobaron los hashes de los assets y el origen oficial de las bibliotecas antes de la eliminación de símbolos de Gradle; los binarios del APK coinciden con esa salida procesada y contienen FTS5. El detalle, los recuentos y las limitaciones están en `docs/CIERRE_PARTE_1.md`.
