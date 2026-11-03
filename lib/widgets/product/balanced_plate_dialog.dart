import 'dart:ui';
import 'package:flutter/material.dart';
import '../../models/product.dart';
import '../../services/favorites_cart_service.dart';

Future<void> showBalancedPlateDialog(
  BuildContext context,
  Product product,
) async {
  await showGeneralDialog(
    context: context,
    barrierLabel: 'Balanced Plate',
    barrierDismissible: true,
    barrierColor: Colors.black.withOpacity(0.45),
    pageBuilder: (_, __, ___) => const SizedBox.shrink(),
    transitionBuilder: (ctx, anim, __, ___) {
      final curved = CurvedAnimation(
        parent: anim,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return Stack(
        children: [
          // Background blur
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: 10 * anim.value,
                sigmaY: 10 * anim.value,
              ),
              child: const SizedBox.shrink(),
            ),
          ),
          Center(
            child: Opacity(
              opacity: curved.value,
              child: _BalancedPlateSheet(product: product),
            ),
          ),
        ],
      );
    },
    transitionDuration: const Duration(milliseconds: 240),
  );
}

class _BalancedPlateSheet extends StatefulWidget {
  final Product product;
  const _BalancedPlateSheet({required this.product});
  @override
  State<_BalancedPlateSheet> createState() => _BalancedPlateSheetState();
}

class _BalancedPlateSheetState extends State<_BalancedPlateSheet> {
  int _qty = 1;
  bool _adding = false;

  static const Map<String, String> _composition = {
    'panda_express_balanced_double_protein_plate':
        '2X Grilled Teriyaki Chicken with Half White Steamed Rice + Half Super Greens',
    'panda_express_balanced_harmonious_macros_plate':
        'Grilled Teriyaki Chicken and Broccoli Beef with Super Greens',
    'panda_express_balanced_bold_flavorful_plate':
        'Kung Pao Chicken and Black Pepper Sirloin Steak with Super Greens',
    'panda_express_balanced_power_packed_plate':
        'Black Pepper Sirloin Steak and Broccoli Beef with Super Greens',
    'panda_express_balanced_protein_fiber_plate':
        'String Bean Chicken Breast and Kung Pao Chicken with Super Greens',
  };

  String _calorieLabel(Product p) {
    // Product model lacks explicit min/max calorie fields for these plates.
    // Attempt to extract a range like "430–1640 Cal" from description text.
    final desc = p.description ?? '';
    final reg = RegExp(
      r'(\d{2,4})\s*[–-]\s*(\d{2,4})\s*Cal',
      caseSensitive: false,
    );
    final singleReg = RegExp(r'(\d{2,4})\s*Cal', caseSensitive: false);
    final m = reg.firstMatch(desc);
    if (m != null) {
      return '${m.group(1)}–${m.group(2)} Cal';
    }
    final s = singleReg.firstMatch(desc);
    if (s != null) return '${s.group(1)} Cal';
    return '';
  }

  Future<void> _add() async {
    if (_adding) return;
    setState(() => _adding = true);
    await CartService.instance.add(widget.product.id, _qty);
    if (!mounted) return;
    setState(() => _adding = false);
    Navigator.of(context).maybePop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1500),
        content: Text('Added ${widget.product.name} x$_qty'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final price = p.price ?? 0;
    final gold = const Color(0xFFE6B450);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Material(
        color: const Color(0xFF181818),
        elevation: 10,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      p.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio:
                      5 / 3.4, // generous landscape crop similar to reference
                  child: p.imageUrl != null
                      ? Image.network(p.imageUrl!, fit: BoxFit.cover)
                      : Container(
                          color: Colors.grey[800],
                          child: const Icon(
                            Icons.image,
                            size: 80,
                            color: Colors.white24,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                '\$' + price.toStringAsFixed(2),
                style: TextStyle(
                  color: gold,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: .3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _calorieLabel(p),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 14),
              if (p.description != null && p.description!.isNotEmpty)
                Text(
                  p.description!.replaceAll('(Base + 2 Entrées)', '').trim(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              if (_composition[p.id] != null) ...[
                const SizedBox(height: 10),
                Text(
                  _composition[p.id]!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 13,
                    height: 1.32,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _QtyButton(
                    icon: Icons.remove,
                    enabled: _qty > 1 && !_adding,
                    onTap: () => setState(() => _qty--),
                  ),
                  const SizedBox(width: 18),
                  Text(
                    '$_qty',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 18),
                  _QtyButton(
                    icon: Icons.add,
                    enabled: !_adding,
                    onTap: () => setState(() => _qty++),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: gold,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _adding ? null : _add,
                  child: _adding
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        )
                      : const Text('ADD TO ORDER'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;
  const _QtyButton({
    required this.icon,
    required this.onTap,
    required this.enabled,
  });
  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(40),
      onTap: enabled ? onTap : null,
      child: Container(
        decoration: BoxDecoration(
          color: enabled
              ? const Color(0xFF242424)
              : const Color(0xFF242424).withOpacity(.5),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24, width: 1),
        ),
        padding: const EdgeInsets.all(10),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}
