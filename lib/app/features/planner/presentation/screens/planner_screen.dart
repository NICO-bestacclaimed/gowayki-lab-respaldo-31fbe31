import 'package:gowayki_lab/shared/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/models/place_result.dart';
import '../../../../../core/models/trip_option.dart';
import '../../../../providers/app_providers.dart';
import '../../../../../shared/theme/theme.dart';

class PlannerScreen extends ConsumerStatefulWidget {
  const PlannerScreen({super.key, required this.destination});

  final PlaceResult destination;

  @override
  ConsumerState<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends ConsumerState<PlannerScreen> {
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
    _future = ref
        .read(tripPlanRepositoryProvider)
        .plan(origin: _origin, destination: widget.destination);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(title: Text(context.l10n.planTrip)),
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
                color: Theme.of(context).colorScheme.surface,
                child: ListTile(
                  leading: const Icon(Icons.route, color: AppColors.primary),
                  title: Text('${_origin.name} → ${widget.destination.name}'),
                  subtitle: Text(widget.destination.address),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                context.l10n.demoOptions,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              ...options.map(
                (o) => Card(
                  color: Theme.of(context).colorScheme.surface,
                  child: ExpansionTile(
                    title: Text(o.summary),
                    subtitle: Text(
                      '~${o.durationMinutes} min · ${o.transferCount} transbordo(s)',
                    ),
                    children: o.legs
                        .map(
                          (leg) => ListTile(
                            dense: true,
                            leading: const Icon(
                              Icons.circle,
                              size: 10,
                              color: AppColors.primary,
                            ),
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
