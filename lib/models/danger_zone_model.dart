class DangerZone {
  // final int id;
  final String province;
  final String name;
  final double latitude;
  final double longitude;
  final double radius;
  final double warningRadius;
  final double riskLevel;
  final bool approximated;

  DangerZone({
    // required this.id,
    required this.province,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.radius = 750,
    this.warningRadius = 1250,
    this.riskLevel = 3,
    this.approximated = false,
  });

  factory DangerZone.fromJson(Map<String, dynamic> json) {
    return DangerZone(
      // id: json['id'],
      province: json['province'],
      name: json['name'],
      latitude: json['latitude'],
      longitude: json['longitude'],
      radius: (json['radius'] ?? 750).toDouble(),
      warningRadius: (json['warningRadius'] ?? 1250).toDouble(),
      riskLevel: (json['riskLevel'] ?? 3).toDouble(),
      approximated: json['approximated'] ?? false,
    );
  }
}
