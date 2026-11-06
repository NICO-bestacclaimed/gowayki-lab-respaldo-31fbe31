# Informe de cierre — Parte 2: planificador

Estado: PARCIAL respecto del requisito de dispositivo; implementación 2A–2D y validación funcional/benchmark en Windows completadas. Falta medir en Android de gama media. El usuario confirmó que por ahora dispone solo de Windows y autorizó continuar las secciones sin detenerse salvo conflicto.

## Resultado

- Dart puro, ejecución en un isolate persistente, red de SQLite cargada fuera de la interfaz y sin handles cruzando isolates.
- Itinerarios, tramos a pie/transporte, geometrías recortadas, puntos intermedios, tarifas y hasta tres abordajes (dos transbordos).
- Frecuencias aprobadas y velocidades por franja; acceso/egreso de 800 m, ampliable a 1.500 m únicamente si no se encuentra transporte.
- Salir ahora, salir a un instante y llegar antes de una hora. Búsqueda inversa y validación hacia delante del plazo; estado explícito sin servicio.
- Selección Pareto por duración, transbordos y caminata. Hasta cinco combinaciones de líneas distintas, con los tres órdenes solicitados. La alternativa de caminar está separada y disponible si su distancia estimada es menor de 2.500 m, incluso cuando el transporte no opera.

## Viajes reales verificados

Referencias OSM fijadas del paquete, salida 10:00 Arequipa (15:00 UTC), revisión de datos 2:

| Viaje | Mejor opción por tiempo | Minutos aprox. | Caminata estimada | Transbordos | Tarifa estimada |
| --- | --- | --- | --- | --- | --- |
| TECSUP Arequipa → Mall Aventura Porongoche | Monterrey Corbacho | 18,44 | 641,27 m | 0 | S/ 1,00 |
| Plaza de Armas → Terminal Terrestre | BR | 25,01 | 544,85 m | 0 | S/ 1,00 |
| Yanahuara → Cerro Colorado | Cotaspa 4 → A | 23,68 | 238,20 m | 1 | S/ 2,00 |

Cerro Colorado se fija en la municipalidad central OSM `node/4126637264`; Yanahuara en `node/4262845116`. Los otros pares usan TECSUP `way/409177970`, Mall Aventura `way/437694283`, Plaza de Armas `way/23811932` y Terminal `way/198666186`. Son coordenadas del extracto, algunas de centro de área, no entradas verificadas. No se intercambió el Terminal Norte ni otro centro comercial para obtener un resultado favorable.

Se obtuvo al menos una opción de transporte entre 10 y 90 minutos para cada par. El JSON del benchmark contiene las alternativas adicionales con líneas, tiempos, caminata y transbordos.

## Criterios y comprobaciones

- ✅ Cálculo manual de tres líneas: 8 min caminando + 15 de espera + 26 de vehículo = 49 min, dos transbordos y S/ 3,00; reporte previo `docs/PLANIFICADOR_2A.md`.
- ✅ Llegar antes de la hora pedida: búsqueda inversa, plazos en cambios de franja y comprobación posterior de llegada.
- ✅ Noche: no se proponen vehículos en la franja 23–05; la opción a pie puede seguir disponible como alternativa.
- ✅ Alternativas: pruebas de Pareto, menor caminata, menos transbordos, límite de cinco y combinaciones no duplicadas.
- ✅ Red real: los tres pares solicitados, con referencias de origen/destino documentadas.
- ✅ Integridad de optimizaciones: 20 redes sintéticas con semilla fija se comparan con el escaneo sin poda; los 28 resultados del benchmark conservan exactamente las rutas y métricas de la referencia anterior a la optimización.
- ✅ `flutter analyze --no-pub`: sin observaciones.
- ✅ `flutter test --no-pub --reporter expanded`: 45 aprobadas, 0 fallidas.
- ✅ Generador: 76 pruebas Python aprobadas en 2A; su implementación y configuración no cambiaron funcionalmente después de esa verificación.
- ✅ Windows AOT: 28 muestras medidas, mediana 152,709 ms, peor caso 393,125 ms; incluye transporte, llegar antes y diez pares adicionales de semilla 42.
- ⚠️ Android de gama media: no medido, por falta de dispositivo disponible; el resultado Windows no certifica ese requisito ni una garantía para cualquier punto geográfico.
- ⚠️ Teléfono, iOS y visualización de itinerarios: no probados en esta parte. Las pantallas de viajes conservan la maqueta hasta su sección de integración.

## Rendimiento y percances resueltos

La primera medición AOT tenía mediana 1.344,315 ms y peor caso 2.899,294 ms. Se identificaron muchas etiquetas intermedias y se aplicaron cotas optimistas hacia el destino con el límite de abordajes restante, reutilización de esperas, tablas por minuto y caminos peatonales inversos preparados al cargar la red.

Solo se limitan a cinco los prefijos con métricas numéricas equivalentes en el mismo estado: todos tienen las mismas opciones futuras y ya proporcionan las cinco combinaciones admitidas por la salida. No se recortan los intercambios reales entre tiempo y caminata. La búsqueda sin poda se conserva como referencia de prueba. Las cotas usan velocidad máxima, espera cero y componentes mínimos independientes, por lo que descartan estados únicamente cuando no pueden mejorar un destino ya encontrado; se deja un margen temporal de 10 ms por redondeo numérico.

Se resolvieron avisos de estilo y una expectativa antigua de prueba al cambiar la espera en frontera de franja. El análisis y la suite final están correctos. No se cambiaron pantallas, Firebase, permisos o dependencias durante la Parte 2.

## Archivos principales

`lib/domain/planner/`: modelos, horario, escaneo, búsqueda inversa, cotas, selección y worker. `lib/infra/city_pack/`: carga y lector SQLite del snapshot. `test/planner/`: pruebas unitarias y reales. `tool/planner_benchmark.dart`: benchmark reproducible. `test/benchmarks/windows_aot_2026-11-06.json`: evidencia de la ejecución AOT. La revisión de datos 2, su configuración y validaciones se incluyen en este cierre.

## Cómo probarlo

Desde `C:\Proyecto_001\gowayki_lab`, con `C:\Proyecto_001\Entorno.ps1` activado:

```powershell
C:\Proyecto_001\Flutter.cmd analyze --no-pub
C:\Proyecto_001\Flutter.cmd test --no-pub --reporter expanded
C:\Proyecto_001\.tools\flutter\bin\cache\dart-sdk\bin\dart.exe build cli --target=tool/planner_benchmark.dart --output=C:\Proyecto_001\.tools\benchmarks\planner
C:\Proyecto_001\.tools\benchmarks\planner\bundle\bin\planner_benchmark.exe --iterations=5
```

El JSON distingue plataforma y ejecución, registra el hash del paquete y marca `android_midrange_validated=false`. Los tiempos de arranque/carga se informan aparte. No se publica un nuevo APK en esta parte porque el núcleo aún no está integrado en la interfaz; la siguiente compilación de aplicación incluirá los assets v2.

## Pendientes y resguardo

Queda medir Android cuando haya dispositivo y completar las partes de interfaz y producto. Siguen los 1.280 nombres estimados y las limitaciones de caminata por factor del paquete. El reloj de ciudad usa UTC-05 moderno.

La ruta del respaldo y el siguiente paso se guardan en `docs/ESTADO_TRABAJO.json`. Se hace commit local `feat: implementar planificador offline con horarios y rutas Pareto`; no se hace push. Se continúa con 3A por la autorización posterior del usuario, conservando la limitación Android sin marcarla como comprobada.
