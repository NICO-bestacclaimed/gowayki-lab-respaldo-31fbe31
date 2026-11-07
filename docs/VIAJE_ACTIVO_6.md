# Viaje activo y alertas locales

La Parte6 usa el itinerario calculado, sus paraderos y su geometría; no sigue vehículos ni necesita Firebase. El estado se mantiene en memoria durante el proceso actual. No guarda un historial de coordenadas ni arranca con el teléfono, una actualización o un reinicio del proceso.

## Flujo

1. En el detalle, Iniciar viaje explica ubicación, notificaciones y finalización antes de pedir permisos.
2. Solo Android/iOS muestran el acceso. Se comprueban ubicación, GPS y notificaciones. Android exige iniciar con la actividad visible; se comprueba nuevamente antes de suscribirse.
3. Caminar al punto de subida avanza con una posición a ≤50m o con confirmación explícita. Ya subí arma la alarma del tramo elegido. No se deduce la subida por cercanía a una ruta.
4. Durante el tramo se muestra distancia aproximada sobre su geometría y paraderos pendientes. Al llegar a ≤60m sobre el recorrido y del punto de bajada se avanza al siguiente paso. Ya bajé permite avanzar cuando el GPS no lo detecte.
5. El último tramo termina al llegar o con Terminar viaje. La app cancela la suscripción y elimina las alertas locales. Se puede volver a la pantalla desde el acceso Viaje en curso de las pestañas.

Android reutiliza el servicio nativo de Geolocator, con notificación persistente GoWayki · Viaje en curso, wakelock durante la suscripción y stopWithTask=true. La ubicación de Explorar se suspende antes para que una suscripción anterior no impida configurar el servicio. Cancelar el seguimiento libera el servicio antes de permitir que Explorar vuelva a usar ubicación. Cerrar la tarea o terminar el proceso no restaura automáticamente un viaje.

## Umbrales y recuperación

Se aceptan posiciones de hasta30s, precisión ≤60m y orden temporal creciente. Las posiciones a más de100m de la geometría no avanzan el tramo ni disparan alarmas. El progreso es monótono; la primera proyección se limita al comienzo del tramo y las siguientes al avance posible según tiempo transcurrido, para reducir saltos en cruces o bucles. Después de una pérdida prolongada de GPS puede recuperar la posición sobre el recorrido. No se interpola movimiento ni se inventan muestras.

La alerta de bajada se emite una vez por tramo cuando queda un paradero o ~400m sobre la geometría. Al completar un tramo con otro transporte posterior se emite la alerta de zona de transbordo. Son aproximaciones sobre candidatos GTFS: no certifican un paradero físico. La pantalla avisa si falta una posición reciente o precisa.

Ajustes se consulta al emitir cada alerta: sonido usa sonido+vibración; vibración usa un canal Android distinto sin sonido; desactivada no publica alertas. La notificación persistente de ubicación sigue siendo necesaria. Android conserva el control del usuario sobre los canales. En iOS se solicita aviso local y se usa feedback háptico; su vibración/sonido en segundo plano dependen del sistema y requieren comprobación física.

## Configuración y verificación

Manifest Android: FOREGROUND_SERVICE, FOREGROUND_SERVICE_LOCATION, POST_NOTIFICATIONS, WAKE_LOCK y permisos de ubicación durante uso. Sin ACCESS_BACKGROUND_LOCATION ni receptores de arranque. El servicio no se exporta. Notificaciones inmediatas, sin alarmas exactas, programación ni permisos de batería adicionales.

Info.plist: explicaciones de ubicación y UIBackgroundModes/location. AppleSettings habilita actualizaciones durante un viaje activo e indicador de ubicación. AppDelegate establece el delegado de notificaciones. iOS no se compila ni valida desde este Windows.

La verificación está en test/trip_tracker_test.dart, test/active_trip_test.dart y test/trip_notifications_test.dart. tool/verify_trip_android.py inspecciona el manifest del APK compilado, no solo el XML fuente. El mapa recibe la posición aceptada y conserva su cámara entre muestras; solo cambia el encuadre al cambiar realmente el itinerario.

## Prueba pendiente en Android físico

Iniciar un viaje con GPS y notificaciones permitidos; comprobar que aparece la notificación persistente. Confirmar Ya subí y simular posiciones siguiendo la geometría antes/después de400m y del último paradero, luego el transbordo. Repetir con sonido, vibración y desactivada. Minimizar la app, bloquear pantalla y comprobar continuidad. Terminar y verificar que desaparece la notificación y deja de actualizar ubicación. Repetir con GPS desactivado, acceso denegado, ubicación aproximada y cierre desde tareas recientes. Sin un equipo conectado, ninguno de estos efectos físicos se declara verificado.

Referencias primarias consultadas: [Geolocator](https://pub.dev/packages/geolocator), [servicios de ubicación Android](https://developer.android.com/develop/background-work/services/fgs/service-types#location), [notificaciones locales](https://pub.dev/packages/flutter_local_notifications/versions/22.3.3), [ubicación en segundo plano Apple](https://developer.apple.com/documentation/corelocation/handling-location-updates-in-the-background).
