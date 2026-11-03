import 'package:flutter/material.dart';

enum CardBrand { visa, mastercard, amex, discover, unknown }

class CardBrandStyle {
  final Color color;
  final Gradient? gradient;
  const CardBrandStyle({required this.color, this.gradient});
}

// Brand primary colors / gradients (simplified palette)
const Map<CardBrand, CardBrandStyle> _brandStyles = {
  CardBrand.visa: CardBrandStyle(color: Color(0xFF1A1F71)),
  CardBrand.mastercard: CardBrandStyle(
    color: Color(0xFFFF5F00),
    gradient: LinearGradient(
      colors: [Color(0xFFEB001B), Color(0xFFF79E1B)],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    ),
  ),
  CardBrand.amex: CardBrandStyle(color: Color(0xFF2E77BC)),
  CardBrand.discover: CardBrandStyle(color: Color(0xFFFF6000)),
  CardBrand.unknown: CardBrandStyle(color: Color(0xFF555555)),
};

CardBrandStyle cardBrandStyle(CardBrand b) =>
    _brandStyles[b] ?? const CardBrandStyle(color: Color(0xFF555555));

CardBrand detectCardBrand(String raw) {
  final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return CardBrand.unknown;
  if (digits.startsWith('4')) return CardBrand.visa;
  if (digits.startsWith('34') || digits.startsWith('37')) return CardBrand.amex;
  final first2 = digits.length >= 2
      ? int.tryParse(digits.substring(0, 2))
      : null;
  final first4 = digits.length >= 4
      ? int.tryParse(digits.substring(0, 4))
      : null;
  if (first2 != null && first2 >= 51 && first2 <= 55)
    return CardBrand.mastercard;
  if (first4 != null && first4 >= 2221 && first4 <= 2720)
    return CardBrand.mastercard;
  if (digits.startsWith('6011') || digits.startsWith('65'))
    return CardBrand.discover; // subset
  return CardBrand.unknown;
}

String cardBrandLabel(CardBrand brand) {
  switch (brand) {
    case CardBrand.visa:
      return 'Visa';
    case CardBrand.mastercard:
      return 'Mastercard';
    case CardBrand.amex:
      return 'Amex';
    case CardBrand.discover:
      return 'Discover';
    case CardBrand.unknown:
      return '';
  }
}
