// File: lib/services/google_places_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class PlacePrediction {
  final String description;
  final String placeId;

  const PlacePrediction({required this.description, required this.placeId});

  factory PlacePrediction.fromJson(Map<String, dynamic> json) {
    return PlacePrediction(
      description: json['description'] ?? '',
      placeId: json['place_id'] ?? '',
    );
  }
}

class PlaceDetails {
  final String line1;
  final String city;
  final String state;
  final String postalCode;

  const PlaceDetails({
    required this.line1,
    required this.city,
    required this.state,
    required this.postalCode,
  });

  factory PlaceDetails.fromJson(Map<String, dynamic> json) {
    final result = json['result'] ?? {};
    final addressComponents = result['address_components'] as List? ?? [];

    String streetNumber = '';
    String route = '';
    String city = '';
    String state = '';
    String postalCode = '';

    for (final component in addressComponents) {
      final types = List<String>.from(component['types'] ?? []);
      final val = component['long_name'] ?? '';
      final shortVal = component['short_name'] ?? '';

      if (types.contains('street_number')) {
        streetNumber = val;
      } else if (types.contains('route')) {
        route = val;
      } else if (types.contains('locality') || types.contains('sublocality')) {
        if (city.isEmpty) city = val;
      } else if (types.contains('administrative_area_level_1')) {
        state = shortVal; // e.g. TX
      } else if (types.contains('postal_code')) {
        postalCode = val;
      }
    }

    final line1 = streetNumber.isNotEmpty ? '$streetNumber $route' : route;

    return PlaceDetails(
      line1: line1.trim(),
      city: city,
      state: state,
      postalCode: postalCode,
    );
  }
}

class GooglePlacesService {
  GooglePlacesService._();
  static final GooglePlacesService instance = GooglePlacesService._();

  static const String apiKey = 'AIzaSyAjtmblGZLpiX77_oBYjEIZoXvFLoL0EFM';

  Future<List<PlacePrediction>> getAutocomplete(String input) async {
    if (input.trim().length < 3) return [];

    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=${Uri.encodeComponent(input)}&key=$apiKey&components=country:us',
      );
      debugPrint('🌍 [GooglePlaces] Requesting autocomplete for: "$input"');
      final response = await http.get(url);
      debugPrint('🌍 [GooglePlaces] Response status: ${response.statusCode}, body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final status = data['status'];
        if (status == 'OK') {
          final predictions = data['predictions'] as List? ?? [];
          return predictions.map((p) => PlacePrediction.fromJson(p)).toList();
        } else {
          debugPrint('⚠️ [GooglePlaces] API returned status: $status, error_message: ${data['error_message']}');
        }
      }
    } catch (e) {
      debugPrint('❌ [GooglePlaces] Error fetching autocomplete: $e');
    }
    return [];
  }

  Future<PlaceDetails?> getPlaceDetails(String placeId) async {
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&fields=address_component&key=$apiKey',
      );
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return PlaceDetails.fromJson(data);
      }
    } catch (e) {
      debugPrint('❌ [GooglePlaces] Error fetching place details: $e');
    }
    return null;
  }
}
