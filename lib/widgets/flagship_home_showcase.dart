// File: lib/widgets/flagship_home_showcase.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BbwQuickRoom {
  final String id;
  final String label;
  final IconData icon;
  final String itemCountLabel;

  const BbwQuickRoom({
    required this.id,
    required this.label,
    required this.icon,
    required this.itemCountLabel,
  });
}

class FlagshipHomeShowcase extends StatefulWidget {
  final VoidCallback onOpenBbwStore;
  final ValueChanged<String> onSelectBbwRoom;
  final Widget recommendedSection;

  const FlagshipHomeShowcase({
    super.key,
    required this.onOpenBbwStore,
    required this.onSelectBbwRoom,
    required this.recommendedSection,
  });

  @override
  State<FlagshipHomeShowcase> createState() => _FlagshipHomeShowcaseState();
}

class _FlagshipHomeShowcaseState extends State<FlagshipHomeShowcase>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressController;
  late final Animation<double> _scaleAnim;
  final Set<String> _notifiedStores = {};

  static const _goldAccent = Color(0xFFF5C542);
  static const _surfaceDark = Color(0xFF171A21);
  static const _borderSubtle = Color(0xFF282D38);

  static const List<BbwQuickRoom> _bbwRooms = [
    BbwQuickRoom(
      id: 'candles',
      label: '3-Wick Candles',
      icon: Icons.local_fire_department_rounded,
      itemCountLabel: '3-Wick & Single',
    ),
    BbwQuickRoom(
      id: 'fragrance',
      label: 'Fine Fragrance',
      icon: Icons.auto_awesome_rounded,
      itemCountLabel: 'Mists & EDPs',
    ),
    BbwQuickRoom(
      id: 'body_care',
      label: 'Body Care',
      icon: Icons.spa_rounded,
      itemCountLabel: 'Creams & Washes',
    ),
    BbwQuickRoom(
      id: 'soaps',
      label: 'Soaps & PocketBacs',
      icon: Icons.clean_hands_rounded,
      itemCountLabel: '40% Off Deals',
    ),
    BbwQuickRoom(
      id: 'wallflowers',
      label: 'Wallflowers',
      icon: Icons.air_rounded,
      itemCountLabel: '10/\$30 Refills',
    ),
  ];

  @override
  void initState() {
    super.initState();
    // 120fps physics-inspired tactile spring press for the Flagship Hero card
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 110),
      reverseDuration: const Duration(milliseconds: 180),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.975).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.fastOutSlowIn),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _toggleNotifyStore(String storeId, String storeName) {
    HapticFeedback.selectionClick();
    final alreadyAdded = _notifiedStores.contains(storeId);
    setState(() {
      if (alreadyAdded) {
        _notifiedStores.remove(storeId);
      } else {
        _notifiedStores.add(storeId);
      }
    });

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF1E222B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: _goldAccent.withValues(alpha: 0.4)),
          ),
          content: Row(
            children: [
              Icon(
                alreadyAdded ? Icons.notifications_off_outlined : Icons.bolt_rounded,
                color: _goldAccent,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  alreadyAdded
                      ? 'Removed $storeName launch alert'
                      : 'VIP Alert Set! We’ll ping you the second $storeName goes live.',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. SECTION HEADER WITH LIVE STATUS INDICATOR
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Flagship Destination',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _goldAccent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _goldAccent.withValues(alpha: 0.35)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_rounded, color: _goldAccent, size: 13),
                    SizedBox(width: 4),
                    Text(
                      '380+ IN-STORE ITEMS',
                      style: TextStyle(
                        color: _goldAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // 2. HERO FLAGSHIP CARD (BATH & BODY WORKS)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: RepaintBoundary(
            child: GestureDetector(
              onTapDown: (_) {
                HapticFeedback.lightImpact();
                _pressController.forward();
              },
              onTapUp: (_) {
                _pressController.reverse();
                widget.onOpenBbwStore();
              },
              onTapCancel: () => _pressController.reverse(),
              child: ScaleTransition(
                scale: _scaleAnim,
                child: Container(
                  height: 196,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF2B1E26),
                        Color(0xFF1A171D),
                        Color(0xFF261E19),
                      ],
                    ),
                    border: Border.all(
                      color: _goldAccent.withValues(alpha: 0.38),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _goldAccent.withValues(alpha: 0.12),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // Subtle ambient watermark motif
                      Positioned(
                        right: -18,
                        bottom: -24,
                        child: Icon(
                          Icons.spa_rounded,
                          size: 165,
                          color: _goldAccent.withValues(alpha: 0.06),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Top Badges Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildPill(
                                  icon: Icons.spa_rounded,
                                  label: 'FRAGRANCE & BODY',
                                  bgColor: Colors.black.withValues(alpha: 0.45),
                                  textColor: _goldAccent,
                                ),
                                _buildPill(
                                  icon: Icons.bolt_rounded,
                                  label: '25–35 MIN',
                                  bgColor: _goldAccent.withValues(alpha: 0.18),
                                  textColor: _goldAccent,
                                ),
                              ],
                            ),
                            const Spacer(),
                            // Live Deal Highlight Strip
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF34222B),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFFFF7EB3).withValues(alpha: 0.35),
                                ),
                              ),
                              child: const Text(
                                '✨ Mix & Match: Buy 3, Get 3 FREE + 40% Off Select Items',
                                style: TextStyle(
                                  color: Color(0xFFFFB8D6),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Bath & Body Works',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 23,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -0.4,
                                        ),
                                      ),
                                      SizedBox(height: 3),
                                      Text(
                                        'Fine Fragrance, 3-Wick Candles & Hand Soaps',
                                        style: TextStyle(
                                          color: Color(0xFFB5BAC5),
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: _goldAccent,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: _goldAccent.withValues(alpha: 0.35),
                                        blurRadius: 12,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.arrow_forward_rounded,
                                    color: Colors.black,
                                    size: 22,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // 3. 1-TAP BOUTIQUE ROOM LAUNCHER CAROUSEL
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 20, 16, 10),
          child: Text(
            'Shop by Boutique Room',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        SizedBox(
          height: 82,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _bbwRooms.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final room = _bbwRooms[index];
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  widget.onSelectBbwRoom(room.id);
                },
                child: Container(
                  width: 142,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _surfaceDark,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _borderSubtle),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Icon(room.icon, color: _goldAccent, size: 20),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: Color(0xFF6B7280),
                            size: 18,
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            room.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            room.itemCountLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF8B92A0),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // 4. EXISTING RECOMMENDED FOR YOU CAROUSEL
        const SizedBox(height: 12),
        widget.recommendedSection,

        // 5. FROSTED "LAUNCHING NEXT" TEASER (ALDI MARKET & TARGET)
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 20, 16, 10),
          child: Row(
            children: [
              Text(
                'Launching Next on RapidRun',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(width: 8),
              Icon(Icons.auto_awesome, color: _goldAccent, size: 16),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              _buildComingSoonStoreCard(
                storeId: 'aldi',
                title: 'ALDI Market',
                subtitle: 'Fresh Produce, Meat & Everyday Pantry Staples',
                icon: Icons.shopping_basket_rounded,
                accentColor: const Color(0xFF38BDF8),
              ),
              const SizedBox(height: 10),
              _buildComingSoonStoreCard(
                storeId: 'target',
                title: 'Target Express',
                subtitle: 'Home Essentials, Tech & Everyday Favorites',
                icon: Icons.gps_fixed_rounded,
                accentColor: const Color(0xFFF87171),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
      ],
    );
  }

  Widget _buildPill({
    required IconData icon,
    required String label,
    required Color bgColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: textColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: textColor, size: 13),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComingSoonStoreCard({
    required String storeId,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
  }) {
    final isNotified = _notifiedStores.contains(storeId);

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _surfaceDark.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _borderSubtle),
          ),
          child: Row(
            children: [
              // Muted store emblem
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: accentColor.withValues(alpha: 0.25)),
                ),
                child: Icon(icon, color: accentColor.withValues(alpha: 0.8), size: 22),
              ),
              const SizedBox(width: 12),
              // Title + Coming Soon badge
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.82),
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: _goldAccent.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'COMING SOON',
                            style: TextStyle(
                              color: _goldAccent,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF7D8594),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Interactive VIP Notify Me pill (prevents dead-tap frustration)
              GestureDetector(
                onTap: () => _toggleNotifyStore(storeId, title),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                  decoration: BoxDecoration(
                    color: isNotified
                        ? _goldAccent.withValues(alpha: 0.18)
                        : const Color(0xFF222631),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isNotified ? _goldAccent : const Color(0xFF343A49),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isNotified
                            ? Icons.notifications_active_rounded
                            : Icons.notifications_none_rounded,
                        color: isNotified ? _goldAccent : Colors.white70,
                        size: 15,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isNotified ? 'Notified' : 'Notify',
                        style: TextStyle(
                          color: isNotified ? _goldAccent : Colors.white70,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
