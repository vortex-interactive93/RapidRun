// File: rapidrun_driver/lib/presentation/home/map_styles/midnight_titanium.dart

/// Validated dark-titanium Google Maps style JSON with lifted building and
/// road contrast tailored for RapidRun's gold (#E6B450) navigation UI.
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
      { "color": "#B6C0CE" }
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
      { "color": "#181C24" }
    ]
  },
  {
    "featureType": "landscape.man_made",
    "elementType": "geometry.fill",
    "stylers": [
      { "color": "#282E3A" }
    ]
  },
  {
    "featureType": "landscape.man_made",
    "elementType": "geometry.stroke",
    "stylers": [
      { "color": "#6B572B" },
      { "weight": 0.7 }
    ]
  },
  {
    "featureType": "poi",
    "elementType": "geometry.fill",
    "stylers": [
      { "color": "#242934" }
    ]
  },
  {
    "featureType": "poi.park",
    "elementType": "geometry.fill",
    "stylers": [
      { "color": "#14221B" }
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
      { "color": "#13161D" },
      { "weight": 1.1 }
    ]
  },
  {
    "featureType": "road.highway",
    "elementType": "geometry.fill",
    "stylers": [
      { "color": "#313746" }
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
