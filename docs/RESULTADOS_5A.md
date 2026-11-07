# Punto de control 5A — resultados reales

Se sustituyó la pantalla anterior de demostración por consultas a PlannerWorker en un isolate persistente. Origen y destino proceden de Buscar/Explorar; no hay origen fijo. La red se carga una vez y al cambiar el límite peatonal se reemplaza el worker de forma controlada, compartiendo las estructuras inmutables al preparar la configuración.

Se muestran transporte y alternativa a pie por separado, estado sin servicio, salir ahora/a una hora/llegar antes y los tres órdenes solicitados. Las tarjetas incluyen horas y duración aproximadas, cadena de tramos, caminata, espera, transbordos y tarifa estimada. El mapa representa las geometrías de alternativas, resalta la seleccionada y diferencia caminata punteada del transporte por color de línea. Las caminatas mantienen su naturaleza estimada, sin afirmar un trazado peatonal certificado.

Las seis pruebas nuevas usan resultados del worker real para TECSUP–Mall, Plaza–Terminal y Yanahuara–Cerro Colorado; la UI sustituye el renderizador nativo. También comprueban estado nocturno, propagación de orden/evitar transbordos y reemplazo del cliente real al cambiar de 400 a 800 m. Suite completa: 90 aprobadas. Análisis sin observaciones.

Se agregó share_plus 13.3.1 para la siguiente sección; todavía no se abrió ningún diálogo real de compartir ni se envió contenido. La siguiente tarea es el detalle de itinerario, guardar/compartir y las fichas/favoritos de 5B–5E. El APK verificado sigue siendo el de la Parte 4; se recompilará al cerrar la Parte 5. La visualización física de MapLibre y rendimiento Android siguen pendientes.

Hubo una interrupción de la revisión automática por límite de uso antes de la suite final. El usuario indicó continuar y la reanudación autorizada permitió completar las 90 pruebas y el análisis. Se conserva respaldo local sin push ni commit parcial de la Parte 5.
