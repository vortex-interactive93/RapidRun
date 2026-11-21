// File: rapidrun_driver/lib/presentation/home/map_styles/midnight_titanium.dart

/// High-contrast dark-titanium map theme engineered to stay legible at wide,
/// mid-range, and close zoom levels while keeping POI clutter off so RapidRun
/// partner stores and the gold (#E6B450) route command attention.
const String midnightTitaniumMapStyle = '''
[
  {
    "elementType": "geometry",
    "stylers": [
      { "color": "#141821" }
    ]
  },
  {
    "elementType": "labels.text.fill",
    "stylers": [
      { "color": "#E2E8F0" }
    ]
  },
  {
    "elementType": "labels.text.stroke",
    "stylers": [
      { "color": "#0B0E14" },
      { "weight": 4 }
    ]
  },
  {
    "featureType": "landscape",
    "elementType": "geometry.fill",
    "stylers": [
      { "color": "#151923" }
    ]
  },
  {
    "featureType": "landscape.man_made",
    "elementType": "geometry.fill",
    "stylers": [
      { "color": "#283042" }
    ]
  },
  {
    "featureType": "landscape.man_made",
    "elementType": "geometry.stroke",
    "stylers": [
      { "color": "#8C6D32" },
      { "weight": 1.25 }
    ]
  },
  {
    "featureType": "poi",
    "stylers": [
      { "visibility": "off" }
    ]
  },
  {
    "featureType": "poi.park",
    "elementType": "geometry.fill",
    "stylers": [
      { "visibility": "on" },
      { "color": "#172A22" }
    ]
  },
  {
    "featureType": "transit",
    "stylers": [
      { "visibility": "off" }
    ]
  },
  {
    "featureType": "road.local",
    "elementType": "geometry.fill",
    "stylers": [
      { "color": "#343D52" }
    ]
  },
  {
    "featureType": "road.local",
    "elementType": "geometry.stroke",
    "stylers": [
      { "color": "#10131A" },
      { "weight": 1.2 }
    ]
  },
  {
    "featureType": "road.arterial",
    "elementType": "geometry.fill",
    "stylers": [
      { "color": "#3F4961" }
    ]
  },
  {
    "featureType": "road.arterial",
    "elementType": "geometry.stroke",
    "stylers": [
      { "color": "#0F1219" },
      { "weight": 1.4 }
    ]
  },
  {
    "featureType": "road.highway",
    "elementType": "geometry.fill",
    "stylers": [
      { "color": "#4C5875" }
    ]
  },
  {
    "featureType": "road.highway",
    "elementType": "geometry.stroke",
    "stylers": [
      { "color": "#E6B450" },
      { "weight": 1.3 }
    ]
  },
  {
    "featureType": "water",
    "elementType": "geometry.fill",
    "stylers": [
      { "color": "#0B1624" }
    ]
  }
]
''';
