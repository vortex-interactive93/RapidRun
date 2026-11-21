// File: rapidrun_driver/lib/presentation/home/map_styles/midnight_titanium.dart

/// Dark-titanium map theme tuned for RapidRun's gold (#E6B450) navigation UI,
/// lifting building & structure geometry so 3D extrusions read clearly at speed.
const String midnightTitaniumMapStyle = '''
[
  {
    "elementType": "geometry",
    "stylers": [
      { "color": "#11141A" }
    ]
  },
  {
    "elementType": "labels.text.fill",
    "stylers": [
      { "color": "#B8C0CC" }
    ]
  },
  {
    "elementType": "labels.text.stroke",
    "stylers": [
      { "color": "#11141A" },
      { "weight": 3 }
    ]
  },
  {
    "featureType": "landscape.manuscript",
    "elementType": "geometry.fill",
    "stylers": [
      { "color": "#262B36" }
    ]
  },
  {
    "featureType": "landscape.manuscript",
    "elementType": "geometry.stroke",
    "stylers": [
      { "color": "#6E5A2E" },
      { "weight": 0.8 }
    ]
  },
  {
    "featureType": "poi.business",
    "elementType": "geometry.fill",
    "stylers": [
      { "color": "#2C2923" }
    ]
  },
  {
    "featureType": "poi.government",
    "elementType": "geometry.fill",
    "stylers": [
      { "color": "#252A34" }
    ]
  },
  {
    "featureType": "poi.medical",
    "elementType": "geometry.fill",
    "stylers": [
      { "color": "#242C33" }
    ]
  },
  {
    "featureType": "poi.school",
    "elementType": "geometry.fill",
    "stylers": [
      { "color": "#292822" }
    ]
  },
  {
    "featureType": "poi.park",
    "elementType": "geometry.fill",
    "stylers": [
      { "color": "#15221C" }
    ]
  },
  {
    "featureType": "road",
    "elementType": "geometry.fill",
    "stylers": [
      { "color": "#202530" }
    ]
  },
  {
    "featureType": "road",
    "elementType": "geometry.stroke",
    "stylers": [
      { "color": "#14171F" },
      { "weight": 1.2 }
    ]
  },
  {
    "featureType": "road.highway",
    "elementType": "geometry.fill",
    "stylers": [
      { "color": "#2E3442" }
    ]
  },
  {
    "featureType": "road.highway",
    "elementType": "geometry.stroke",
    "stylers": [
      { "color": "#C99A3E" },
      { "weight": 1.0 }
    ]
  },
  {
    "featureType": "water",
    "elementType": "geometry.fill",
    "stylers": [
      { "color": "#0C1521" }
    ]
  }
]
''';
