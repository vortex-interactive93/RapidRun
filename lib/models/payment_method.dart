// Payment method model
import 'dart:convert';

enum PaymentMethodType { card }

class PaymentMethodSummary {
  final String id;
  final PaymentMethodType type;
  final String brand; // Visa, MasterCard, etc.
  final String last4;
  final int expMonth;
  final int expYear;
  final bool isDefault;
  PaymentMethodSummary({
    required this.id,
    required this.type,
    required this.brand,
    required this.last4,
    required this.expMonth,
    required this.expYear,
    this.isDefault = false,
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'brand': brand,
    'last4': last4,
    'expMonth': expMonth,
    'expYear': expYear,
    'isDefault': isDefault,
  };
  static PaymentMethodSummary fromJson(Map<String, dynamic> json) =>
      PaymentMethodSummary(
        id: json['id'] as String,
        type: PaymentMethodType.values.firstWhere(
          (e) => e.name == json['type'],
        ),
        brand: json['brand'] as String,
        last4: json['last4'] as String,
        expMonth: json['expMonth'] as int,
        expYear: json['expYear'] as int,
        isDefault: json['isDefault'] == true,
      );
  PaymentMethodSummary copyWith({
    String? id,
    PaymentMethodType? type,
    String? brand,
    String? last4,
    int? expMonth,
    int? expYear,
    bool? isDefault,
  }) => PaymentMethodSummary(
    id: id ?? this.id,
    type: type ?? this.type,
    brand: brand ?? this.brand,
    last4: last4 ?? this.last4,
    expMonth: expMonth ?? this.expMonth,
    expYear: expYear ?? this.expYear,
    isDefault: isDefault ?? this.isDefault,
  );
  static List<PaymentMethodSummary> decodeList(String raw) {
    if (raw.isEmpty) return [];
    final list = json.decode(raw) as List;
    return list
        .map((e) => PaymentMethodSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static String encodeList(List<PaymentMethodSummary> list) =>
      json.encode(list.map((e) => e.toJson()).toList());
}

class CardValidator {
  static String? validateNumber(String? value) {
    final v = value?.replaceAll(RegExp(r'\s+'), '') ?? '';
    if (v.isEmpty) return 'Card number required';
    if (v.length < 13 || v.length > 19) return 'Invalid length';
    if (!_luhnValid(v)) return 'Invalid card number';
    return null;
  }

  static String? validateExpiry(String? value) {
    if (value == null || value.trim().isEmpty) return 'Expiry required';
    final parts = value.split('/');
    if (parts.length != 2) return 'MM/YY';
    final mm = int.tryParse(parts[0]);
    final yy = int.tryParse(parts[1]);
    if (mm == null || yy == null) return 'MM/YY';
    if (mm < 1 || mm > 12) return 'Invalid month';
    final now = DateTime.now();
    final four = 2000 + yy;
    if (four < now.year || (four == now.year && mm < now.month))
      return 'Expired';
    return null;
  }

  static String? validateCvc(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'CVC required';
    if (v.length < 3 || v.length > 4) return '3-4 digits';
    if (!RegExp(r'^\d{3,4}$').hasMatch(v)) return 'Digits only';
    return null;
  }

  static bool _luhnValid(String number) {
    int sum = 0;
    bool alt = false;
    for (int i = number.length - 1; i >= 0; i--) {
      int n = int.parse(number[i]);
      if (alt) {
        n *= 2;
        if (n > 9) n -= 9;
      }
      sum += n;
      alt = !alt;
    }
    return sum % 10 == 0;
  }
}
