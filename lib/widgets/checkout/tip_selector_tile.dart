// File: lib/widgets/checkout/tip_selector_tile.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TipSelectorTile extends StatefulWidget {
  final double subtotal;
  final ValueChanged<double> onTipSelected;

  const TipSelectorTile({
    super.key,
    required this.subtotal,
    required this.onTipSelected,
  });

  @override
  State<TipSelectorTile> createState() => _TipSelectorTileState();
}

class _TipSelectorTileState extends State<TipSelectorTile> {
  int _selectedIndex = 2; // Default to 15%
  final double _customTip = 0.0;

  List<double> get _tipPercentages => [0.10, 0.12, 0.15, 0.20];

  double _getTipAmount(int index) {
    if (index < _tipPercentages.length) {
      final calculated = widget.subtotal * _tipPercentages[index];
      // Minimum tip floor of $3.00 so small carts still reward drivers
      return calculated < 3.00 ? 3.00 : calculated;
    }
    return _customTip;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onTipSelected(_getTipAmount(_selectedIndex));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'Shopper Tip',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                '100% goes to your driver',
                style: TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Tip Selection Pills
          Row(
            children: [
              for (int i = 0; i < _tipPercentages.length; i++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: i == _tipPercentages.length - 1 ? 0 : 8),
                    child: _tipPill(
                      label: '${(_tipPercentages[i] * 100).round()}%',
                      amount: '\$${_getTipAmount(i).toStringAsFixed(2)}',
                      isSelected: _selectedIndex == i,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedIndex = i);
                        widget.onTipSelected(_getTipAmount(i));
                      },
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tipPill({
    required String label,
    required String amount,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    const gold = Color(0xFFE6B450);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? gold : const Color(0xFF262626),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? gold : Colors.white12),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              amount,
              style: TextStyle(
                color: isSelected ? Colors.black87 : Colors.white54,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
