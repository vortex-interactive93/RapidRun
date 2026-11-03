// File: lib/screens/order/delivery_completion_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DeliveryCompletionSheet extends StatefulWidget {
  final String orderId;
  final String driverName;
  final String? dropoffPhotoUrl;
  final double initialTip;

  const DeliveryCompletionSheet({
    super.key,
    required this.orderId,
    this.driverName = 'Thomas Davis',
    this.dropoffPhotoUrl,
    this.initialTip = 5.00,
  });

  @override
  State<DeliveryCompletionSheet> createState() => _DeliveryCompletionSheetState();
}

class _DeliveryCompletionSheetState extends State<DeliveryCompletionSheet> {
  int _selectedRating = 5;
  double _tipBoost = 0.0;
  bool _isSubmitting = false;

  void _submitReviewAndTipBoost() async {
    setState(() => _isSubmitting = true);
    HapticFeedback.heavyImpact();

    try {
      final orderRef = FirebaseFirestore.instance.collection('orders').doc(widget.orderId);

      // Atomically update the order document that the customer owns
      await orderRef.update({
        'rating': _selectedRating,
        'tipBoost': _tipBoost,
        'totalTip': widget.initialTip + _tipBoost,
        'reviewedAt': FieldValue.serverTimestamp(),
        if (_tipBoost > 0) ...{
          'customerTip': FieldValue.increment(_tipBoost),
          'guaranteedPayout': FieldValue.increment(_tipBoost),
          'pendingBoostAmount': _tipBoost,
          'tipBoostPending': true,
          'boostToken': DateTime.now().millisecondsSinceEpoch.toString(),
          'tipBoostAddedAt': FieldValue.serverTimestamp(),
        },
      });

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF10B981),
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.black, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _tipBoost > 0
                        ? 'Added \$${_tipBoost.toStringAsFixed(2)} tip boost for ${widget.driverName}! Thank you! 🎉'
                        : 'Rating submitted! Enjoy your items!',
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.redAccent,
            content: Text('Failed to add tip boost: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF14171D),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 28),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'DELIVERED TO YOUR DOORSTEP',
                    style: TextStyle(
                      color: Color(0xFFE5A93C),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                  Text(
                    'Order fulfilled by ${widget.driverName}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Doorstep Photo Viewfinder Card
          _buildDoorstepPhotoPreview(context),

          const SizedBox(height: 20),

          // 5-Star Courier Rating Bar
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final starNumber = index + 1;
                final isSelected = starNumber <= _selectedRating;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedRating = starNumber);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(
                      isSelected ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: isSelected ? const Color(0xFFE5A93C) : Colors.white24,
                      size: 34,
                    ),
                  ),
                );
              }),
            ),
          ),

          const SizedBox(height: 20),

          // Extra Courier Tip Booster
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'BOOST COURIER TIP',
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                'Initial Tip: \$${widget.initialTip.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [2.0, 4.0, 6.0].map((boost) {
              final isSel = _tipBoost == boost;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _tipBoost = isSel ? 0.0 : boost);
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isSel ? const Color(0xFFE5A93C) : Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSel ? const Color(0xFFE5A93C) : Colors.white10,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '+\$${boost.toInt()}',
                        style: TextStyle(
                          color: isSel ? Colors.black : Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 24),

          // Done Action Button
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE5A93C),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 4,
            ),
            onPressed: _isSubmitting ? null : _submitReviewAndTipBoost,
            child: _isSubmitting
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                : Text(
                    _tipBoost > 0
                        ? 'CONFIRM & ADD +\$${_tipBoost.toStringAsFixed(2)} TIP'
                        : 'SUBMIT RATING & RETURN HOME',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoorstepPhotoPreview(BuildContext context) {
    final photoUrl = widget.dropoffPhotoUrl;

    return GestureDetector(
      onTap: () {
        if (photoUrl == null || photoUrl.isEmpty) return;
        HapticFeedback.lightImpact();
        showDialog(
          context: context,
          builder: (_) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(12),
            child: Stack(
              alignment: Alignment.topRight,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: InteractiveViewer(
                    maxScale: 4.0,
                    child: Image.network(photoUrl, fit: BoxFit.contain),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        );
      },
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          color: Colors.black45,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          alignment: Alignment.bottomRight,
          children: [
            photoUrl != null && photoUrl.isNotEmpty
                ? Image.network(photoUrl, fit: BoxFit.cover, width: double.infinity)
                : Container(
                    color: const Color(0xFF1B1E26),
                    width: double.infinity,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.door_front_door_outlined, color: Colors.white.withValues(alpha: 0.3), size: 40),
                        const SizedBox(height: 8),
                        Text(
                          'Doorstep Photo Proof Verified',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Left safely according to gate instructions',
                          style: TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
            if (photoUrl != null && photoUrl.isNotEmpty)
              Container(
                margin: const EdgeInsets.all(10),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.zoom_in, color: Color(0xFFE5A93C), size: 14),
                    SizedBox(width: 4),
                    Text('TAP TO ENLARGE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
