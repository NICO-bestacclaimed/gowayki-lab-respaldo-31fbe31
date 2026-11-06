# Punto de control — Parte 2, sección 2A

Estado: COMPLETADA. STOP antes de 2B. Fecha: 6 de noviembre de 2026.

## Alcance realizado

Se crearon modelos de itinerario, tramos a pie y tramos en transporte en Dart puro. El núcleo por rondas añade un abordaje por ronda y admite hasta tres (dos transbordos). Escanea cada patrón marcado desde su primera visita alcanzable, conserva la secuencia incluso en bucles y reconstruye los tramos con metadatos de línea, puntos intermedios, tarifa y geometría recortada.

La carga del SQLite se hace en un isolate con `loadPlannerNetwork(installed)`. `planInIsolate(network, query)` ejecuta el cálculo con una red de objetos independientes de Flutter y sin transferir handles de SQLite. El punto de entrada es utilizable por otras capas; la pantalla de viajes mantiene su repositorio demo hasta la integración prevista en el plan.

Referencia primaria del recorrido por rondas: [Delling, Pajor y Werneck, Round-Based Public Transit Routing](https://www.microsoft.com/en-us/research/publication/round-based-public-transit-routing/). Esta implementación adapta el escaneo a las frecuencias y velocidades estimadas solicitadas; no reproduce horarios de viajes GTFS inexistentes.

## Horarios aprobados por el usuario

| Periodo | Horas de Arequipa | Frecuencia del modelo |
| --- | --- | --- |
| Punta | 07–09 y 17–20 | 6 minutos |
| Valle | 05–07 y 09–17 | 10 minutos |
| Noche | 20–23 | 15 minutos |
| Sin servicio | 23–05 | Sin abordajes |

Se guardan como `frequency_bands` en la configuración fuente y en la tabla SQLite. `data_version` se incrementó de 1 a 2. El esquema sigue siendo 1; los archivos GTFS originales y GeoJSON mantienen sus hashes. El paquete sigue midiendo 16.142.336 bytes.

Las fechas del modelo son instantes UTC y se consultan con el reloj moderno de Arequipa, UTC-05. No dependen de la zona horaria configurada en la computadora o teléfono.

## Cálculo manual de la red de prueba

Red sintética exclusiva de las pruebas: R1, R2 y R3. Salida 10:00; frecuencia valle 10 minutos, espera prevista 5; velocidad 18 km/h = 300 m/min; caminata 75 m/min. Cada tramo peatonal mide 150 m = 2 minutos.

| Paso | Cálculo | Hora estimada |
| --- | --- | --- |
| Acceso al punto A | 150 / 75 = 2 min | 10:02 |
| Espera R1 | 10 / 2 = 5 min | 10:07 |
| R1: A → M → B | 3.000 / 300 = 10 min | 10:17 |
| B → C a pie | 150 / 75 = 2 min | 10:19 |
| Espera R2 | 10 / 2 = 5 min | 10:24 |
| R2: C → D | 1.800 / 300 = 6 min | 10:30 |
| D → E a pie | 150 / 75 = 2 min | 10:32 |
| Espera R3 | 10 / 2 = 5 min | 10:37 |
| R3: E → F | 3.000 / 300 = 10 min | 10:47 |
| Egreso al destino | 150 / 75 = 2 min | 10:49 |

Resultado manual y probado: 8 minutos caminando + 15 esperando + 26 en vehículo = 49 minutos; 600 m a pie, tres abordajes, dos transbordos y tarifa estimada S/ 3,00. El punto M figura como intermedio en R1 y se cuentan dos puntos recorridos después de abordar, incluido B.

También se verifican un viaje de una línea de 19 minutos, una tarifa de R2 sobrescrita a S/ 1,50 (total S/ 3,50), espera y velocidad de punta, límites de abordajes, un cuarto vehículo inaccesible y ampliación del acceso a 1.500 m solo si no hay resultado con 800 m.

## Cambios de franja y caminatas

La distancia a bordo se integra en cada franja atravesada. Ejemplo: 1.000 m desde las 06:58 consume primero dos minutos a 22 km/h y luego el resto a 14 km/h: 2 + (1.000 − 733,333333) / 233,333333 = 3,142857 minutos. No se mantiene artificialmente la velocidad inicial durante todo el tramo ni se circula por una franja sin servicio.

La espera prevista sigue siendo frecuencia / 2. El pasajero puede permanecer en el punto hasta un cambio cercano de franja si eso permite abordar antes. Se conserva esa espera adicional en `TransitLeg.waitingForBandMinutes`, separada de `expectedWaitMinutes`; `waitMinutes` suma ambas y forma parte de la duración total. A las 06:59, esperar hasta las 07:00 y luego los tres minutos previstos permite abordar a las 07:03. Esta regla mantiene que llegar antes no haga perder una conexión que obtendría quien llega después. La prueba recorre cada segundo alrededor de las 07:00 para comprobarlo.

Las caminatas de acceso/egreso se estiman con distancia geográfica × 1,3, a 75 m/min. Los radios de 800 y 1.500 m limitan metros de caminata estimada. Cada transbordo entre vehículos usa una arista directa de la tabla precalculada: no encadena ilimitadamente enlaces para saltarse ese límite. La geometría peatonal es una línea orientativa, sin comprobación de barreras ni entradas.

## Pruebas y alcance real de la validación

- `flutter analyze --no-pub`: sin observaciones.
- `flutter test --no-pub --reporter expanded`: 26 aprobadas, 0 fallidas; incluye las 12 previas y 14 nuevas de núcleo/carga.
- Python: 76 aprobadas, 0 fallidas; incluye franjas aprobadas, huecos, solapes y coherencia con el horario de servicio.
- La carga real encontró 98 líneas, 191 patrones, 6.711 candidatos, 27.258 visitas y 170.308 aristas de transbordo; las consultas anteriores y el arranque demo siguen pasando con la revisión 2.
- Los hashes del paquete/manifiesto, GeoJSON y las cinco fuentes se verificaron otra vez después de las pruebas.
- El dominio no importa Flutter ni `dart:ui`; no se modificaron pantallas, Firebase, permisos o dependencias.

Un script de estilo recibió inicialmente varios directorios cuando `dart fix` admite uno; se corrigió la invocación. Al corregir el caso límite de frecuencia se actualizó una expectativa de prueba que conservaba el resultado anterior. Ambos percances quedaron resueltos; no hay pruebas fallidas al cerrar la sección.

No se ejecutó un nuevo build APK en 2A: no cambió código nativo ni dependencias. El APK generado en Parte 1 conserva los datos de revisión 1. La validación actual corresponde al código fuente y assets de revisión 2. Tampoco se certificó ejecución en teléfono ni rendimiento de gama media.

## Pendientes con sección asignada

- 2B: opciones de salida/llegada solicitadas y estado explícito sin servicio. El núcleo actual solo recibe una salida concreta y devuelve candidatos vacíos cuando no puede viajar.
- 2C: selección Pareto por tiempo, transbordos y caminata, hasta cinco combinaciones y opción de solo caminar. En 2A se ofrece el candidato más temprano para cada número de abordajes; no se declara un conjunto Pareto final.
- 2D: los tres viajes reales y medición de rendimiento. El aislamiento de 2A copia la red al ejecutar cada consulta; su coste debe medirse antes de decidir una optimización.
- Integración visual: permanece en las partes posteriores del plan.

La geometría de transporte conserva distancias del shape original y se interpola sobre su versión simplificada; no certifica una ubicación física de subida. Se mantienen los 1.280 nombres estimados pendientes de revisión y la ruta excluida del catálogo de patrones.

No se crea commit de cierre de Parte 2 hasta completar 2D. El respaldo verificado y el siguiente paso constan en `docs/ESTADO_TRABAJO.json`. La cuota de cinco horas no es visible; ante un aviso observado o señal del usuario, guardar el estado y detenerse hasta recibir CONTINÚA.
