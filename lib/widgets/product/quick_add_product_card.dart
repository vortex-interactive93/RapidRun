import 'package:flutter/material.dart';
import '../../models/product.dart';
import '../../services/favorites_cart_service.dart';
import 'package:flutter/services.dart';

/// Inline quick add card for simple products (no modifiers / bundles) used in
/// category grids like Panda appetizers. Keeps visual consistency with
/// ProductCardV2 but adds quantity stepper + add button inline to avoid
/// navigating to product detail.
class QuickAddProductCard extends StatefulWidget {
  final Product product;
  final bool isHorizontal;
  final bool selected; // whether this card is "active" (expanded)
  final VoidCallback? onSelect; // request selection
  final void Function(int qty)? onQuantityChanged; // bubble qty when selected
  final Future<void> Function(int qty)? onAdd; // optional override for add
  const QuickAddProductCard({
    super.key,
    required this.product,
    this.isHorizontal = false,
    this.selected = true,
    this.onSelect,
    this.onQuantityChanged,
    this.onAdd,
  });

  @override
  State<QuickAddProductCard> createState() => _QuickAddProductCardState();
}

class _QuickAddProductCardState extends State<QuickAddProductCard>
    with SingleTickerProviderStateMixin {
  int _qty =
      1; // local desired quantity before adding (only used when selected)
  bool _adding = false;
  late AnimationController _expandC;
  late Animation<double> _expand;

  @override
  void initState() {
    super.initState();
    _expandC = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      value: widget.selected ? 1 : 0,
    );
    _expand = CurvedAnimation(parent: _expandC, curve: Curves.easeInOut);
  }

  @override
  void didUpdateWidget(covariant QuickAddProductCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) {
      if (widget.selected) {
        _expandC.forward();
      } else {
        _expandC.reverse();
      }
    }
  }

  @override
  void dispose() {
    _expandC.dispose();
    super.dispose();
  }

  void _inc() {
    setState(() => _qty++);
    widget.onQuantityChanged?.call(_qty);
  }

  void _dec() {
    setState(() {
      if (_qty > 1) _qty--;
    });
    widget.onQuantityChanged?.call(_qty);
  }

  Future<void> _addToCart() async {
    if (_adding) return;
    final price = widget.product.price;
    if (price == null) return; // defensive
    setState(() => _adding = true);
    if (widget.onAdd != null) {
      await widget.onAdd!(_qty);
    } else {
      await CartService.instance.add(widget.product.id, _qty);
    }
    if (!mounted) return;
    // Light haptic (ignore errors on unsupported platforms)
    try {
      HapticFeedback.selectionClick();
    } catch (_) {}
    setState(() {
      _adding = false;
      _qty = 1; // reset after add for quick repeat adds
    });
    // Lightweight feedback; rely on theme gold color.
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1500),
        content: Text(
          'Added ${widget.product.name} x$_qty',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final price = p.price;
    final isH = widget.isHorizontal;
    final gold = const Color(0xFFE6B450);
    // We'll animate only the border color (not width) to prevent layout shift
    // that caused sibling cards to "shake". Keep constant width.
    final bool isSelected = widget.selected;
    final collapsed = !widget.selected;
    // NOTE: This Column previously used Spacer/Expanded which caused
    // RenderFlex exceptions inside the vertical ListView (unbounded height).
    // We now shrink-wrap the content with mainAxisSize.min and rely on
    // intrinsic sizing instead of flex.
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          p.name,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (price != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '\$' + price.toStringAsFixed(2),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: gold,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        if (!collapsed) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              _QtyButton(
                icon: Icons.remove_circle_outline,
                onTap: _qty > 1 && !_adding ? _dec : null,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  '$_qty',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              _QtyButton(
                icon: Icons.add_circle_outline,
                onTap: !_adding ? _inc : null,
              ),
              const Spacer(),
              SizedBox(
                height: 34,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: gold,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: (_adding || price == null) ? null : _addToCart,
                  child: _adding
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            valueColor: AlwaysStoppedAnimation(gold.darken()),
                          ),
                        )
                      : const Text('Add'),
                ),
              ),
            ],
          ),
        ],
      ],
    );

    final img = p.imageUrl;
    final imageWidget = ClipRRect(
      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      child: img != null && img.isNotEmpty
          ? Image.network(
              img,
              height: isH ? 96 : 108,
              width: isH ? 96 : double.infinity,
              fit: BoxFit.cover,
            )
          : Container(
              height: isH ? 96 : 108,
              color: Colors.grey[200],
              child: Icon(Icons.image, size: 40, color: Colors.grey[400]),
            ),
    );

    final body = isH
        ? Row(
            children: [
              SizedBox(width: 96, child: imageWidget),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: content,
                ),
              ),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              imageWidget,
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: content,
              ),
            ],
          );

    Widget card = AnimatedBuilder(
      animation: _expand,
      builder: (context, child) {
        final borderColor = isSelected
            ? gold.withOpacity(0.95 * _expand.value)
            : Colors.transparent;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            // Dark inner surface consistent with rest of app (previous white removed)
            color: const Color(0xFF202020),
            border: Border.all(color: borderColor, width: 1.1),
          ),
          clipBehavior: Clip.antiAlias,
          child: child,
        );
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.selected ? null : widget.onSelect,
          child: body,
        ),
      ),
    );

    // Dark theme adaptation (original cards were dark). We'll wrap with a Card using theme.
    // Outer Card kept subtle; remove inner elevation change to reduce jank.
    return Card(
      elevation: isSelected ? 2 : 0,
      color: const Color(0xFF181818),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: card,
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _QtyButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Icon(
          icon,
          size: 22,
          color: disabled ? Colors.black26 : const Color(0xFFE6B450),
        ),
      ),
    );
  }
}

extension _ColorShade on Color {
  Color darken([double amount = .2]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }
}
