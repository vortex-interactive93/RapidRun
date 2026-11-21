// File: rapidrun_driver/lib/presentation/home/map_styles/midnight_titanium.dart

/// Ultra-clean dark-titanium map style for RapidRun:
/// - Lifts 3D building silhouettes for depth without visual noise
/// - Hides ALL third-party Google POI icons & business labels (dealerships,
///   pet stores, restaurants) so ONLY RapidRun partner stores stand out!
const String midnightTitaniumMapStyle = '''
[
  {
    "elementType": "geometry",
    "stylers": [
      { "color": "#12151C" }
    ]
  },
  {
    "elementType": "labels.text.fill",
    "stylers": [
      { "color": "#9AA5B4" }
    ]
  },
  {
    "elementType": "labels.text.stroke",
    "stylers": [
      { "color": "#12151C" },
      { "weight": 3 }
    ]
  },
  {
    "featureType": "landscape",
    "elementType": "geometry.fill",
    "stylers": [
      { "color": "#171B23" }
    ]
  },
  {
    "featureType": "landscape.man_made",
    "elementType": "geometry.fill",
    "stylers": [
      { "color": "#262C38" }
    ]
  },
  {
    "featureType": "landscape.man_made",
    "elementType": "geometry.stroke",
    "stylers": [
      { "color": "#5C4B26" },
      { "weight": 0.7 }
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
      { "color": "#14211B" }
    ]
  },
  {
    "featureType": "transit",
    "stylers": [
      { "visibility": "off" }
    ]
  },
  {
    "featureType": "road",
    "elementType": "geometry.fill",
    "stylers": [
      { "color": "#222733" }
    ]
  },
  {
    "featureType": "road",
    "elementType": "geometry.stroke",
    "stylers": [
      { "color": "#12151C" },
      { "weight": 1.1 }
    ]
  },
  {
    "featureType": "road.highway",
    "elementType": "geometry.fill",
    "stylers": [
      { "color": "#303645" }
    ]
  },
  {
    "featureType": "road.highway",
    "elementType": "geometry.stroke",
    "stylers": [
      { "color": "#C6973E" },
      { "weight": 1.0 }
    ]
  },
  {
    "featureType": "water",
    "elementType": "geometry.fill",
    "stylers": [
      { "color": "#0B131E" }
    ]
  }
]
''';
