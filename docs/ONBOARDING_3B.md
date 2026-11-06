# Punto de control 3B — identidad, bienvenida y ubicación

Se usa el logo real entregado en `C:\Proyecto_001\Imagenes- Proyecto001`. Las quince ilustraciones corresponden exactamente a los quince PNG originales; se copiaron sus versiones WebP ya entregadas, byte por byte y conservando transparencia. El logo y los quince WebP suman 4.169.234 bytes. `tool/data/artwork_sources.json` conserva procedencia, tamaño y SHA-256; los originales y ZIP se mantienen fuera de los assets de la app, sin alteraciones.

El splash representa la carga real del paquete, sin temporizador ficticio. La introducción tiene tres diapositivas: Encuentra tu combi; Sabe dónde bajar; Llega a tiempo (tiempos estimados). Cada diapositiva usa cinco ilustraciones, con decodificación limitada al tamaño de presentación para reducir memoria. El contenido admite desplazamiento vertical y texto grande.

Al terminar u omitir las ilustraciones se muestra la explicación de ubicación. No se solicita un permiso automáticamente al entrar. Permitir ubicación comprueba el permiso, solicita únicamente si hace falta y permite continuar al concederlo. Denegación y denegación permanente tienen estados distintos; esta última ofrece abrir los ajustes del sistema. Continuar sin ubicación también completa la introducción, que no se repite al recrear la app.

Android ya declara ubicación aproximada/precisa en primer plano. Se agregó `NSLocationWhenInUseUsageDescription` en iOS. No se añadió ubicación en segundo plano ni se obtiene una posición en esta sección. Las pruebas usan un repositorio de permisos sustituible; los diálogos reales del dispositivo y compilación iOS no se han probado desde Windows.

Las 13 pruebas de interfaz acumuladas de 3A/3B pasaron, incluidas integridad de assets, permiso explícito, rechazo, ajustes y persistencia de primera ejecución. Se corrigió una estructura de paréntesis del nuevo widget antes de validar. La suite completa y el APK se verificarán al cerrar la Parte 3.
