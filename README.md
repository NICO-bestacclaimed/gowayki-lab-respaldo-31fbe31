# GoWayki Lab

Aplicación Flutter de transporte para Arequipa: MapLibre offline, búsqueda local, planificador estimado, fichas, favoritos y seguimiento de un viaje iniciado por el usuario. El funcionamiento principal usa archivos del dispositivo; no necesita un servidor de rutas. La ciudad instalada es Arequipa.

## Ejecutar y verificar

El entorno preparado para este equipo está íntegramente en `C:\Proyecto_001`. Flutter, SDK Android, cachés y herramientas locales se activan con `Entorno.ps1` o `Flutter.cmd`:

```powershell
C:\Proyecto_001\Flutter.cmd pub get
C:\Proyecto_001\Flutter.cmd analyze --no-pub
C:\Proyecto_001\Flutter.cmd test --no-pub
C:\Proyecto_001\Flutter.cmd run
C:\Proyecto_001\Flutter.cmd build apk --debug
```

`run` requiere un Android/iOS compatible con MapLibre. Windows se utiliza para preparar, compilar y ejecutar las pruebas; no se ha certificado una aplicación de mapas nativa de Windows. iOS requiere macOS/Xcode para compilarse.

`USE_FIREBASE=false` es el valor predeterminado. El login y comentarios heredados permanecen en modo demo hasta su parte de integración; no son servicios remotos configurados. No activar Firebase real con los identificadores de ejemplo del repositorio. La variante web/PMTiles/Hosting se aplazó por la decisión de usar MapLibre offline.

## Datos y límites

| Recurso | Uso |
| --- | --- |
| `assets/city/arequipa/pack.sqlite` | Líneas, sentidos, candidatos a paradero, lugares, calles, transferencias y configuración estimada |
| `assets/city/arequipa/manifest.json` | Versión de datos y SHA-256 |
| `assets/city/arequipa/routes.geojson` | Geometrías simplificadas |
| `assets/map/` | MBTiles z0–14, estilos claro/oscuro, glifos y manifiesto; cámara hasta z18 por overzoom |
| `tool/data/raw/` | Fuentes GTFS originales para regeneración; no se empaquetan como assets antiguos |
| `assets/brand/`, `assets/illustrations/micros/` | Logo y 15 ilustraciones originales suministradas |

El planificador usa velocidades y frecuencias por franja aprobadas para el laboratorio. Horas de ciudad: America/Lima, UTC−05. Todos los tiempos y tarifas mostrados son estimados; no se afirma seguimiento de vehículos. La caminata usa distancia geográfica con factor 1,3 y un trazado orientativo, sin enrutador peatonal vial.

Los candidatos GTFS no equivalen a paraderos certificados físicamente. Hay 1.280 nombres estimados que requieren revisión y una ruta sin asociación de sentido que se conserva como fuente pero no se habilita en el planificador. El MBTiles declara una fecha OSM de fondo distinta de la procedencia del paquete de rutas/lugares. Los detalles de fuentes y hashes están en los informes de las partes.

El límite de 400 ms en Android de gama media y la fluidez del mapa todavía necesitan un dispositivo. Las pruebas Windows y la compilación del APK no sustituyen esa validación ni certifican modo avión, GPS, audio o vibración reales.

## Regenerar y comprobar

Con `C:\Proyecto_001\Entorno.ps1` activado, desde la raíz del repositorio:

```powershell
C:\Proyecto_001\.tools\city-pack-venv\Scripts\python.exe -B tool/build_city_pack/build.py --pack
C:\Proyecto_001\.tools\city-pack-venv\Scripts\python.exe -B -m unittest discover -s tool/build_city_pack/tests -v
C:\Proyecto_001\.tools\city-pack-venv\Scripts\python.exe -B tool/build_map_manifest.py --check
C:\Proyecto_001\.tools\city-pack-venv\Scripts\python.exe -B tool/verify_apk.py
```

No reemplazar las fuentes por otro GTFS sin revisar su correspondencia. La regeneración requiere el PBF fijado y sus hashes, documentados en `tool/build_city_pack/`. El comando de Planetiler para una salida nueva con POI y números se documenta en `docs/MAPA_4A.md`; no se ha ejecutado ni reemplazado el mapa original.

El APK debug se genera en `build/app/outputs/flutter-apk/app-debug.apk`. Sus datos, imágenes, mapa y bibliotecas SQLite se verifican con `tool/verify_apk.py`.

## Organización

- `lib/domain/`: modelos, contratos y planificador Dart puro en isolate.
- `lib/infra/`: instalación/verificación, SQLite de solo lectura, mapas y ubicación.
- `lib/app/`: proveedores Riverpod, navegación go_router y pantallas.
- `lib/shared/`, `lib/l10n/`: componentes, formato y textos es/en.
- `test/`: pruebas de datos, cálculo, persistencia y UI con servicios nativos sustituibles.
- `docs/ESTADO_TRABAJO.json`: último punto de control y pendientes.

Privacidad y términos aún no están publicados. Sus botones están desactivados; se configuran cuando existan con `PRIVACY_URL` y `TERMS_URL`. El viaje activo usa un servicio Android de ubicación con notificación persistente, confirmación de subida y alarmas locales configurables. Solo se inicia con consentimiento y la app visible; termina al llegar, finalizar o cerrar la tarea. No se restaura automáticamente después de que el sistema cierre el proceso. Juego, actualizaciones remotas y Firebase se completan en sus partes respectivas. No se hizo push ni despliegue automático.
