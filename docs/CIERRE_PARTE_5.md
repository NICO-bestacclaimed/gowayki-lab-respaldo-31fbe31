# Cierre de la Parte 5 — resultados, fichas y favoritos locales

Implementación 5A–5E completada y verificada en Windows. Sigue pendiente la comprobación física de MapLibre y de los diálogos nativos en Android; iOS no se compiló en Windows. El seguimiento y las alarmas corresponden a la Parte 6.

## Resultado

- Se retiraron la pantalla de planificación, el catálogo de lugares y el repositorio de viajes ficticios. La pantalla recibe origen/destino elegidos y consulta PlannerWorker real en isolate, con configuración del paquete y preferencias de caminata/transbordos.
- Hora de salir ahora, salir a una hora y llegar antes; orden por duración, transbordos o caminata; estado sin servicio y alternativa a pie separada. El worker se sustituye de manera controlada al cambiar el límite peatonal.
- Mapa con todas las alternativas, selección resaltada, caminata punteada gris y transporte por color de línea. Tarjetas con horas/duración aproximadas, cadena de tramos, caminata, espera, transbordos, tarifa y etiquetas comparativas.
- Detalle con instrucciones, frecuencia y espera aproximadas, espera adicional por cambio de franja cuando corresponda, número de paraderos, bajada e intermedios desplegables. Tocar un paso centra su punto en el mapa. Guardar conserva el par de puntos; abrir un viaje guardado recalcula las alternativas, y la interfaz lo explica.
- Compartir usa share_plus 13.3.1 mediante un adaptador sustituible. No se comparte nada automáticamente. Las pruebas capturan el texto sin enviar mensajes ni abrir un diálogo real.
- Hay un punto de extensión para Iniciar viaje; el botón permanece oculto hasta que la Parte 6 proporcione el seguimiento funcional. No se muestra un botón sin acción.
- Rutas: búsqueda local, orden alfabético y filtro de líneas próximas usando una muestra real de ubicación con permiso previo. La ficha contiene avatar/color, sentidos/destinos, mapa, paraderos, frecuencia según hora de Arequipa, tarifa, favorito y compartir.
- Ficha de paradero: datos del paquete, mapa, líneas/sentidos, espera estimada, selección como origen/destino y favorito. Los toques de rutas y paraderos del mapa abren sus fichas. Reportar problema permanece oculto hasta su implementación en la Parte 8.
- Biblioteca local: Casa, Trabajo, lugares, líneas, paraderos, viajes y recientes (máximo 30). Se puede reordenar y borrar por deslizamiento. Los lugares guardados y Casa/Trabajo alimentan Explorar y Buscar. Se conserva la compatibilidad de los favoritos de líneas anteriores.
- Buscar tiene selector de un punto para configurar lugares y lectura actual de ubicación solo si el permiso ya está concedido. Una respuesta de GPS tardía no sustituye un origen editado por el usuario. No se inventan coordenadas ante permiso denegado o GPS inaccesible.

## Verificación

- 104 pruebas Flutter aprobadas, cero fallidas; análisis sin observaciones.
- Los tres viajes reales se consultan desde la pantalla hasta el worker auténtico. El puente de zona de las pruebas permite procesar el I/O nativo fuera del reloj simulado; únicamente el renderizador del mapa se sustituye en estos casos.
- Se verifican tarjetas, estado nocturno, preferencia de transbordos, cambio de radio del worker, instrucciones y texto de compartir, persistencia concurrente, límites de recientes, borrado/reordenamiento, Casa, fichas y protección ante datos locales dañados.
- APK debug compilado con la integración nativa de compartir: 241.215.645 bytes, SHA-256 `9ba31f8d1d74467d8e4ea9206985ae03c2b5cc4876aa95d4becf8f1eb8580266`.
- `tool/verify_apk.py`: paquete revisión 2, sus hashes, 16 imágenes, 12 recursos de mapa y SQLite ARM/ARM64/x64 verificados. Evidencia: `docs/VERIFICACION_APK_PARTE_5.json`. El contenido del paquete de ciudad no cambió.
- Gradle detenido al terminar. No se hizo push ni despliegue.

Los resultados principales siguen siendo aproximados: TECSUP–Mall 18,44 min; Plaza–Terminal 25,01 min; Yanahuara–municipalidad central de Cerro Colorado 23,68 min, a las 10:00 de Arequipa según los parámetros aprobados. La evidencia detallada y sus referencias OSM están en el cierre de la Parte 2.

## Percances resueltos

La carga inicial de la biblioteca mezclaba observación de estado y del Future de almacenamiento; se unificó la dependencia para evitar una espera sin resolver. También se corrigieron las pruebas de desplazamiento antes de pulsar botones fuera del área visible.

La suite completa detectó archivos SQLite todavía abiertos por lectores en isolate al cerrar la navegación en Windows. Los repositorios ahora esperan sus lectores y comparten una única operación de cierre entre llamadas concurrentes. Se añadió una prueba que inicia lecturas, cierra y elimina su carpeta propia sin bloqueo. El estado vacío de recientes no inicia una lectura del mapa innecesaria. Las pruebas de navegación y la suite completa vuelven a pasar.

Se ajustaron el reordenamiento a la API vigente de Flutter, claves de controles distintas de las filas, el borrado idempotente de líneas y la numeración de paraderos según las secuencias reales del paquete (que empiezan en 1).

## Límites y continuación

No se certifican GPS, notificaciones, sonido, vibración, compartir ni fluidez visual en un teléfono por compilar o sustituir sus adaptadores en pruebas. El rendimiento AOT Windows previo no certifica el requisito Android. Persisten los nombres estimados y avisos de compatibilidad futura Firebase/Kotlin, Java y SDK ya documentados.

Sigue la Parte 6: viaje activo, servicio de ubicación en primer plano, alarma y permisos. Para la Parte 7, el usuario pidió que el juego sea lo más ligero posible ante la elección de crear copias pequeñas locales de las ilustraciones. Se conservarán las originales y se medirá el total contra el límite de 150 KB.
