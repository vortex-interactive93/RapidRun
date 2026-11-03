import 'package:flutter/material.dart';
import '../../../services/firebase_service.dart';
import '../../../services/favorites_cart_service.dart';
import '../../../models/product.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Phase A header: greeting (left), centered logo placeholder, cart icon (right),
/// and a search pill underneath. Drawer + legacy AppBar removed.
class HomeHeader extends StatelessWidget {
  final VoidCallback onCartTap;
  final VoidCallback onSearchTap;
  final VoidCallback? onAddressTap;
  final String? address; // pre-fetched address (may be null while loading)
  final EdgeInsets padding;
  const HomeHeader({
    super.key,
    required this.onCartTap,
    required this.onSearchTap,
    this.onAddressTap,
    this.address,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  });

  String _greetingName() {
    final user = FirebaseService.user;
    if (user == null) return 'there';
    final name = (user.displayName ?? user.email ?? '').trim();
    if (name.isEmpty) return 'there';
    final first = name.split(RegExp(r'\s+|@')).first;
    if (first.isEmpty) return 'there';
    return first[0].toUpperCase() + first.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final cart = CartService.instance;
    final products = {
      for (final p in ProductRepository.sampleProducts) p.id: p,
    };
    double subtotal = 0;
    cart.items.forEach((id, qty) {
      final price = products[id]?.price ?? 0;
      subtotal += price * qty;
    });
    String subtotalStr = subtotal == 0
        ? ''
        : '\$' + subtotal.toStringAsFixed(subtotal < 100 ? 2 : 0);
    final top = MediaQuery.of(context).padding.top; // Safe area
    final primary = const Color(0xFF181818); // existing dark header base
    // Removed unused 'gold' color constant (was not applied in UI).
    return Container(
      decoration: BoxDecoration(
        color: primary,
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      padding: EdgeInsets.only(top: top) + padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height:
                52, // increased to allow larger logo & comfortable tap targets
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    'Hi, ${_greetingName()}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Center logo mark (SVG)
                Expanded(
                  child: Center(
                    child: SvgPicture.asset(
                      'assets/branding/logo_mark.svg',
                      height: 100, // enlarged logo mark
                      semanticsLabel: 'RapidRun',
                    ),
                  ),
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: AnimatedBuilder(
                      animation: cart,
                      builder: (context, _) {
                        final count = cart.totalItems;
                        return InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: onCartTap,
                          child: SizedBox(
                            width: 56,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                SizedBox(
                                  height: 28,
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Align(
                                        alignment: Alignment.center,
                                        child: Icon(
                                          Icons.shopping_cart_outlined,
                                          color: Colors.white,
                                          size: 22,
                                        ),
                                      ),
                                      if (count > 0)
                                        Positioned(
                                          top: -2,
                                          right: -2,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 5,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.redAccent,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            constraints: const BoxConstraints(
                                              minWidth: 20,
                                            ),
                                            child: Text(
                                              count > 99 ? '99+' : '$count',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                if (subtotalStr.isNotEmpty)
                                  Text(
                                    subtotalStr,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SearchPill(onTap: onSearchTap),
          if (address != null) ...[
            const SizedBox(height: 10),
            _AddressRow(text: address!, onTap: onAddressTap),
          ],
        ],
      ),
    );
  }
}

class _SearchPill extends StatelessWidget {
  final VoidCallback onTap;
  const _SearchPill({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(28),
      onTap: onTap,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFF222222),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFF2e2e2e)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            const Icon(Icons.search, color: Colors.white70, size: 22),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Search RapidRun',
                style: TextStyle(color: Colors.white54, fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF2d2d2d),
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.all(6),
              child: const Icon(
                Icons.qr_code_scanner,
                color: Colors.white70,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddressRow extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  const _AddressRow({required this.text, this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF202020),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF2a2a2a)),
        ),
        child: Row(
          children: [
            const Icon(Icons.local_shipping, size: 16, color: Colors.white70),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down,
              size: 18,
              color: Colors.white54,
            ),
          ],
        ),
      ),
    );
  }
}

/// Helper to present an address edit sheet and persist to Firestore user doc.
Future<void> showEditAddressSheet(BuildContext context) async {
  final user = FirebaseService.user;
  if (user == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sign in to set delivery address')),
    );
    return;
  }
  final doc = FirebaseFirestore.instance.collection('users').doc(user.uid);
  String initial = '';
  try {
    final snap = await doc.get();
    initial = (snap.data()?['deliveryAddress'] ?? '').toString();
  } catch (_) {}
  final controller = TextEditingController(text: initial);
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF181818),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Delivery Address',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 2,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Enter address',
                hintStyle: TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Color(0xFF222222),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2a2a2a),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      final val = controller.text.trim();
                      try {
                        await doc.set({
                          'deliveryAddress': val,
                        }, SetOptions(merge: true));
                        Navigator.pop(ctx, true);
                      } catch (e) {
                        ScaffoldMessenger.of(
                          ctx,
                        ).showSnackBar(SnackBar(content: Text('Failed: $e')));
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFe6b450),
                      foregroundColor: Colors.black,
                    ),
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
  if (saved == true) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Address updated')));
  }
}
