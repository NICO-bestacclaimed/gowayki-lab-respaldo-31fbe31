# Gowayki Lab (TECSUP)

Proyecto académico: **interfaces** al estilo Gowayki GO + **MapLibre offline**
con rutas del GTFS de Arequipa (`gtfs/arequipa/gtfs`).

No incluye motores de navegación, OTP, Places ni lógica de producción.

## Correr

```bash
cd gowayki_lab
flutter pub get
flutter run
```

Modo demo (sin Firebase) por defecto. Con Firebase:

```bash
flutterfire configure
flutter run --dart-define=USE_FIREBASE=true
```

## Datos offline

| Asset | Origen |
|-------|--------|
| `assets/map/` | MBTiles + estilo Arequipa (MapLibre) |
| `assets/gtfs/*.txt` | Copia de `gtfs/arequipa/gtfs` |
| `assets/gtfs/network.json` | Rutas+shapes simplificados para el mapa |

## Estructura

```
lib/
  app/features/     # pantallas (interfaces)
  app/common/ui/    # layouts tipo Gowayki
  shared/theme/     # tokens de marca (Culpeo / naranja)
  data/             # Firebase + demo
  domain/           # contratos
  infra/map/        # MapLibre offline + capas GTFS
```
