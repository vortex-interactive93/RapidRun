import 'package:flutter/material.dart';
import 'package:rapidrun_driver/presentation/home/incoming_offer_overlay.dart';
import 'package:rapidrun_driver/theme/design_tokens.dart';

/// Simple MVP bottom sheet listing multiple offers.
/// Not yet draggable (tap-to-toggle integration handled by parent screen).
class OffersBottomSheet extends StatelessWidget {
  final List<IncomingOfferData> offers;
  final ValueChanged<IncomingOfferData> onAccept;
  final ValueChanged<IncomingOfferData> onDecline;
  final VoidCallback onCloseRequested;
  const OffersBottomSheet({
    super.key,
    required this.offers,
    required this.onAccept,
    required this.onDecline,
    required this.onCloseRequested,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: DesignTokens.surfaceElevated.withOpacity(0.97),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black87,
            blurRadius: 30,
            offset: Offset(0, -10),
          ),
        ],
        border: Border.all(color: Colors.white.withOpacity(0.06), width: 1),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: onCloseRequested,
            child: Container(
              width: 46,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.22),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'Offers (${offers.length})',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: onCloseRequested,
                icon: const Icon(Icons.close, color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: offers.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final o = offers[i];
                return _OfferRow(
                  data: o,
                  onAccept: () => onAccept(o),
                  onDecline: () => onDecline(o),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _OfferRow extends StatelessWidget {
  final IncomingOfferData data;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  const _OfferRow({
    required this.data,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.07), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  data.store,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              _badge('${data.expiresIn.inSeconds}s'),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Pay ${data.pay.toStringAsFixed(2)} • ${data.distanceMiles.toStringAsFixed(1)} mi • ETA ${data.eta.inMinutes}m',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _button(
                  context,
                  label: 'Decline',
                  filled: false,
                  onTap: onDecline,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _button(
                  context,
                  label: 'Accept',
                  filled: true,
                  onTap: onAccept,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _badge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [DesignTokens.primaryBright, DesignTokens.secondaryBright],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _button(
    BuildContext context, {
    required String label,
    required bool filled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: filled
              ? LinearGradient(
                  colors: [DesignTokens.primary, DesignTokens.secondary],
                )
              : null,
          color: filled ? null : Colors.white.withOpacity(0.08),
          border: Border.all(color: Colors.white.withOpacity(0.12), width: 1),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: filled ? Colors.white : Colors.white,
          ),
        ),
      ),
    );
  }
}
