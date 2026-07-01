import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:http/http.dart' as http;

class MapCacheService {
  static final MapCacheService _instance = MapCacheService._internal();
  factory MapCacheService() => _instance;
  MapCacheService._internal();

  Database? _database;
  String? _cacheDir;

  final List<Map<String, dynamic>> cities = [
    {'name': 'Cape Town', 'lat': -33.9249, 'lng': 18.4241, 'radius': 20},
    {'name': 'Johannesburg', 'lat': -26.2041, 'lng': 28.0473, 'radius': 20},
    {'name': 'Pretoria', 'lat': -25.7479, 'lng': 28.2293, 'radius': 20},
    {'name': 'Durban', 'lat': -29.8587, 'lng': 31.0218, 'radius': 20},
    {'name': 'Port Elizabeth', 'lat': -33.9608, 'lng': 25.6022, 'radius': 15},
    {'name': 'Bloemfontein', 'lat': -29.0852, 'lng': 26.1596, 'radius': 15},
    {'name': 'East London', 'lat': -33.0152, 'lng': 27.9116, 'radius': 15},
    {'name': 'Kimberley', 'lat': -28.7282, 'lng': 24.7499, 'radius': 15},
    {'name': 'Nelspruit', 'lat': -25.4749, 'lng': 30.9703, 'radius': 15},
    {'name': 'Polokwane', 'lat': -23.9042, 'lng': 29.4689, 'radius': 15},
  ];

  Future<void> initDatabase() async {
    if (_database != null) return;

    final directory = await getApplicationDocumentsDirectory();
    _cacheDir = p.join(directory.path, 'map_tiles');
    await Directory(_cacheDir!).create(recursive: true);

    final dbPath = p.join(directory.path, 'map_cache.db');
    _database = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) {
        return db.execute(
          'CREATE TABLE tiles ('
          'id INTEGER PRIMARY KEY AUTOINCREMENT,'
          'city TEXT,'
          'z INTEGER,'
          'x INTEGER,'
          'y INTEGER,'
          'data BLOB,'
          'timestamp INTEGER'
          ')',
        );
      },
    );
  }

  Future<void> downloadTile(String city, int z, int x, int y) async {
    await initDatabase();
    final url = 'https://tile.openstreetmap.org/$z/$x/$y.png';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        await _database!.insert(
          'tiles',
          {
            'city': city,
            'z': z,
            'x': x,
            'y': y,
            'data': response.bodyBytes,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    } catch (e) {
      print('Failed to download tile: $e');
    }
  }

  Future<Uint8List?> getTile(int z, int x, int y) async {
    await initDatabase();
    final result = await _database!.query(
      'tiles',
      where: 'z = ? AND x = ? AND y = ?',
      whereArgs: [z, x, y],
    );
    if (result.isNotEmpty) {
      return result.first['data'] as Uint8List?;
    }
    return null;
  }

  Future<void> downloadCity(String cityName, Function(int, int) onProgress) async {
    await initDatabase();

    final city = cities.firstWhere(
      (c) => c['name'] == cityName,
      orElse: () => throw Exception('City not found'),
    );

    final lat = city['lat'] as double;
    final lng = city['lng'] as double;
    final radius = city['radius'] as int;
    final zoomLevels = [12, 13, 14, 15, 16];

    int totalTiles = 0;
    int downloadedTiles = 0;

    for (var z in zoomLevels) {
      final tileCount = _getTileCountForRadius(z, lat, lng, radius.toDouble());
      totalTiles += tileCount;
    }

    for (var z in zoomLevels) {
      final tiles = _getTilesForRadius(z, lat, lng, radius.toDouble());
      for (var tile in tiles) {
        await downloadTile(cityName, z, tile['x']!, tile['y']!);
        downloadedTiles++;
        onProgress(downloadedTiles, totalTiles);
      }
    }
  }

  List<Map<String, int>> _getTilesForRadius(int z, double lat, double lng, double radius) {
    final tiles = <Map<String, int>>[];
    final metersPerPixel = 156543.03392 * (1 / (1 << z));
    final pixels = (radius * 1000) / metersPerPixel;
    final tileOffset = (pixels / 256).ceil();

    final centerTile = _latLngToTile(lat, lng, z);

    for (int dx = -tileOffset; dx <= tileOffset; dx++) {
      for (int dy = -tileOffset; dy <= tileOffset; dy++) {
        final x = centerTile['x']! + dx;
        final y = centerTile['y']! + dy;
        if (x >= 0 && y >= 0 && x < (1 << z) && y < (1 << z)) {
          tiles.add({'x': x, 'y': y});
        }
      }
    }
    return tiles;
  }

  int _getTileCountForRadius(int z, double lat, double lng, double radius) {
    final tiles = _getTilesForRadius(z, lat, lng, radius);
    return tiles.length;
  }

  Map<String, int> _latLngToTile(double lat, double lng, int z) {
    final x = ((lng + 180) / 360 * (1 << z)).floor();
    final y = ((1 - (0.5 - (0.5 * (1 - sin(lat * 3.141592653589793 / 180))) / (3.141592653589793 * 2)) / 1) * (1 << z)).floor();
    return {'x': x, 'y': y};
  }

  List<Map<String, dynamic>> getNearbyCities(double lat, double lng) {
    final sortedCities = List<Map<String, dynamic>>.from(cities);
    sortedCities.sort((a, b) {
      final distA = _calculateDistance(lat, lng, a['lat'], a['lng']);
      final distB = _calculateDistance(lat, lng, b['lat'], b['lng']);
      return distA.compareTo(distB);
    });
    return sortedCities;
  }

  double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    const R = 6371;
    final dLat = (lat2 - lat1) * 3.141592653589793 / 180;
    final dLng = (lng2 - lng1) * 3.141592653589793 / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * 3.141592653589793 / 180) *
        cos(lat2 * 3.141592653589793 / 180) *
        sin(dLng / 2) * sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  Future<void> deleteCityCache(String cityName) async {
    await initDatabase();
    await _database!.delete('tiles', where: 'city = ?', whereArgs: [cityName]);
  }

  Future<void> clearAllCache() async {
    await initDatabase();
    await _database!.delete('tiles');
    if (_cacheDir != null) {
      final dir = Directory(_cacheDir!);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        await dir.create();
      }
    }
  }
}