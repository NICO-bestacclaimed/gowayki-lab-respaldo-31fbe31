import '../../core/models/place_result.dart';

enum NavigationSearchGroup { place, stop, line, street }

class NavigationSearchResult {
  const NavigationSearchResult({
    required this.id,
    required this.name,
    required this.detail,
    required this.group,
    this.point,
    this.needsReview = false,
  });
  final String id, name, detail;
  final NavigationSearchGroup group;
  final PlaceResult? point;
  final bool needsReview;
}

class JourneyEndpoints {
  const JourneyEndpoints({required this.origin, required this.destination});
  final PlaceResult origin, destination;
}
