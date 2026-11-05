class City {
  const City({
    required this.code,
    required this.name,
    required this.region,
    required this.centerLat,
    required this.centerLng,
  });

  final String code;
  final String name;
  final String region;
  final double centerLat;
  final double centerLng;

  factory City.fromMap(Map<String, dynamic> map) => City(
        code: map['code'] as String? ?? '',
        name: map['name'] as String? ?? '',
        region: map['region'] as String? ?? '',
        centerLat: (map['center_lat'] as num?)?.toDouble() ?? 0,
        centerLng: (map['center_lng'] as num?)?.toDouble() ?? 0,
      );
}
