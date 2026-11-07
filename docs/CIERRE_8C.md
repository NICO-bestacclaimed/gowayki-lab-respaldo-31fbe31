# Punto de control 8C — sincronización

Favoritos de líneas, Casa/Trabajo, lugares/paraderos, viajes guardados y recientes se conservan primero en SharedPreferences y se sincronizan por elemento bajo users/{uid}/state. La biblioteca local anterior se migra sin inventar datos. Máximo30 recientes activos; los retirados pierden su contenido y conservan una clave SHA-256 y una revisión para impedir que un dispositivo antiguo los restaure. Las versiones locales y remotas se combinan con revisiones por reloj y desempate por instalación; el reloj avanza más allá de lo observado. Los registros son inmutables.

Cada cuenta tiene su caché independiente. El invitado se incorpora al iniciar sesión; la vinculación conserva la misma UID, y si Google abre una cuenta existente se incorporan los favoritos de la sesión anónima anterior. Al cerrar sesión o cambiar entre cuentas reales no se copia la biblioteca privada anterior al invitado ni a otra cuenta. El dato local precede a la red: no se sube nada hasta recibir una instantánea del servidor; las transacciones comparan revisiones antes de escribir. Un borrado no se restaura por una escritura antigua. Los errores conservan la copia local y Perfil permite reintentar; reintentos automáticos limitados.

El perfil informa el estado de sincronización. La antigua ruta profiles, incompatible con las reglas, se corrigió a users/{uid}/preferences/settings. El modo local mantiene los formatos heredados para compatibilidad; nunca guarda la biblioteca de una cuenta real en las claves del invitado.

Verificación: suite completa158 pruebas Flutter aprobadas; después de los últimos ajustes pasaron17 pruebas dirigidas (incluida una nueva de migración/recientes e inmutabilidad). Análisis final limpio. Emuladores:36 pruebas aprobadas (28 reglas iniciales,4Auth y4 transacciones/sesiones). Ambos APK Android, USE_FIREBASE=true/false, compilados y datos/mapa/juego/SQLite verificados. La variante con Firebase conserva el cliente Google compilado correcto. Gradle y emuladores detenidos.

Percances resueltos: la primera integración dependía de una espera circular del proveedor; las pruebas detectaron que las proyecciones no se actualizaban inmediatamente y una inicialización cruzaba las zonas de pruebas de widgets. Se separó la escucha de la carga inicial, las acciones publican el estado antes de finalizar y la prueba aislada espera la caché igual que la navegación normal. También se corrigió el orden del primer reciente añadido tras migrar.

Pendiente: Firestore real aún no creado por el usuario; no se verificaron sincronización entre teléfonos reales, índices desplegados ni permisos del proyecto en producción. No se desplegó nada. Las pruebas prueban el coordinador con transporte controlado y el protocolo/reglas en emulador; el adaptador nativo requiere comprobación en Android/iOS. Continúa8D–8E.

Referencia primaria: https://firebase.google.com/docs/firestore/manage-data/transactions
