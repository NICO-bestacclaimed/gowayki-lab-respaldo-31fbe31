import '../../core/models/transit_line.dart';

/// Red de transporte offline (GTFS).
abstract interface class TransitNetworkRepository {
  Future<List<TransitLine>> lines();
}
