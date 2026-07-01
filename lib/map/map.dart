import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlong;

class MapWidget extends StatefulWidget {
  final latlong.LatLng currentPosition;
  final List<Marker>? markers;
  final List<Polyline>? polylines;
  final List<Polygon>? polygons;
  final List<CircleMarker>? circles;
  final bool myLocation;
  final bool myLocationButton;
  final bool zoomControls;
  final bool compass;
  final Function(MapController)? onMapCreate;

  const MapWidget({
    Key? key,
    required this.currentPosition,
    this.markers,
    this.polylines,
    this.polygons,
    this.circles,
    this.myLocation = false,
    this.myLocationButton = true,
    this.zoomControls = true,
    this.compass = true,
    this.onMapCreate,
  }) : super(key: key);

  @override
  State<MapWidget> createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget> {
  late MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            center: widget.currentPosition,
            zoom: 14.0,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
            ),
            onMapReady: () {
              if (widget.onMapCreate != null) {
                widget.onMapCreate!(_mapController);
              }
            },
          ),
          children: [
            TileLayer(
              // Light, colorful style – similar to Google Maps but with a purple tint
              urlTemplate:
                  'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
              subdomains: ['a', 'b', 'c'],
              userAgentPackageName: 'com.emihle.purplesafety',
            ),
            if (widget.markers != null && widget.markers!.isNotEmpty)
              MarkerLayer(markers: widget.markers!),
            if (widget.polylines != null && widget.polylines!.isNotEmpty)
              PolylineLayer(polylines: widget.polylines!),
            if (widget.polygons != null && widget.polygons!.isNotEmpty)
              PolygonLayer(polygons: widget.polygons!),
            if (widget.circles != null && widget.circles!.isNotEmpty)
              CircleLayer(circles: widget.circles!),
          ],
        ),
        // The "Locate Me" button is automatically shown if myLocationButton is true
      ],
    );
  }
}