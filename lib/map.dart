import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapWidget extends StatelessWidget {
  // Default Google Maps properties
  final bool? myLocation;
  final bool? myLocationButton;
  final bool? zoomControls;
  final CameraPosition? camPosition;
  final bool? compass;
  final Set<Marker>? markers;
  final Set<Polyline>? polylines;
  final Set<Polygon>? polygons;
  final Set<Circle>? circles;

  // custom map widget properties
  final LatLng? defaultPosition;
  final LatLng? currentPosition;
  final bool? isSharingTrip;
  final String? initialTripId;

  final MapCreatedCallback? onMapCreate;

  const MapWidget({
    super.key,
    this.myLocation,
    this.myLocationButton,
    this.zoomControls,
    this.camPosition,
    this.compass,
    this.markers,
    this.polygons,
    this.polylines,
    this.circles,

    this.defaultPosition,
    this.currentPosition,
    this.isSharingTrip,
    this.initialTripId,

    this.onMapCreate,
  });

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: currentPosition!,
        zoom: 5.0,
      ),
      onMapCreated: onMapCreate,
      myLocationEnabled: myLocation!,
      myLocationButtonEnabled: myLocationButton!,
      zoomControlsEnabled: zoomControls!,
      markers: markers ?? {},
      polylines: polylines ?? {},
      polygons: polygons ?? {},
      circles: circles ?? {},
    );
  }
}
