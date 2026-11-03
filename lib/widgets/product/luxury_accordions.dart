// File: lib/widgets/product/luxury_accordions.dart

import 'package:flutter/material.dart';
import '../../models/product.dart';

class LuxuryProductAccordions extends StatelessWidget {
  final Product product;

  const LuxuryProductAccordions({super.key, required this.product});

  List<String> _getOverviewBullets(Product product) {
    final sub = (product.subCategory ?? '').toLowerCase();
    final name = product.name.toLowerCase();
    final category = (product.category ?? '').toLowerCase();
    final combined = '$category $sub $name';

    if (combined.contains('candle')) {
      return [
        'Delivers up to 25 to 45 hours of room-filling fragrance.',
        'Made with natural essential oils and a proprietary soy wax blend.',
        'Features lead-free wicks engineered for a clean, even burn.',
        'Comes with a decorative lid to extinguish flame and protect wax.',
        '100% cruelty-free formula — never tested on animals.',
      ];
    }
    if (combined.contains('butter')) {
      return [
        'Rich, whipped, deeply indulgent body butter texture that melts into skin.',
        'Infused with rich Shea Butter and Cocoa Butter for 24-hour intense moisture.',
        'Relieves dry skin spots and restores skin\'s natural moisture barrier.',
        'Dermatologist approved and tested for daily skin nourishment.',
        '100% cruelty-free formula — never tested on animals.',
      ];
    }
    if (combined.contains('cream') || combined.contains('hydration')) {
      return [
        'Rich, luxurious cream texture that leaves skin feeling soft, smooth and replenished.',
        'Infused with Hyaluronic Acid and Shea Butter for 24-hour ultimate hydration.',
        'Fast-absorbing formula without any greasy residue.',
        'Dermatologist approved and tested for daily moisturizing.',
        '100% cruelty-free formula — never tested on animals.',
      ];
    }
    if (combined.contains('lotion')) {
      return [
        'Lightweight, silky body lotion that absorbs instantly into skin.',
        'Infused with Coconut Oil, Shea Butter, and Vitamin E.',
        'Provides 24 hours of continuous, weightless moisture.',
        'Dermatologist approved and tested for daily moisturizing.',
        '100% cruelty-free formula — never tested on animals.',
      ];
    }
    if (combined.contains('hand cream') || combined.contains('hand balm')) {
      return [
        'Rich, concentrated hand cream designed for fast absorption and deep relief.',
        'Infused with Shea Butter and Vitamin E to soothe dry, overworked hands.',
        'Compact travel size perfect for on-the-go nourishment.',
        'Dermatologist approved and tested.',
        '100% cruelty-free formula — never tested on animals.',
      ];
    }
    if (combined.contains('body wash') || combined.contains('shower gel') || combined.contains('cleanser')) {
      return [
        'Rich, bubbly lather that gently cleanses without drying skin.',
        'Infused with Pro-Vitamin B5, Aloe, and Shea Extract.',
        'Leaves skin feeling instantly refreshed, soft and beautifully scented.',
        'Dermatologist tested and suitable for daily showers.',
        '100% cruelty-free formula — never tested on animals.',
      ];
    }
    if (combined.contains('scrub')) {
      return [
        'Exfoliating body scrub with gentle buffing sugar granules.',
        'Removes dull, dry skin to reveal smooth, radiant, soft skin beneath.',
        'Infused with Vitamin E and essential oils for instant nourishment.',
        'Dermatologist tested.',
        '100% cruelty-free formula — never tested on animals.',
      ];
    }
    return [
      'Lightweight fine fragrance mist designed for lightweight, all-over coverage.',
      'Formulated with high fragrance concentration for lasting scent power.',
      'Gives up to 1,750 scent spritzes per full-size bottle.',
      'Dermatologist approved and tested for daily layering.',
      '100% cruelty-free formula — never tested on animals.',
    ];
  }

  (String usage, String proTip) _getHowToUseContent(Product product) {
    final sub = (product.subCategory ?? '').toLowerCase();
    final name = product.name.toLowerCase();
    final category = (product.category ?? '').toLowerCase();
    final combined = '$category $sub $name';

    if (combined.contains('candle')) {
      return (
        'Always trim wicks to 1/4 inch before lighting and keep debris out of wax pool. Never burn longer than 4-hour intervals. Set candle on heat-resistant surface and avoid drafts.',
        'Pro-Tip: Allow the entire top layer of wax to melt completely across the top on your first burn to prevent tunneling and ensure an even burn every time.',
      );
    }
    if (combined.contains('butter') || combined.contains('cream') || combined.contains('lotion')) {
      return (
        'Massage generously over clean, dry skin after a bath or shower, paying special attention to dry areas like elbows, knees, and hands. Reapply whenever skin needs extra hydration.',
        'Pro-Tip: For maximum scent staying power, apply matching scented moisturizer right after bathing while skin is still slightly damp, then lock in your scent with matching fine fragrance mist.',
      );
    }
    if (combined.contains('hand cream') || combined.contains('hand balm')) {
      return (
        'Apply a pea-sized amount to hands and massage thoroughly into palms, knuckles, and cuticles whenever hands feel dry or after washing hands.',
        'Pro-Tip: Keep a tube in your bag or desk drawer for instant hydration throughout the day.',
      );
    }
    if (combined.contains('body wash') || combined.contains('shower gel') || combined.contains('cleanser')) {
      return (
        'Apply to wet skin with hands, a washcloth, or a pouf. Work into a rich, fragrant lather, then rinse thoroughly with warm water.',
        'Pro-Tip: Follow immediately with matching body lotion or body cream to lock in moisture and scent.',
      );
    }
    if (combined.contains('scrub')) {
      return (
        'Gently massage in circular motions onto damp skin 2–3 times a week, focusing on dry areas. Rinse well with warm water.',
        'Pro-Tip: Always follow exfoliation with a rich body butter or cream to nourish fresh skin cells.',
      );
    }
    return (
      'Spritz generously over your skin and hair for a burst of scent as often as you like. Refresh throughout the day to carry the fine fragrance from morning to night.',
      'Pro-Tip: For all-day staying power, start with matching scented body wash, follow with body cream, then lock in your scent with this fine fragrance mist.',
    );
  }

  String _getIngredientsText(Product product) {
    final sub = (product.subCategory ?? '').toLowerCase();
    final name = product.name.toLowerCase();
    final category = (product.category ?? '').toLowerCase();
    final combined = '$category $sub $name';

    if (combined.contains('candle')) {
      return 'Hydrogenated Soy Wax Blend, Paraffin Wax, Natural Essential Oils (Fragrance/Parfum), Lead-Free Cotton Wicks, UV Inhibitors.';
    }
    if (combined.contains('butter')) {
      return 'Water (Aqua, Eau), Butyrospermum Parkii (Shea) Butter, Theobroma Cacao (Cocoa) Seed Butter, Caprylic/Capric Triglyceride, Fragrance (Parfum), Cetearyl Alcohol, Glycerin, Petrolatum, Cocos Nucifera (Coconut) Oil, Tocopherol (Vitamin E), Phenoxyethanol, Ethylhexylglycerin.';
    }
    if (combined.contains('cream') || combined.contains('hydration')) {
      return 'Water (Aqua, Eau), Glycerin, Caprylic/Capric Triglyceride, Isohexadecane, Fragrance (Parfum), Cetyl Alcohol, Butyrospermum Parkii (Shea) Butter, Sodium Hyaluronate (Hyaluronic Acid), Tocopherol (Vitamin E), Cocos Nucifera (Coconut) Oil, Dimethicone, Xanthan Gum.';
    }
    if (combined.contains('lotion')) {
      return 'Water (Aqua, Eau), Glycerin, Caprylic/Capric Triglyceride, Glyceryl Stearate SE, Fragrance (Parfum), Cetyl Alcohol, Butyrospermum Parkii (Shea) Butter, Cocos Nucifera (Coconut) Oil, Tocopheryl Acetate (Vitamin E), Dimethicone, Carbomer, Sodium Hydroxide, Disodium EDTA.';
    }
    if (combined.contains('hand cream')) {
      return 'Water (Aqua, Eau), Butyrospermum Parkii (Shea) Butter, Glycerin, Caprylic/Capric Triglyceride, Fragrance (Parfum), Glyceryl Stearate, Tocopheryl Acetate (Vitamin E), Sodium Hyaluronate, Cetearyl Alcohol, Ethylhexylglycerin.';
    }
    return 'Alcohol Denat., Water (Aqua, Eau), Fragrance (Parfum), Propylene Glycol, Ethylhexyl Methoxycinnamate, Ethylhexyl Salicylate, Butyl Methoxydibenzoylmethane, Ext. Violet 2, Linalool, Limonene, Benzyl Salicylate.';
  }

  @override
  Widget build(BuildContext context) {
    final fragrance = product.fragranceProfile;
    const gold = Color(0xFFE6B450);

    final bullets = _getOverviewBullets(product);
    final (usageText, proTipText) = _getHowToUseContent(product);
    final ingredientsText = _getIngredientsText(product);

    return Column(
      children: [
        // 1. Fragrance Notes Drawer
        if (fragrance != null)
          _AccordionCard(
            title: 'Fragrance Profile',
            icon: Icons.auto_awesome_rounded,
            initiallyExpanded: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (product.description != null && product.description!.isNotEmpty) ...[
                  Text(
                    product.description!,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                _noteRow('Top', fragrance.topNotes, const Color(0xFFFFD54F)),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Divider(color: Colors.white10, height: 1),
                ),
                _noteRow('Heart', fragrance.heartNotes, const Color(0xFFF48FB1)),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Divider(color: Colors.white10, height: 1),
                ),
                _noteRow('Base', fragrance.baseNotes, const Color(0xFFCE93D8)),
              ],
            ),
          ),

        const SizedBox(height: 8),

        // 2. Overview & Benefits Drawer
        _AccordionCard(
          title: 'Overview & Formula',
          icon: Icons.checklist_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: bullets.map((b) => _bullet(b)).toList(),
          ),
        ),

        const SizedBox(height: 8),

        // 3. Usage & Scent Layering Drawer
        _AccordionCard(
          title: 'How to Use & Care',
          icon: Icons.spa_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                usageText,
                style: const TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.35),
              ),
              const SizedBox(height: 8),
              Text(
                proTipText,
                style: const TextStyle(color: gold, fontSize: 12, height: 1.35, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // 4. Ingredients & Clean Standards Drawer
        _AccordionCard(
          title: 'Ingredients & Safety Standards',
          icon: Icons.verified_user_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (product.cleanStandards.isNotEmpty) ...[
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: product.cleanStandards.map((std) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F2618),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF4ADE80).withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        std,
                        style: const TextStyle(
                          color: Color(0xFF86EFAC),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
              ],
              Text(
                ingredientsText,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _noteRow(String tier, List<String> notes, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 50,
          child: Text(
            tier.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Expanded(
          child: Text(
            notes.isEmpty ? 'Signature essence' : notes.join(' • '),
            style: const TextStyle(color: Colors.white, fontSize: 12.5),
          ),
        ),
      ],
    );
  }

  Widget _bullet(String text) {
    const gold = Color(0xFFE6B450);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Icon(Icons.circle, size: 5, color: gold),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccordionCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final bool initiallyExpanded;

  const _AccordionCard({
    required this.title,
    required this.icon,
    required this.child,
    this.initiallyExpanded = false,
  });

  @override
  State<_AccordionCard> createState() => _AccordionCardState();
}

class _AccordionCardState extends State<_AccordionCard> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFE6B450);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _expanded ? gold.withValues(alpha: 0.28) : Colors.white.withValues(alpha: 0.05),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(widget.icon, size: 18, color: _expanded ? gold : Colors.white54),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        color: _expanded ? Colors.white : Colors.white70,
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: Colors.white38,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: widget.child,
            ),
            crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}
