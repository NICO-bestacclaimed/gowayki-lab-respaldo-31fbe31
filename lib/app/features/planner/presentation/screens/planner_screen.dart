import 'package:flutter/material.dart';

import '../../../../../core/models/place_result.dart';
import '../../../../../core/models/trip_option.dart';
import '../../../../../data/service_locator.dart';
import '../../../../../shared/theme/theme.dart';

class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key, required this.destination});

  final PlaceResult destination;

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  late final Future<List<TripOption>> _future;

  static const _origin = PlaceResult(
    id: 'me',
    name: 'Origen de demostración',
    address: 'Punto de partida (demo)',
    latitude: -16.40,
    longitude: -71.54,
  );

  @override
  void initState() {
    super.initState();
    _future = ServiceLocator.trips.plan(
      origin: _origin,
      destination: widget.destination,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Planificar viaje')),
      body: FutureBuilder<List<TripOption>>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final options = snap.data!;
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Card(
                color: AppColors.surface,
                child: ListTile(
                  leading: const Icon(Icons.route, color: AppColors.primary),
                  title: Text('${_origin.name} → ${widget.destination.name}'),
                  subtitle: Text(widget.destination.address),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const Text(
                'Opciones de demostración',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.sm),
              ...options.map(
                (o) => Card(
                  color: AppColors.surface,
                  child: ExpansionTile(
                    title: Text(o.summary),
                    subtitle: Text(
                      '~${o.durationMinutes} min · ${o.transferCount} transbordo(s)',
                    ),
                    children: o.legs
                        .map(
                          (leg) => ListTile(
                            dense: true,
                            leading: const Icon(Icons.circle, size: 10, color: AppColors.primary),
                            title: Text(leg),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
