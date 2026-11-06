# Informe de cierre — Parte 1: paquete offline de Arequipa

Estado: TERMINADO en el alcance de datos offline y su repositorio Flutter. La aplicación completa y la prueba en teléfono siguen fuera de este cierre.

## Qué se hizo

Se completaron patrones y distancias, enriquecimiento OSM, nombres con evidencia o etiquetas estimadas autorizadas, transbordos, lugares FTS5, geometrías simplificadas, configuración y empaquetado con manifiesto verificable. La app instala el SQLite en su almacenamiento privado y lo consume para líneas y lugares sin Firebase. El repositorio también expone paraderos, patrones, visitas ordenadas, shapes, transbordos, config y tarifas. La comparación de versiones está preparada; no se añadieron descargas de actualizaciones.

## Archivos creados o modificados

- `tool/build_city_pack/`: generador, documentación, configuración y 75 pruebas Python.
- `tool/data/raw/`: cinco fuentes originales, conservadas por hash; retiradas de `assets/gtfs/`.
- `assets/city/arequipa/`: SQLite, GeoJSON y manifiesto.
- `lib/domain/models/city_pack_models.dart`, `lib/domain/repositories/city_pack_repository.dart` y `lib/infra/city_pack/`: modelos, contrato, instalación, lectura, búsqueda y versiones.
- `lib/data/service_locator.dart`: conexión a los repositorios offline reales; retirado el lector de JSON de `lib/infra/gtfs/`.
- `pubspec.yaml`, `pubspec.lock`: assets y dependencias verificadas.
- `test/city_pack_repository_test.dart`, `test/widget_test.dart`: integración local real y arranque sin Firebase, 12 pruebas Flutter.
- `tool/prepare_sqlite_android.ps1`: descarga oficial por hash para la caché nativa cuando el hook no tiene acceso de red.
- `docs/PAQUETE_OFFLINE.md`, `docs/ESTADO_TRABAJO.json` y este informe: uso, evidencia y reanudación.

## Recuentos finales

| Dato | Resultado |
| --- | --- |
| Líneas | 98 |
| Patrones/sentidos | 191 |
| Candidatos de la fuente GTFS | 6.711 |
| Candidatos distintos usados en patrones | 6.128 |
| Visitas en patrones, incluidos bucles | 27.258 |
| Virtuales añadidos en el dataset actual | 0 |
| Nombres estimados marcados para revisión | 1.280 |
| Lugares FTS5 | 11.582 |
| Pares de transbordo | 85.154 (170.308 aristas dirigidas) |
| Geometrías conservadas | 192 |
| Vértices | 91.050 originales → 13.596 simplificados |
| Desviación máxima medida | 7,997162 m |
| SQLite | 16.142.336 bytes (16,14 MB decimales) |
| GeoJSON | 419.377 bytes |

Los candidatos GTFS no se certifican como paraderos físicos. La ruta 17684887 se conserva con geometría, pero sigue sin asociación inventada de línea/sentido ni patrón habilitado.

## Criterios de aceptación

- ✅ Patrones ordenados y proyección a un máximo de 35 m: pruebas Python y recorrido de los 191 patrones en las pruebas Flutter.
- ✅ Ningún punto sin etiqueta: comprobación SQLite y pruebas del generador; se mantiene la incertidumbre de los 1.280 nombres estimados.
- ✅ Transbordos por grilla y lugares con FTS5: 75 pruebas Python correctas en 1C. Sus archivos de código y configuración se conservan sin cambios funcionales en 1D; los hashes de fuentes y paquete se volvieron a comprobar.
- ✅ Simplificación de aproximadamente 8 m, colores y configuración solicitada: pruebas de 1C y manifiesto verificado. Las franjas de velocidad cubren 24 horas e incluyen ausencia de servicio 23–05.
- ✅ Crudos fuera de assets: cinco fuentes idénticas por hash en `tool/data/raw/`; no queda `assets/gtfs/` dentro del APK final.
- ✅ Instalación desde assets, reutilización, integridad y consultas: pruebas contra el SQLite real; rechazo de manifiestos/hashes inválidos, reparación local y conservación de otra copia válida.
- ✅ Línea y paraderos ordenados, FTS sin tildes: prueba real de toda la red, TECSUP y Ejército; el caso literal `Arequípa` se introduce únicamente en una copia temporal de prueba.
- ✅ Preparación para versiones: diferencia entre revisión nueva, anterior, misma revisión y build diferente; ningún servicio remoto inventado.
- ✅ Demo sin Firebase: arranque y consultas reales de líneas/lugares en la prueba de widget.
- ✅ Android: APK debug compilado; hashes de datos, manifiesto y bibliotecas nativas comprobados. Antes de eliminar símbolos, las bibliotecas coinciden con los hashes oficiales; dentro del APK coinciden con la salida `stripped_native_libs` de Gradle. FTS5 aparece compilado para ARM, ARM64 y x64.
- ⚠️ Teléfono, interfaz visual, modo avión, permisos y rendimiento: sin prueba manual en dispositivo.
- ⚠️ iOS: sin compilación desde Windows.

## Comandos y resultados

- Python: `python -B -m unittest discover -s tool/build_city_pack/tests -v` → 75 aprobadas en 1C, 0 fallidas.
- `flutter analyze --no-pub` → sin observaciones en el estado final de 1D y con caché local.
- `flutter test --no-pub --reporter expanded` → 12 aprobadas, 0 fallidas en la ejecución final.
- `flutter build apk --debug --no-pub` → correcto tras resolver la descarga nativa; 90,2 segundos en el intento final.
- `git diff --check` → correcto.

SHA-256 SQLite: `f031c47f5bb52eb484671c2bb79240ef90b97ee70c91fd38f13f1334b76a8151`.

APK debug: `C:\Proyecto_001\gowayki_lab\build\app\outputs\flutter-apk\app-debug.apk`.

## Percances, solución y límites

El primer build Android falló por DNS al descargar SQLite desde su hook. Se descargaron las tres bibliotecas oficiales desde PowerShell, se verificaron por SHA-256 y se usó la caché que el hook vuelve a validar. Una transferencia x64 se interrumpió y terminó en su único reintento. Se regeneró la configuración de paquetes para usar exclusivamente la caché local preparada. El procedimiento queda documentado y no requiere un servidor.

Las observaciones de estilo de las primeras iteraciones se corrigieron. Siguen los avisos previos de compatibilidad futura Firebase/Kotlin, acceso nativo Java y metadatos SDK Android; no bloquearon el build final. Gradle se detuvo al terminar.

La caminata entre puntos es estimada por factor y no contempla barreras; algunos lugares OSM usan centro de área y no entrada. La búsqueda ya lee datos reales, pero el planificador de viajes existente continúa siendo demo hasta la Parte 2. No se modificaron pantallas, mapas base, Firebase, permisos nativos ni el algoritmo de planificación.

## Cómo probarlo

Los comandos completos de generación, pruebas y ejecución Android sin Firebase están en `docs/PAQUETE_OFFLINE.md` y los README de `tool/build_city_pack/`. En teléfono, abrir el explorador, buscar `TECSUP Arequipa` y revisar las líneas. Esa prueba manual no se marca como realizada.

## Pendientes para otras partes

Antes del planificador se deben acordar las horas exactas de punta, valle y noche: el plan define frecuencias de 6, 10 y 15 minutos, pero no sus intervalos horarios. Después corresponde la Parte 2; no se inició en este cierre. Splash/navegación, interfaz, alarmas, juego, Firebase y distribución conservan el alcance de sus partes posteriores.

## Resguardo y commit

El estado y la ruta exacta del respaldo verificado constan en `docs/ESTADO_TRABAJO.json`. La cuota de cinco horas no es visible: ante un aviso observado o señal del usuario, guardar el estado y detener el trabajo hasta recibir CONTINÚA.

Este informe se incluye en el commit local de cierre `feat: integrar paquete offline de Arequipa con SQLite`. Obtener su hash con `git log -1 --format=%H`. No se hace push. STOP al terminar la Parte 1.
