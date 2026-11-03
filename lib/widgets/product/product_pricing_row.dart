// File: lib/widgets/product/product_pricing_row.dart

import 'package:flutter/material.dart';

class ProductPricingRow extends StatelessWidget {
  final double currentPrice;
  final double? originalPrice;
  final String? discountLabel;
  final String? unitPriceDetails;

  const ProductPricingRow({
    super.key,
    required this.currentPrice,
    this.originalPrice,
    this.discountLabel,
    this.unitPriceDetails,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          spacing: 8.0,
          runSpacing: 4.0,
          children: [
            // Left Group: Price & Discount Badges
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '\$${currentPrice.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Color(0xFFFFC107), // RapidRun Gold
                    fontSize: 26.0,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                if (originalPrice != null && originalPrice! > currentPrice) ...[
                  const SizedBox(width: 8.0),
                  Text(
                    '\$${originalPrice!.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 15.0,
                      decoration: TextDecoration.lineThrough,
                      decorationColor: Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                ],
                if (discountLabel != null) ...[
                  const SizedBox(width: 8.0),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD32F2F).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4.0),
                      border: Border.all(
                        color: const Color(0xFFD32F2F).withValues(alpha: 0.6),
                        width: 1.0,
                      ),
                    ),
                    child: Text(
                      discountLabel!,
                      style: const TextStyle(
                        color: Color(0xFFFF5252),
                        fontSize: 11.0,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ],
            ),

            // Right Group: Unit Measurement with Ellipsis Protection
            if (unitPriceDetails != null)
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: constraints.maxWidth * 0.45,
                ),
                child: Text(
                  unitPriceDetails!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 13.0,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
