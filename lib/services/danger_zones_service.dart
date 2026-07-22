import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/danger_zone_model.dart';

class DangerZoneService {
  Future<List<DangerZone>> loadDangerZones() async {
    final jsonString = await rootBundle.loadString(
      'assets/SA_Danger_Zones_Enhanced.json',
    );

    final List<dynamic> jsonData = json.decode(jsonString);

    return jsonData.map((zone) => DangerZone.fromJson(zone)).toList();
  }

  Future<Set<Circle>> loadDangerZonesCircle() async {
    final jsonString = await rootBundle.loadString(
      'assets/SA_Danger_Zones_Enhanced.json',
    );

    final List<dynamic> jsonData = json.decode(jsonString);

    List<DangerZone> zones = jsonData
        .map((zone) => DangerZone.fromJson(zone))
        .toList();

    final dZC = <Circle>{};
    for (final zone in zones) {
      final color = await DangerZoneService().getRiskColor(zone);
      final fillColor = color.withValues(alpha: 0.3);

      Circle dangerZone = Circle(
        circleId: CircleId(zone.name),
        center: LatLng(zone.latitude, zone.longitude),
        radius: zone.radius,
        fillColor: fillColor,
        strokeColor: color,
        strokeWidth: 2,
      );

      dZC.add(dangerZone);
    }

    return dZC;
  }

  Future<Color> getRiskColor(DangerZone zone) async {
    switch (zone.riskLevel) {
      case 1:
        return const Color(0xFF2196F3); // Blue
      case 2:
        return const Color(0xFFFFC107); // Amber
      case 3:
        return const Color(0xFFFF9800); // Orange
      case 4:
        return const Color(0xFFF44336); // Red
      case 5:
        return const Color(0xFF8B0000); // Dark Red
      default:
        return Colors.grey;
    }
  }
}
