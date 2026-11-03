import 'dart:convert';

class Address {
  final String id; // uuid or timestamp string
  final String fullName;
  final String line1;
  final String? line2;
  final String city;
  final String state;
  final String postalCode;
  final bool isDefault;

  Address({
    required this.id,
    required this.fullName,
    required this.line1,
    this.line2,
    required this.city,
    required this.state,
    required this.postalCode,
    this.isDefault = false,
  });

  Address copyWith({
    String? id,
    String? fullName,
    String? line1,
    String? line2,
    String? city,
    String? state,
    String? postalCode,
    bool? isDefault,
  }) => Address(
    id: id ?? this.id,
    fullName: fullName ?? this.fullName,
    line1: line1 ?? this.line1,
    line2: line2 ?? this.line2,
    city: city ?? this.city,
    state: state ?? this.state,
    postalCode: postalCode ?? this.postalCode,
    isDefault: isDefault ?? this.isDefault,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'fullName': fullName,
    'line1': line1,
    'line2': line2,
    'city': city,
    'state': state,
    'postalCode': postalCode,
    'isDefault': isDefault,
  };

  static Address fromJson(Map<String, dynamic> json) => Address(
    id: json['id'] as String,
    fullName: json['fullName'] as String,
    line1: json['line1'] as String,
    line2: json['line2'] as String?,
    city: json['city'] as String,
    state: json['state'] as String,
    postalCode: json['postalCode'] as String,
    isDefault: json['isDefault'] == true,
  );

  static List<Address> decodeList(String raw) {
    if (raw.isEmpty) return [];
    final list = json.decode(raw) as List;
    return list
        .map((e) => Address.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static String encodeList(List<Address> list) =>
      json.encode(list.map((e) => e.toJson()).toList());
}

class AddressValidator {
  static String? validateName(String? v) {
    if (v == null || v.trim().isEmpty) return 'Name required';
    if (v.trim().length < 2) return 'Too short';
    return null;
  }

  static String? validateLine(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    return null;
  }

  static String? validateCity(String? v) {
    if (v == null || v.trim().isEmpty) return 'City required';
    return null;
  }

  static String? validateState(String? v) {
    if (v == null || v.trim().isEmpty) return 'State';
    if (v.trim().length < 2) return 'Use abbr';
    return null;
  }

  static String? validatePostal(String? v) {
    if (v == null || v.trim().isEmpty) return 'ZIP required';
    final r = RegExp(r'^[0-9]{5}(?:-[0-9]{4})?$');
    if (!r.hasMatch(v.trim())) return 'Invalid ZIP';
    return null;
  }
}
