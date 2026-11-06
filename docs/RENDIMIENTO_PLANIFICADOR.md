# Benchmark del planificador — Windows AOT

Evidencia completa: `test/benchmarks/windows_aot_2026-11-06.json`. Comandos, optimizaciones y límites: `docs/CIERRE_PARTE_2.md`.

| Medición | Muestras | Mediana | Peor caso |
| --- | --- | --- | --- |
| Total | 28 | 152,709 ms | 393,125 ms |
| Salida a hora fija | 25 | 149,649 ms | 347,430 ms |
| Llegar antes de una hora | 3 | 192,441 ms | 393,125 ms |

Cinco repeticiones por cada uno de los tres viajes reales, tres llegadas antes de una hora y diez pares adicionales con semilla 42. Una consulta de calentamiento por cada viaje real se excluye del cómputo. El arranque, la lectura de red y el envío inicial al isolate costaron 251,435 ms y se informan por separado; la comprobación del hash precede a ese contador.

Plataforma Windows; compilación nativa AOT mediante `dart build cli`. Las cifras no equivalen a mediciones Android ni prueban todas las coordenadas posibles. No hay dispositivo Android disponible según confirmó el usuario. Se conserva ese criterio pendiente.
