import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/navigation_search.dart';
import '../../domain/planner/itinerary.dart';

/// Part 6 supplies an action once foreground tracking and permissions are ready.
typedef StartTripAction =
    Future<void> Function(
      BuildContext context,
      Itinerary trip,
      JourneyEndpoints points,
    );
final startTripActionProvider = Provider<StartTripAction?>((ref) => null);
