import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/favorites_cart_service.dart';
import '../services/product_catalog_service.dart';
import 'package:intl/intl.dart';
import '../services/firebase_service.dart';

/// A sticky glassmorphic persistent bar showing cart total + quick checkout CTA.
class MiniCartBar extends StatefulWidget {
  final VoidCallback onViewCart;
  final VoidCallback onCheckout;
  final bool dismissible;
  final VoidCallback? onDismissed;
  const MiniCartBar({
    super.key,
    required this.onViewCart,
    required this.onCheckout,
    this.dismissible = true,
    this.onDismissed,
  });

  @override
  State<MiniCartBar> createState() => _MiniCartBarState();
}

class _MiniCartBarState extends State<MiniCartBar> {
  final cart = CartService.instance;
  bool _loadingCatalog = false;
  double _subtotal = 0;
  late final NumberFormat _currency = NumberFormat.simpleCurrency();

  @override
  void initState() {
    super.initState();
    cart.addListener(_recompute);
    _ensureCatalog();
    _recompute();
  }

  @override
  void dispose() {
    cart.removeListener(_recompute);
    super.dispose();
  }

  Future<void> _ensureCatalog() async {
    if (_loadingCatalog) return;
    _loadingCatalog = true;
    await ProductCatalogService.instance.ensureLoaded();
    if (!mounted) return;
    _loadingCatalog = false;
    _recompute();
  }

  void _recompute() {
    double total = 0;
    cart.items.forEach((id, qty) {
      final p = ProductCatalogService.instance.get(id);
      final price = (p?.price != null && p!.price! > 0) ? p.price! : 9.99;
      total += price * qty;
    });
    setState(() => _subtotal = total);
  }

  @override
  Widget build(BuildContext context) {
    final totalItems = cart.totalItems;
    final isAuthed = FirebaseService.user != null;

    if (totalItems == 0) return const SizedBox.shrink();

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E).withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: const Color(0xFFFFC107).withValues(alpha: 0.45),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Gold Item Counter Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFC107).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFFFC107).withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.shopping_bag_outlined,
                          color: Color(0xFFFFC107),
                          size: 16,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '$totalItems',
                          style: const TextStyle(
                            color: Color(0xFFFFC107),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Running Subtotal
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Estimated Subtotal',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 10,
                            letterSpacing: 0.3,
                          ),
                        ),
                        Text(
                          _loadingCatalog
                              ? 'Calculating…'
                              : _currency.format(_subtotal),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // View Cart CTA
                  TextButton(
                    onPressed: widget.onViewCart,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white70,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: const Text('View Cart'),
                  ),
                  const SizedBox(width: 4),
                  // Checkout Primary Gold Button
                  ElevatedButton(
                    onPressed: widget.onCheckout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFC107),
                      foregroundColor: Colors.black,
                      elevation: 2,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      isAuthed ? 'Checkout' : 'Sign In',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
