import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rapidrun_shared/rapidrun_shared.dart';
import '../../models/product.dart';
import '../../services/favorites_cart_service.dart';
import '../../utils/product_title_sanitizer.dart';

class ProductBadgeMeta {
  final bool isNew;
  final bool isValue;
  final bool isPopular;
  final bool isPersonal;
  const ProductBadgeMeta({
    this.isNew = false,
    this.isValue = false,
    this.isPopular = false,
    this.isPersonal = false,
  });
}

class ProductCardV2 extends StatelessWidget {
  final Product product;
  final String? highlight;
  final VoidCallback? onTap;
  final ProductBadgeMeta? meta;
  final bool? isHorizontalLayout;
  final bool hidePrice;

  const ProductCardV2({
    super.key,
    required this.product,
    this.highlight,
    this.onTap,
    this.meta,
    this.isHorizontalLayout,
    this.hidePrice = false,
  });

  @override
  Widget build(BuildContext context) {
    final isHorizontal = isHorizontalLayout ?? false;
    final sanitized = ProductTitleSanitizer.process(
      rawTitle: product.name,
      rawBrand: product.brand,
      rawDescription: product.description,
    );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1B1B1B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.07),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: isHorizontal
            ? Row(
                children: [
                  _ProductFramedImage(
                    imageUrl: product.imageUrl,
                    badge: sanitized.primaryBadge,
                    width: 108,
                    height: 108,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: _ProductDetailsBlock(
                        product: product,
                        sanitized: sanitized,
                        hidePrice: hidePrice,
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Structured 55% frame for packshot
                  Expanded(
                    flex: 11,
                    child: _ProductFramedImage(
                      imageUrl: product.imageUrl,
                      badge: sanitized.primaryBadge,
                    ),
                  ),
                  // Structured 45% container for typography hierarchy
                  Expanded(
                    flex: 9,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                      child: _ProductDetailsBlock(
                        product: product,
                        sanitized: sanitized,
                        hidePrice: hidePrice,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _ProductFramedImage extends StatelessWidget {
  final String? imageUrl;
  final ProductBadgeSpec? badge;
  final double? width;
  final double? height;

  const _ProductFramedImage({
    this.imageUrl,
    this.badge,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(6),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Inset packshot charcoal canvas card
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A1E26),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(4),
            child: (imageUrl != null && imageUrl!.isNotEmpty)
                ? RapidNetworkImage(
                    imageUrl: imageUrl!,
                    width: double.infinity,
                    height: double.infinity,
                    borderRadius: 12,
                    fit: BoxFit.contain,
                  )
                : const Center(
                    child: Icon(
                      Icons.shopping_bag_outlined,
                      color: Colors.white24,
                      size: 32,
                    ),
                  ),
          ),
          // Micro-pill certification badge
          if (badge != null)
            Positioned(
              top: 6,
              left: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: badge!.backgroundColor.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: badge!.borderColor, width: 0.8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(badge!.icon, size: 9, color: badge!.textColor),
                    const SizedBox(width: 3.5),
                    Text(
                      badge!.label,
                      style: TextStyle(
                        color: badge!.textColor,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProductDetailsBlock extends StatelessWidget {
  final Product product;
  final SanitizedProductData sanitized;
  final bool hidePrice;

  const _ProductDetailsBlock({
    required this.product,
    required this.sanitized,
    this.hidePrice = false,
  });

  @override
  Widget build(BuildContext context) {
    final unitString = (product.unitShort ?? product.unit ?? '').trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Eyebrow Brand Label
            Text(
              sanitized.brandLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFE6B450),
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 2),
            // Hero Title
            Text(
              sanitized.heroTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
                height: 1.15,
              ),
            ),
            if (unitString.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                unitString,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
        if (!hidePrice && product.price != null)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '\$${product.price!.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      letterSpacing: -0.3,
                    ),
                  ),
                  if (product.msrp != null && product.msrp! > product.price!) ...[
                    const SizedBox(width: 4),
                    Text(
                      '\$${product.msrp!.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontWeight: FontWeight.w500,
                        fontSize: 11,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  ],
                ],
              ),
              _QuickAddCartPill(product: product),
            ],
          ),
      ],
    );
  }
}

class _QuickAddCartPill extends StatefulWidget {
  final Product product;
  const _QuickAddCartPill({required this.product});

  @override
  State<_QuickAddCartPill> createState() => _QuickAddCartPillState();
}

class _QuickAddCartPillState extends State<_QuickAddCartPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  Future<void> _onAdd() async {
    HapticFeedback.lightImpact();
    await _scaleController.forward();
    await _scaleController.reverse();
    await CartService.instance.addProduct(widget.product, 1);
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Material(
        color: const Color(0xFFE6B450),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: _onAdd,
          borderRadius: BorderRadius.circular(8),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            child: Icon(
              Icons.add_shopping_cart_rounded,
              color: Colors.black,
              size: 15,
            ),
          ),
        ),
      ),
    );
  }
}
