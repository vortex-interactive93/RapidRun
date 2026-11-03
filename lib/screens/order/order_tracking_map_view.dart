// File: lib/screens/order/order_tracking_map_view.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

class OrderTrackingMapView extends StatefulWidget {
  final String orderId;
  final double storeLat;
  final double storeLng;
  final double deliveryLat;
  final double deliveryLng;

  const OrderTrackingMapView({
    super.key,
    required this.orderId,
    this.storeLat = 32.7538,
    this.storeLng = -97.4302,
    this.deliveryLat = 32.759602,
    this.deliveryLng = -97.471416,
  });

  @override
  State<OrderTrackingMapView> createState() => _OrderTrackingMapViewState();
}

class _OrderTrackingMapViewState extends State<OrderTrackingMapView> {
  final MapController _mapController = MapController();
  StreamSubscription<DocumentSnapshot>? _orderSubscription;

  late LatLng _storeLocation;
  late LatLng _deliveryLocation;

  LatLng? _driverPosition;
  double _driverHeading = 0.0;
  List<LatLng> _routePoints = [];
  bool _isLoadingRoute = true;
  bool _hasInitialBoundsFitted = false;

  @override
  void initState() {
    super.initState();
    _storeLocation = LatLng(widget.storeLat, widget.storeLng);
    _deliveryLocation = LatLng(widget.deliveryLat, widget.deliveryLng);
    _subscribeToOrderAndTelemetry();
  }

  @override
  void dispose() {
    _orderSubscription?.cancel();
    super.dispose();
  }

  void _subscribeToOrderAndTelemetry() {
    _orderSubscription = FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.orderId)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists || !mounted) return;
      final data = snapshot.data() as Map<String, dynamic>?;
      if (data == null) return;

      // 1. Dynamic Store Location from Firestore order
      if (data['storeLat'] != null && data['storeLng'] != null) {
        final lat = (data['storeLat'] as num).toDouble();
        final lng = (data['storeLng'] as num).toDouble();
        _storeLocation = LatLng(lat, lng);
      } else if (data['storeLocation'] != null) {
        final storeMap = data['storeLocation'] as Map<String, dynamic>;
        final lat = (storeMap['latitude'] as num?)?.toDouble();
        final lng = (storeMap['longitude'] as num?)?.toDouble();
        if (lat != null && lng != null) {
          _storeLocation = LatLng(lat, lng);
        }
      }

      // 2. Dynamic Delivery Destination from Firestore order
      if (data['customerLat'] != null && data['customerLng'] != null) {
        final lat = (data['customerLat'] as num).toDouble();
        final lng = (data['customerLng'] as num).toDouble();
        _deliveryLocation = LatLng(lat, lng);
      } else if (data['deliveryLocation'] != null) {
        final destMap = data['deliveryLocation'] as Map<String, dynamic>;
        final lat = (destMap['latitude'] as num?)?.toDouble();
        final lng = (destMap['longitude'] as num?)?.toDouble();
        if (lat != null && lng != null) {
          _deliveryLocation = LatLng(lat, lng);
        }
      }

      // 3. Fetch street-level polyline if not loaded yet
      if (_routePoints.isEmpty) {
        _fetchStreetRoute();
      }

      // 4. Live Driver GPS Telemetry stream
      final loc = data['driverLocation'] as Map<String, dynamic>?;
      if (loc != null) {
        final lat = (loc['latitude'] as num).toDouble();
        final lng = (loc['longitude'] as num).toDouble();
        final heading = (loc['heading'] as num?)?.toDouble() ?? 0.0;
        final newPos = LatLng(lat, lng);

        setState(() {
          _driverPosition = newPos;
          _driverHeading = heading;
        });

        if (!_hasInitialBoundsFitted) {
          _fitRouteBounds();
          _hasInitialBoundsFitted = true;
        }
      }
    });
  }

  Future<void> _fetchStreetRoute() async {
    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/'
      '${_storeLocation.longitude},${_storeLocation.latitude};'
      '${_deliveryLocation.longitude},${_deliveryLocation.latitude}'
      '?overview=full&geometries=geojson',
    );

    try {
      final response = await http.get(url, headers: {'User-Agent': 'RapidRun-App/1.0'});

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final routes = data['routes'] as List<dynamic>?;

        if (routes != null && routes.isNotEmpty) {
          final coordinates = routes[0]['geometry']['coordinates'] as List<dynamic>;
          final points = coordinates.map((c) {
            return LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble());
          }).toList();

          if (mounted) {
            setState(() {
              _routePoints = points;
              _isLoadingRoute = false;
            });
            _fitRouteBounds();
          }
          return;
        }
      }
    } catch (e) {
      debugPrint('⚠️ [OSRM Polyline Warning]: $e');
    }

    if (mounted) {
      setState(() {
        _routePoints = [_storeLocation, _deliveryLocation];
        _isLoadingRoute = false;
      });
    }
  }

  void _fitRouteBounds() {
    final bounds = LatLngBounds.fromPoints([
      _storeLocation,
      _deliveryLocation,
      if (_driverPosition != null) _driverPosition!,
    ]);

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 36),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 280,
      decoration: BoxDecoration(
        color: const Color(0xFF121418), // Prevents white flashing
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _storeLocation,
              initialZoom: 14.2,
              minZoom: 11.0,
              maxZoom: 18.5, // Allows close street-level inspection
              backgroundColor: const Color(0xFF121418), // Pure Obsidian Dark fallback
            ),
            children: [
              // 1. Watermark-Free Obsidian Tiles with Native Zoom Scaling
              TileLayer(
                urlTemplate:
                    'https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Dark_Gray_Base/MapServer/tile/{z}/{y}/{x}',
                userAgentPackageName: 'com.rapidrun.rapidrun',
                maxNativeZoom: 16, // Upsamples zoom 16 tiles at zoom 17+ to prevent white screen
                maxZoom: 19,
              ),

              // 2. Turn-by-Turn Route Polyline (RapidRun Titanium Amber)
              if (_routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      strokeWidth: 4.5,
                      color: const Color(0xFFE5A93C),
                      borderColor: const Color(0xFF1E160C),
                      borderStrokeWidth: 2.0,
                    ),
                  ],
                ),

              // 3. Dynamic Location Markers
              MarkerLayer(
                markers: [
                  // Store Hub Marker (Westover Village)
                  Marker(
                    point: _storeLocation,
                    width: 42,
                    height: 42,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF14171D),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFE5A93C), width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFE5A93C).withValues(alpha: 0.3),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.storefront_rounded, color: Color(0xFFE5A93C), size: 22),
                    ),
                  ),

                  // Customer Destination Marker (White Settlement Rd)
                  Marker(
                    point: _deliveryLocation,
                    width: 42,
                    height: 42,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF14171D),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF10B981), width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF10B981).withValues(alpha: 0.3),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.home_rounded, color: Color(0xFF10B981), size: 22),
                    ),
                  ),

                  // Real-time Vehicle Puck with Smooth Compass Heading
                  if (_driverPosition != null)
                    Marker(
                      point: _driverPosition!,
                      width: 44,
                      height: 44,
                      child: Transform.rotate(
                        angle: (_driverHeading * (3.1415926535 / 180)),
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFE5A93C),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.black, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFE5A93C).withValues(alpha: 0.5),
                                blurRadius: 14,
                                spreadRadius: 3,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.navigation, color: Colors.black, size: 22),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),

          // Loading Badge for initial route calculation
          if (_isLoadingRoute)
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF14171D).withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 12,
                      width: 12,
                      child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFFE5A93C)),
                    ),
                    SizedBox(width: 6),
                    Text(
                      'ROUTING...',
                      style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
