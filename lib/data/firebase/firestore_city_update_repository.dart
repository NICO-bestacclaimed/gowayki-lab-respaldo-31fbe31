import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/updates/city_update.dart';

class FirestoreCityUpdateRepository implements CityUpdateRepository {
  FirestoreCityUpdateRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;
  @override
  Future<CityUpdateMetadata?> check() async {
    final snapshot = await _db
        .collection('cities')
        .doc('arequipa')
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 12));
    final data = snapshot.data();
    return data == null ? null : CityUpdateMetadata.fromJson(data);
  }
}

class DisabledCityUpdateRepository implements CityUpdateRepository {
  @override
  Future<CityUpdateMetadata?> check() async => null;
}
