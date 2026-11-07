# Cierre de la Parte6 — viaje activo y alarma

Estado: implementación y verificaciones disponibles en Windows completas; validación física Android e iOS pendiente. Se continúa a Parte7 por autorización del usuario.

## Resultado

Iniciar viaje conectado al itinerario real, explicación previa, solicitud de ubicación/notificaciones y comprobación de app visible. Pantalla con paso actual, posición aceptada, distancia aproximada, confirmación de subida/bajada, finalización y acceso para volver desde las pestañas. Un solo propietario del stream de ubicación evita que Explorar interfiera con el servicio. GPS y notificación persistente se liberan al terminar; el servicio Android finaliza también al cerrar la tarea.

Alarma a ~400m o último paradero y otra en zona de transbordo. Canales separados para sonido/vibración y ninguna alerta cuando el ajuste está desactivado. Se descartan posiciones antiguas, imprecisas o alejadas de la geometría; control de cruces/bucles y recuperación tras pérdida prolongada de GPS. No se detectan vehículos.

## Evidencia

- flutter analyze --no-pub: No issues found.
- flutter test --no-pub: 126 aprobadas, incluidas22 nuevas de seguimiento, integración y plugin de notificaciones.
- APK debug final: 241519395 bytes; SHA-256 `628f4d5f78cbc4d6bc8799f27e976bb13e160ead36fa1f7a3301843ef20e8779`.
- Assets verificados contra sus manifiestos: datos versión2,16 imágenes originales,12 archivos del mapa y SQLite/FTS5 para3 ABI.
- Manifest del APK inspeccionado con aapt: permisos de ubicación durante uso, FOREGROUND_SERVICE_LOCATION, POST_NOTIFICATIONS, servicio location privado y stopWithTask=true. ACCESS_BACKGROUND_LOCATION ausente.
- Gradle detenido tras el build.

Los logs quedan en C:\Proyecto_001\.tools\logs\parte6-*.log y los informes JSON en docs/VERIFICACION_APK_PARTE_6.json y docs/VERIFICACION_PERMISOS_PARTE_6.json.

## Percances resueltos

La prueba de pantalla mezclaba zonas asíncronas de Flutter y quedaba esperando al cancelar el stream; se alineó su ciclo nativo con runAsync. La prueba anterior de guardar itinerario necesitó desplazamiento explícito tras añadir Iniciar viaje. Se corrigió el caso de pérdida larga de GPS para permitir retomar progreso y se evitó que actualizar posición reencuadre el mapa. Todos los casos pasan en la batería final.

Cambios imprescindibles de partes previas: propiedad exclusiva de ubicación en ExplorerLocationController, comparación del contenido de la lista de itinerarios del mapa y acceso global de navegación al viaje activo. Dependencia nueva fijada: flutter_local_notifications22.3.3 y desugaring Android2.1.4. No se modificó el paquete de rutas ni los originales gráficos.

## No verificado

No hay Android físico conectado: notificación visible/persistente, continuidad al minimizar/bloquear, modo avión, consumo, GPS real, sonido, vibración y comportamiento de fabricantes pendientes. iOS tiene permisos/configuración, pero requiere macOS/Xcode y equipo para compilar y comprobar haptics/notificaciones en segundo plano. El servicio no garantiza sobrevivir a terminación del proceso por el sistema y no se reinicia automáticamente. La configuración de sonido/vibración del sistema prevalece.

La guía concreta de prueba y límites está en docs/VIAJE_ACTIVO_6.md. El juego no se mostró como botón incompleto; se conecta en Parte7. No se ejecutó push ni despliegue.
