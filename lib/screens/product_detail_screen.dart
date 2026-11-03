// File: lib/screens/product_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rapidrun_shared/rapidrun_shared.dart';
import '../models/product.dart';
import '../services/favorites_cart_service.dart';
import '../services/product_catalog_service.dart';
import '../widgets/product/luxury_accordions.dart';
import '../widgets/reactive_cart_badge.dart';
import '../widgets/catalog/independent_retailer_disclaimer.dart';

class ProductDetailScreen extends StatefulWidget {
  final String id;
  final String name;
  final String? brand;
  final String? imageUrl;
  final String description;
  final double? price;
  final String? unit;
  final String? unitShort;
  final bool bundleContext;
  final String? wrapperId;
  final Map<String, dynamic>? nutritionRaw;

  const ProductDetailScreen({
    super.key,
    required this.id,
    required this.name,
    this.brand,
    this.imageUrl,
    required this.description,
    this.price,
    this.unit,
    this.unitShort,
    this.nutritionRaw,
    this.bundleContext = false,
    this.wrapperId,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final ScrollController _scrollController = ScrollController();
  int _qty = 1;
  Product? _productData;

  @override
  void initState() {
    super.initState();
    _loadProduct();
  }

  Future<void> _loadProduct() async {
    await ProductCatalogService.instance.ensureLoaded();
    final svc = ProductCatalogService.instance;
    if (mounted) {
      setState(() => _productData = svc.get(widget.id));
    }
  }

  Product? _product() {
    if (_productData != null) return _productData;
    final svc = ProductCatalogService.instance;
    if (!svc.isLoaded) return null;
    _productData = svc.get(widget.id);
    return _productData;
  }

  (String scent, String form) _splitTitle(String rawTitle, String? subCat) {
    final sub = (subCat != null && subCat.isNotEmpty) ? subCat : 'Body Care';
    String scent = rawTitle.replaceAll(RegExp(RegExp.escape(sub), caseSensitive: false), '').trim();
    scent = scent.replaceAll(RegExp(r'\s+(Body Lotion|Ultimate Hydration Body Cream|Body Cream|Body Butter|Hand Cream|Body Wash|Shower Gel|Fine Fragrance Mist|Perfume Mist|Diamond Shimmer Mist|Deodorizing Body Spray|Essential Oil Mist|Cologne|Mini Eau de Parfum|Body Spray|Body Oil)$', caseSensitive: false), '').trim();
    return (scent.isEmpty ? rawTitle : scent, sub);
  }

  String _perUnitPriceStr(double price, String? uStr) {
    if (uStr == null || uStr.isEmpty) return '';
    final match = RegExp(r'(\d+(?:\.\d+)?)\s*fl\s*oz', caseSensitive: false).firstMatch(uStr);
    if (match != null) {
      final oz = double.tryParse(match.group(1)!);
      if (oz != null && oz > 0) {
        return '\$${(price / oz).toStringAsFixed(2)} per fl oz';
      }
    }
    return '\$${(price / 8.0).toStringAsFixed(2)} per fl oz';
  }

  @override
  Widget build(BuildContext context) {
    final favSvc = FavoritesService.instance;
    final isFav = favSvc.isFavorite(widget.id);
    const gold = Color(0xFFE6B450);
    const card = Color(0xFF181818);
    const bg = Color(0xFF121212);

    final p = _product();
    final price = widget.price ?? p?.price ?? 0.0;
    final msrp = p?.msrp ?? (price > 0 ? (price < 10 ? 18.95 : price * 1.25) : 18.95);
    final rating = p?.rating ?? 4.8;
    final (scentTitle, formSubtitle) = _splitTitle(widget.name, p?.subCategory);
    final isFragrance = p?.fragranceProfile != null || (p?.store == 'bath_and_body_works');

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: card,
        elevation: 0,
        title: Text(
          scentTitle,
          style: const TextStyle(
            color: gold,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: isFav ? 'Remove favorite' : 'Add to favorites',
            icon: Icon(
              isFav ? Icons.favorite : Icons.favorite_border,
              color: gold,
            ),
            onPressed: () {
              favSvc.toggle(widget.id);
              setState(() {});
            },
          ),
          ReactiveCartBadge(
            onPressed: () => Navigator.pushNamed(context, '/cart'),
            iconColor: gold,
          ),
        ],
      ),
      body: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
        children: [
          // 1. Packshot Charcoal Canvas Showcase Container
          if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty) ...[
            Container(
              height: 290,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1E26), // Charcoal Canvas (No White Box)
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.55),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: RapidNetworkImage(
                    imageUrl: widget.imageUrl!,
                    width: double.infinity,
                    height: double.infinity,
                    borderRadius: 20,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
          ],

          // 2. Social Proof & Community Rating Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F1E36),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.4)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.local_fire_department_rounded, color: Color(0xFF38BDF8), size: 13),
                    SizedBox(width: 4),
                    Text(
                      'In 12,161 bags',
                      style: TextStyle(
                        color: Color(0xFF38BDF8),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  const Icon(Icons.star_rounded, color: gold, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    rating.toStringAsFixed(1),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    '(6,981)',
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 3. Scent Name + Form Subtitle
          Text(
            scentTitle,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            formSubtitle,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.white54,
            ),
          ),
          const SizedBox(height: 14),

          // 4. Price & Markdown Matrix
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '\$${price.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: gold,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              if (msrp > price) ...[
                const SizedBox(width: 10),
                Text(
                  '\$${msrp.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 16,
                    decoration: TextDecoration.lineThrough,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE53935).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFE53935)),
                  ),
                  child: Text(
                    '-${(((msrp - price) / msrp) * 100).round()}% OFF',
                    style: const TextStyle(
                      color: Color(0xFFEF5350),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              Text(
                p?.unit ?? widget.unit ?? '8 fl oz / 236 mL',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _perUnitPriceStr(price, p?.unit ?? widget.unit),
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ),
          const SizedBox(height: 16),

          // 5. Accordion Drawers
          if (p != null && isFragrance)
            LuxuryProductAccordions(product: p)
          else if (p != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF181818),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'About this item',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    p.description ?? widget.description,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13.5,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          const IndependentRetailerDisclaimer(),
          const SizedBox(height: 80),
        ],
      ),

      // Sticky Bottom Add-to-Cart Bar with System Navigation Inset Safety
      bottomSheet: Builder(
        builder: (context) {
          final bottomInset = MediaQuery.of(context).padding.bottom;
          return Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, bottomInset > 0 ? bottomInset + 12 : 24),
            decoration: BoxDecoration(
              color: const Color(0xFF181818),
              border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF222222),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: gold.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: _qty > 1 ? () => setState(() => _qty--) : null,
                          icon: const Icon(Icons.remove, size: 18),
                          color: gold,
                        ),
                        Text(
                          '$_qty',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: () => setState(() => _qty++),
                          icon: const Icon(Icons.add, size: 18),
                          color: gold,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: gold,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () async {
                        HapticFeedback.lightImpact();
                        await CartService.instance.add(widget.id, _qty);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: gold,
                              content: Text(
                                'Added $_qty × $scentTitle to cart',
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.add_shopping_cart_rounded, color: Colors.black),
                      label: Text(
                        'Add (\$${(price * _qty).toStringAsFixed(2)})',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
