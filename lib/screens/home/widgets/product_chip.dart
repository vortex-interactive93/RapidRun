import 'package:flutter/material.dart';
import '../../../models/product.dart';
import '../../../services/favorites_cart_service.dart';
import '../../../utils/cart_flyer.dart';
import '../../../widgets/reactive_cart_badge.dart';
import 'package:flutter/services.dart';

class ProductChip extends StatelessWidget {
  final Product product;
  final VoidCallback? onTap;
  final String? highlight; // case-insensitive substring to highlight in name
  const ProductChip({
    super.key,
    required this.product,
    this.onTap,
    this.highlight,
  });

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    final isMulti = (product.subCategory ?? '').toLowerCase() == 'multipacks';
    return Container(
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.25),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Main content
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Center(
                    child: Hero(
                      // Include store and id plus widget hashCode to ensure uniqueness when same product repeats in a single list
                      tag:
                          'product:${product.store}:${product.id}_${product.hashCode}',
                      child: Icon(Icons.inventory_2, size: 42, color: gold),
                    ),
                  ),
                ),
                _buildName(),
                const SizedBox(height: 4),
                if (product.store != null)
                  Text(
                    product.store!,
                    style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                  ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: _QuickAddButton(productId: product.id, gold: gold),
                ),
              ],
            ),
            if (isMulti)
              Positioned(
                top: -4,
                left: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [gold.withValues(alpha: 0.9), gold],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(14),
                      bottomRight: Radius.circular(12),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Text(
                    'MULTI',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildName() {
    final h = highlight;
    final name = product.name;
    if (h == null || h.trim().isEmpty) {
      return Text(
        name,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      );
    }
    final lowerName = name.toLowerCase();
    final lowerH = h.toLowerCase();
    final spans = <TextSpan>[];
    int start = 0;
    while (true) {
      final idx = lowerName.indexOf(lowerH, start);
      if (idx < 0) {
        spans.add(TextSpan(text: name.substring(start)));
        break;
      }
      if (idx > start) {
        spans.add(TextSpan(text: name.substring(start, idx)));
      }
      spans.add(
        TextSpan(
          text: name.substring(idx, idx + lowerH.length),
          style: const TextStyle(
            backgroundColor: Color(0x66FFC107),
            fontWeight: FontWeight.w700,
          ),
        ),
      );
      start = idx + lowerH.length;
      if (start >= name.length) break;
    }
    return RichText(
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        children: spans,
      ),
    );
  }
}

class _QuickAddButton extends StatefulWidget {
  final String productId;
  final Color gold;
  const _QuickAddButton({required this.productId, required this.gold});

  @override
  State<_QuickAddButton> createState() => _QuickAddButtonState();
}

class _QuickAddButtonState extends State<_QuickAddButton>
    with SingleTickerProviderStateMixin {
  bool _adding = false;
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    if (_adding) return;
    setState(() => _adding = true);
    await CartService.instance.add(widget.productId, 1);
    if (mounted) {
      _controller
        ..reset()
        ..forward();
      // Fire off a fly-to-cart animation.
      CartFlyer.instance.flyFrom(
        context,
        color: widget.gold,
        onComplete: () {
          try {
            HapticFeedback.lightImpact();
          } catch (_) {}
          CartBadgePulse.pulse();
        },
      );
      try {
        HapticFeedback.selectionClick();
      } catch (_) {}
      setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween(
        begin: 1.0,
        end: 1.3,
      ).chain(CurveTween(curve: Curves.easeOutBack)).animate(_controller),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: _add,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: widget.gold.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.gold.withValues(alpha: 0.4),
              width: 1,
            ),
          ),
          child: _adding
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(Icons.add_shopping_cart, size: 16, color: widget.gold),
        ),
      ),
    );
  }
}
