import 'package:flutter/material.dart';

/// Central lightweight store branding configuration.
/// Keeps UI specific colors / gradients decoupled from feature widgets.
class StoreBranding {
  const StoreBranding({required this.primary, required this.gradient});
  final Color primary;
  final Gradient gradient;

  static StoreBranding of(String? store) {
    final key = (store ?? '').toLowerCase().replaceAll(' ', '_');
    switch (key) {
      case 'taco_bell':
        return StoreBranding(
          primary: const Color(0xFF702082), // Taco Bell purple (approx)
          gradient: const LinearGradient(
            colors: [Color(0xFF3E0E46), Color(0xFF702082)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        );
      case 'panda_express':
        return StoreBranding(
          primary: const Color(0xFFD32F2F), // Panda Express red (approx)
          gradient: const LinearGradient(
            colors: [Color(0xFF6A1B1A), Color(0xFFD32F2F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        );
      default:
        return StoreBranding(
          primary: Colors.amber,
          gradient: LinearGradient(
            colors: [Colors.grey.shade900, Colors.grey.shade800],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        );
    }
  }
}

Color storeAccent(String? store) => StoreBranding.of(store).primary;
