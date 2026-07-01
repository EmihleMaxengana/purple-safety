import 'package:flutter/material.dart';
import 'package:location/location.dart' as location;
import 'package:purple_safety/services/map_cache_service.dart';

class OfflineMapsScreen extends StatefulWidget {
  const OfflineMapsScreen({Key? key}) : super(key: key);
  @override
  State<OfflineMapsScreen> createState() => _OfflineMapsScreenState();
}

class _OfflineMapsScreenState extends State<OfflineMapsScreen> {
  final MapCacheService _cacheService = MapCacheService();
  final location.Location _location = location.Location();

  List<Map<String, dynamic>> _allCities = [];
  List<Map<String, dynamic>> _filteredCities = [];
  bool _isLoading = true;
  bool _isDownloading = false;
  String? _downloadingCity;
  double _downloadProgress = 0;
  String _downloadStatus = '';
  int _totalTiles = 0;
  int _downloadedTiles = 0;
  String _errorMessage = '';
  String _searchQuery = '';
  String _closestCity = '';

  @override
  void initState() {
    super.initState();
    _loadCities();
  }

  Future<void> _loadCities() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // First, load all cities from the service
      final allCities = _cacheService.cities;

      // Try to get location
      bool serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _location.requestService();
        if (!serviceEnabled) {
          // If location not available, just show all cities
          setState(() {
            _allCities = allCities;
            _filteredCities = allCities;
            _isLoading = false;
          });
          return;
        }
      }

      final permission = await _location.hasPermission();
      if (permission == location.PermissionStatus.denied) {
        final requested = await _location.requestPermission();
        if (requested != location.PermissionStatus.granted) {
          // Permission denied – show all cities
          setState(() {
            _allCities = allCities;
            _filteredCities = allCities;
            _isLoading = false;
          });
          return;
        }
      }

      final currentLocation = await _location.getLocation();
      if (currentLocation.latitude != null && currentLocation.longitude != null) {
        // Get nearby cities sorted by distance
        final nearby = _cacheService.getNearbyCities(
          currentLocation.latitude!,
          currentLocation.longitude!,
        );
        // The first one is the closest
        if (nearby.isNotEmpty) {
          _closestCity = nearby.first['name'] ?? '';
        }
        // Combine: show closest first, then the rest
        final all = [...nearby, ...allCities.where((city) => !nearby.contains(city))];
        // Remove duplicates (by name)
        final seen = <String>{};
        final unique = <Map<String, dynamic>>[];
        for (var city in all) {
          final name = city['name'] as String;
          if (!seen.contains(name)) {
            seen.add(name);
            unique.add(city);
          }
        }
        setState(() {
          _allCities = unique;
          _filteredCities = unique;
          _isLoading = false;
        });
      } else {
        setState(() {
          _allCities = allCities;
          _filteredCities = allCities;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading cities: $e';
        _isLoading = false;
      });
    }
  }

  void _filterCities(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredCities = _allCities;
      } else {
        _filteredCities = _allCities.where((city) {
          final name = city['name'] as String;
          return name.toLowerCase().contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  Future<void> _downloadCity(String cityName) async {
    if (_isDownloading) return;
    setState(() {
      _isDownloading = true;
      _downloadingCity = cityName;
      _downloadProgress = 0;
      _downloadStatus = 'Starting...';
      _downloadedTiles = 0;
      _totalTiles = 0;
    });
    try {
      await _cacheService.downloadCity(cityName, (downloaded, total) {
        setState(() {
          _downloadedTiles = downloaded;
          _totalTiles = total;
          _downloadProgress = total > 0 ? downloaded / total : 0;
          _downloadStatus = 'Downloading $downloaded of $total tiles...';
        });
      });
      setState(() {
        _downloadStatus = '✅ Complete!';
        _isDownloading = false;
        _downloadingCity = null;
      });
      // Refresh to update "downloaded" counts
      await _loadCities();
      _showCompletionDialog(cityName);
    } catch (e) {
      setState(() {
        _downloadStatus = '❌ Failed: $e';
        _isDownloading = false;
        _downloadingCity = null;
      });
    }
  }

  void _showCompletionDialog(String cityName) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: const Text('Download Complete'),
        content: Text('Map data for $cityName downloaded.'),
        actions: [ TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')) ],
        backgroundColor: const Color(0xFF1a0f2e),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.green.withOpacity(0.5)),
        ),
      ),
    );
  }

  Future<void> _deleteCityCache(String cityName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Maps'),
        content: Text('Delete maps for $cityName?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
        backgroundColor: const Color(0xFF1a0f2e),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.purple.withOpacity(0.3)),
        ),
      ),
    );
    if (confirm == true) {
      await _cacheService.deleteCityCache(cityName);
      await _loadCities();
    }
  }

  Future<void> _clearAllCache() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All'),
        content: const Text('Delete all downloaded maps?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete All', style: TextStyle(color: Colors.red))),
        ],
        backgroundColor: const Color(0xFF1a0f2e),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.purple.withOpacity(0.3)),
        ),
      ),
    );
    if (confirm == true) {
      await _cacheService.clearAllCache();
      await _loadCities();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0e0718),
      appBar: AppBar(
        title: const Text('Offline Maps', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF6A1B9A),
        foregroundColor: Colors.white,
        actions: [
          if (_filteredCities.any((c) => c['downloaded'] != null && c['downloaded'] > 0))
            TextButton(
              onPressed: _clearAllCache,
              child: const Text('Clear All', style: TextStyle(color: Colors.white70)),
            ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0e0718), Color(0xFF100c1f)],
          ),
        ),
        child: _isLoading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.purple),
                    SizedBox(height: 16),
                    Text('Loading cities...', style: TextStyle(color: Colors.white70)),
                  ],
                ),
              )
            : Column(
                children: [
                  // Search bar
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: TextField(
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Search for a city...',
                        hintStyle: const TextStyle(color: Colors.white54),
                        prefixIcon: const Icon(Icons.search, color: Colors.white70),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.1),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, color: Colors.white70),
                                onPressed: () {
                                  _filterCities('');
                                  setState(() {});
                                },
                              )
                            : null,
                      ),
                      onChanged: _filterCities,
                    ),
                  ),

                  // Show closest city badge if we have one
                  if (_closestCity.isNotEmpty && _searchQuery.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.purple.withOpacity(0.5)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.location_on, color: Colors.purple, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'Closest city: $_closestCity',
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Download progress
                  if (_isDownloading)
                    Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1a0f2e),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.download, color: Colors.blue),
                              const SizedBox(width: 12),
                              Expanded(child: Text('Downloading $_downloadingCity...', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                              Text('${(_downloadProgress * 100).toInt()}%', style: const TextStyle(color: Colors.white70)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: _downloadProgress,
                            backgroundColor: Colors.grey[800],
                            color: Colors.blue,
                            minHeight: 6,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          const SizedBox(height: 8),
                          Text(_downloadStatus, style: TextStyle(color: Colors.white70, fontSize: 11)),
                        ],
                      ),
                    ),

                  // City list
                  Expanded(
                    child: _filteredCities.isEmpty
                        ? const Center(
                            child: Text(
                              'No cities found.\nTry a different search term.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white54),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _filteredCities.length,
                            itemBuilder: (context, index) {
                              final city = _filteredCities[index];
                              final cityName = city['name'] as String;
                              final downloaded = city['downloaded'] ?? 0;
                              final isDownloading = _isDownloading && _downloadingCity == cityName;
                              final isClosest = cityName == _closestCity;

                              return Card(
                                color: const Color(0xFF1a0f2e),
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: isClosest
                                        ? Colors.purple.withOpacity(0.5)
                                        : Colors.purple.withOpacity(0.3),
                                    width: isClosest ? 2 : 1,
                                  ),
                                ),
                                child: ListTile(
                                  leading: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: downloaded > 0
                                          ? Colors.green.withOpacity(0.2)
                                          : Colors.purple.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      downloaded > 0 ? Icons.check_circle : Icons.location_city,
                                      color: downloaded > 0 ? Colors.green : Colors.purple.shade300,
                                    ),
                                  ),
                                  title: Text(
                                    cityName,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: isClosest ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                  subtitle: Text(
                                    downloaded > 0
                                        ? '$downloaded tiles downloaded'
                                        : '${city['radius']}km radius',
                                    style: TextStyle(
                                      color: downloaded > 0 ? Colors.green : Colors.white54,
                                      fontSize: 12,
                                    ),
                                  ),
                                  trailing: isDownloading
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.blue,
                                          ),
                                        )
                                      : downloaded > 0
                                          ? IconButton(
                                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                                              onPressed: _isDownloading ? null : () => _deleteCityCache(cityName),
                                            )
                                          : IconButton(
                                              icon: const Icon(Icons.download, color: Colors.blue),
                                              onPressed: _isDownloading ? null : () => _downloadCity(cityName),
                                            ),
                                  onTap: () {
                                    if (downloaded > 0 && !isDownloading) {
                                      showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: Text(cityName),
                                          content: Text(
                                            '$downloaded map tiles downloaded.\n\n'
                                            'These maps are available offline.\n'
                                            'You can delete them if you need storage space.',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(context),
                                              child: const Text('OK'),
                                            ),
                                          ],
                                          backgroundColor: const Color(0xFF1a0f2e),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(20),
                                            side: BorderSide(color: Colors.purple.withOpacity(0.3)),
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}