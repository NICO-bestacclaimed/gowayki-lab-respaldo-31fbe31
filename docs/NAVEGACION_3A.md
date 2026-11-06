# Punto de control 3A — proveedores y navegación

Se reemplazó el localizador estático por proveedores Riverpod, con apertura/cierre de recursos asociados al ProviderScope. La navegación usa go_router y cuatro pestañas: Explorar, Rutas, Favoritos y Perfil. Las ramas conservan su estado; ajustes, ayuda y la pantalla de viajes existente siguen accesibles desde rutas declaradas.

Rutas usa las 98 líneas reales del SQLite. Favoritos tiene un estado vacío real y guarda selecciones en SharedPreferences; los cambios simultáneos se serializan. Perfil distingue ausencia de sesión y no inventa nombre ni correo. Se puede explorar y guardar favoritos locales sin iniciar sesión.

Se corrigieron dos problemas de la lista previa de combis: ordenaba una lista inmutable del repositorio y sus ListTile no tenían una superficie Material visible. Las pruebas comprueban abrir, buscar y seleccionar una línea.

Pruebas específicas: 6 aprobadas (carga/bienvenida, error/reintento, navegación, favoritos, persistencia y combis). Se preparan las consultas de datos fuera del reloj simulado de los tests de widgets; la espera observada era de la preparación de prueba. Se corrigieron la firma de ConsumerState y una aserción de nulabilidad. El análisis y la suite completa se repetirán en el cierre de la Parte 3.

Versiones: flutter_riverpod 3.4.3 y go_router 18.1.3. Referencias primarias: https://pub.dev/packages/flutter_riverpod y https://pub.dev/packages/go_router. No se implementó autenticación nueva, sincronización remota ni la pantalla final de itinerarios.

El usuario autorizó continuar entre secciones y suministró el material gráfico en C:\Proyecto_001\Imagenes- Proyecto001. Se continúa con 3B sin STOP intermedio.
