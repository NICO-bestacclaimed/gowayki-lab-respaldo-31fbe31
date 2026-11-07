# Cierre de la Parte 4 — MapLibre offline, Explorar y Buscar

Implementación del alcance offline completada; verificación visual y de fluidez en Android pendiente. El usuario pidió «Que use el maplibre Offline»: se mantiene MBTiles local y se aplaza la variante web/PMTiles/Hosting. No se publica una URL de ejemplo.

## Resultado

- Mapa base MapLibre con MBTiles y glifos locales, maxzoom de datos 14 y cámara hasta 18. Estilos claro/oscuro con cambio de tema. Instalación atómica y verificada por hashes; versiones anteriores preservadas y recuperación de copia dañada. Regeneración con POI/housenumber documentada en `docs/MAPA_4A.md`, sin ejecutar Planetiler ni cambiar el MBTiles existente.
- Rutas con color real de cada línea y borde blanco; ida continua, vuelta discontinua y flechas que siguen la geometría. Paraderos desde zoom 15 y nombres desde 17. Nombres estimados señalados con `~`. Marcadores A/B al elegir origen y destino.
- Callbacks de ruta/paradero con las entidades del paquete. Las previsualizaciones muestran únicamente datos existentes; las fichas completas corresponden a la Parte 5.
- Carga de asociaciones de 6.128 puntos usados y 98 líneas mediante una conexión SQLite propia de un isolate. No se transfieren handles entre isolates.
- Explorar: buscador, chips de líneas favoritas reales, pulsación larga con Ir aquí/Salir desde aquí, selector de línea, mostrar/ocultar rutas, ubicación manual de MapLibre alimentada desde geolocator con coordenada/precisión/rumbo observados y panel deslizable con tres alturas. No se usa una coordenada ficticia como ubicación del usuario.
- Seguimiento solo con permiso previamente concedido y GPS activo; se detiene al ocultar Explorar o minimizar la app. No se pide permiso de forma automática desde el mapa. Los estados de permiso/GPS/error permiten continuar eligiendo puntos manualmente.
- Paraderos próximos con distancia peatonal estimada (factor 1,3) y líneas que los sirven. Se respeta un límite explícito de caminata; el listado se reutiliza al arrastrar el panel para evitar ordenar 6.128 puntos en cada frame.
- Buscar devuelve ambos puntos, permite intercambiarlos y usar la ubicación real disponible. Agrupa Lugares, Paraderos, Rutas y Calles. Seleccionar una línea permite elegir uno de sus paraderos reales, sin asignarle una coordenada inventada.
- FTS5 sin tildes: lugares/calles en el índice del paquete, paraderos/líneas en un índice TEMP de la conexión de lectura. El archivo distribuido no cambia ni requiere una nueva revisión de datos. Se limita y escapa la entrada FTS, se cancela el consumo de búsquedas antiguas y se aplica debounce.
- Recientes locales deduplicados, máximo 30 y persistentes. La posición actual no se guarda automáticamente en recientes. Favoritos de líneas alimentan chips y búsqueda; Casa/Trabajo/lugares se configurarán en la Parte 5 y por ahora pueden estar vacíos.
- No se calculan ni presentan itinerarios nuevos en esta parte. La pantalla anterior de planificación sigue pendiente de sustitución en la Parte 5.

## Comprobaciones

84 pruebas Flutter aprobadas y análisis sin observaciones. Incluyen los casos anteriores y pruebas nuevas de instalación/recuperación del mapa, integridad de assets, colores y coordenadas, asociaciones reales, FTS por grupos/tildes, inmutabilidad del paquete, GPS/permiso/cancelación, distancia a pie, selección e intercambio de puntos, respuesta tardía de búsqueda, recientes, texto grande con teclado y navegación de Explorar con renderizador nativo sustituido.

Los tests de interfaz sustituyen únicamente el renderizador nativo o las fuentes de ubicación; no convierten una posición simulada en datos de producción. Un test comprueba la existencia del mosaico padre z14 de una vista z18 en el centro de Arequipa.

La evidencia del APK, hashes de datos/imágenes/mapa y bibliotecas nativas se guarda en `docs/VERIFICACION_APK_PARTE_4.json` al finalizar la compilación. Las advertencias conocidas de Firebase/Kotlin, Java y metadatos SDK se mantienen registradas.

## Percances resueltos

Se corrigió un acceso a WidgetRef durante dispose que provocaba una excepción al cerrar Explorar. El controlador necesario se conserva antes del desmontaje. Se corrigió un desbordamiento de 72 px en Buscar con ventana 320×568, teclado y texto al 180%; el formulario puede desplazarse cuando hay poca altura. Las pruebas reproducen ambos casos y ahora pasan.

El verificador del APK contempla las rutas URI con espacios codificados de los directorios de glifos. No faltaban fuentes en el paquete.

## Lo que falta verificar en dispositivo

No se ha inspeccionado MapLibre nativo, los toques de capas, el punto azul, la brújula/rumbo ni cambios rápidos de estilo en un teléfono. Tampoco se ha certificado modo avión ni z18 sin áreas en blanco en todo el ámbito. No se midieron FPS ni latencia al mover el mapa: el entorno Windows de pruebas no ejecuta el renderizador Android. Por ello no se inventa una cifra de rendimiento ni se da por cumplido ese criterio físico.

La cartografía de fondo conserva la fecha OSM 2026-02-20 que declara el MBTiles; rutas/lugares del paquete tienen su procedencia propia. Overzoom amplía el mapa existente, no añade POI ni números ausentes. Los 1.280 nombres estimados y la ruta sin asociación documentados en las partes previas siguen pendientes de revisión de datos.

## Siguiente parte

Conectar el núcleo de planificación con resultados y detalle, completar fichas de línea/paradero y favoritos locales. Se sigue sin push ni despliegue.
