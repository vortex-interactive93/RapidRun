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
      { "color": "#DCE4EE" }
    ]
  },
  {
    "elementType": "labels.text.stroke",
    "stylers": [
      { "color": "#0D1017" },
      { "weight": 4 }
    ]
  },
  {
    "featureType": "landscape",
    "elementType": "geometry.fill",
    "stylers": [
      { "color": "#161A24" }
    ]
  },
  {
    "featureType": "landscape.man_made",
    "elementType": "geometry.fill",
    "stylers": [
      { "color": "#232938" }
    ]
  },
  {
    "featureType": "landscape.man_made",
    "elementType": "geometry.stroke",
    "stylers": [
      { "color": "#5A4A28" },
      { "weight": 0.9 }
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
      { "color": "#172922" }
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
      { "color": "#2E3648" }
    ]
  },
  {
    "featureType": "road.local",
    "elementType": "geometry.stroke",
    "stylers": [
      { "color": "#12151D" },
      { "weight": 1.1 }
    ]
  },
  {
    "featureType": "road.arterial",
    "elementType": "geometry.fill",
    "stylers": [
      { "color": "#3A445A" }
    ]
  },
  {
    "featureType": "road.arterial",
    "elementType": "geometry.stroke",
    "stylers": [
      { "color": "#11141C" },
      { "weight": 1.3 }
    ]
  },
  {
    "featureType": "road.highway",
    "elementType": "geometry.fill",
    "stylers": [
      { "color": "#47536E" }
    ]
  },
  {
    "featureType": "road.highway",
    "elementType": "geometry.stroke",
    "stylers": [
      { "color": "#D9A74A" },
      { "weight": 1.2 }
    ]
  },
  {
    "featureType": "water",
    "elementType": "geometry.fill",
    "stylers": [
      { "color": "#0C1724" }
    ]
  }
]
''';
