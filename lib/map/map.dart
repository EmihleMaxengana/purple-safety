import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapWidget extends StatelessWidget {
  final LatLng currentPosition;
  final Set<Marker>? markers;
  final Set<Polyline>? polylines;
  final Set<Polygon>? polygons;
  final Set<Circle>? circles;
  final bool myLocation;
  final bool myLocationButton;
  final bool zoomControls;
  final bool compass;
  final MapCreatedCallback? onMapCreate;

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

  static const String _mapStyle = '''
[
  {
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#1d2c3d"
      }
    ]
  },
  {
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#8ec3b0"
      }
    ]
  },
  {
    "elementType": "labels.text.stroke",
    "stylers": [
      {
        "color": "#1a3646"
      }
    ]
  },
  {
    "featureType": "administrative.country",
    "elementType": "geometry.stroke",
    "stylers": [
      {
        "color": "#4b2e6b"
      },
      {
        "weight": 1.5
      }
    ]
  },
  {
    "featureType": "administrative.land_parcel",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#b9daa4"
      }
    ]
  },
  {
    "featureType": "poi",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#8ec3b0"
      }
    ]
  },
  {
    "featureType": "poi.park",
    "elementType": "geometry.fill",
    "stylers": [
      {
        "color": "#2a5c4a"
      }
    ]
  },
  {
    "featureType": "road",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#3c2b4f"
      }
    ]
  },
  {
    "featureType": "road.arterial",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#d4bfff"
      }
    ]
  },
  {
    "featureType": "road.highway",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#5a3e7a"
      }
    ]
  },
  {
    "featureType": "road.highway",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#f3d9ff"
      }
    ]
  },
  {
    "featureType": "transit",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#b9daa4"
      }
    ]
  },
  {
    "featureType": "water",
    "elementType": "geometry.fill",
    "stylers": [
      {
        "color": "#2e5c8a"
      }
    ]
  }
]
  ''';

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: currentPosition,
        zoom: 14.0,
      ),
      onMapCreated: (controller) {
        controller.setMapStyle(_mapStyle);
        if (onMapCreate != null) {
          onMapCreate!(controller);
        }
      },
      myLocationEnabled: myLocation,
      myLocationButtonEnabled: myLocationButton,
      zoomControlsEnabled: zoomControls,
      markers: markers ?? {},
      polylines: polylines ?? {},
      polygons: polygons ?? {},
      circles: circles ?? {},
    );
  }
}