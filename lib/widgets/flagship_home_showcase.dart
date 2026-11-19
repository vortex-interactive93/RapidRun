// File: lib/widgets/flagship_home_showcase.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BbwQuickRoom {
  final String id;
  final String label;
  final IconData icon;
  final String subtitle;

  const BbwQuickRoom({
    required this.id,
    required this.label,
    required this.icon,
    required this.subtitle,
  });
}

class FlagshipHomeShowcase extends StatefulWidget {
  final VoidCallback onOpenBbwStore;
  final ValueChanged<String> onSelectBbwRoom;
  final Widget recommendedSection;

  /// Pass exact asset paths from pubspec.yaml (defaults provided below)
  final String bbwLogoAsset;
  final String aldiLogoAsset;
  final String targetLogoAsset;

  const FlagshipHomeShowcase({
    super.key,
    required this.onOpenBbwStore,
    required this.onSelectBbwRoom,
    required this.recommendedSection,
    this.bbwLogoAsset = 'assets/images/bbw_logo.png',
    this.aldiLogoAsset = 'assets/images/aldi_logo.png',
    this.targetLogoAsset = 'assets/images/target_logo.png',
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
      subtitle: '3-Wick & Single',
    ),
    BbwQuickRoom(
      id: 'fragrance',
      label: 'Fine Fragrance',
      icon: Icons.auto_awesome_rounded,
      subtitle: 'Mists & EDPs',
    ),
    BbwQuickRoom(
      id: 'body_care',
      label: 'Body Care',
      icon: Icons.spa_rounded,
      subtitle: 'Creams & Washes',
    ),
    BbwQuickRoom(
      id: 'soaps',
      label: 'Hand Soaps',
      icon: Icons.clean_hands_rounded,
      subtitle: 'Foaming & Gels',
    ),
    BbwQuickRoom(
      id: 'wallflowers',
      label: 'Wallflowers',
      icon: Icons.air_rounded,
      subtitle: 'Refills & Plugs',
    ),
  ];

  @override
  void initState() {
    super.initState();
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
                      : 'VIP Alert Set! We’ll ping you when $storeName goes live.',
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
        // 1. MINIMAL SECTION HEADER
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Text(
            'Featured Store',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
        ),

        // 2. CLEAN, DECLUTTERED FLAGSHIP HERO CARD (BATH & BODY WORKS)
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
                  height: 176,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF241E26),
                        Color(0xFF171920),
                        Color(0xFF1F1C18),
                      ],
                    ),
                    border: Border.all(
                      color: _goldAccent.withValues(alpha: 0.35),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top Row: Real BBW Logo Badge + Single ETA Pill
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildBrandLogoContainer(
                              assetPath: widget.bbwLogoAsset,
                              size: 48,
                              fallbackIcon: Icons.spa_rounded,
                              fallbackColor: _goldAccent,
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                              decoration: BoxDecoration(
                                color: _goldAccent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _goldAccent.withValues(alpha: 0.35),
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.bolt_rounded, color: _goldAccent, size: 14),
                                  SizedBox(width: 4),
                                  Text(
                                    '25–35 MIN',
                                    style: TextStyle(
                                      color: _goldAccent,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        // Bottom Row: Clean Store Title, Subtitle & Action Button
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Bath & Body Works',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.4,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    '3-Wick Candles, Fine Fragrance & Body Care',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Color(0xFFA6ACB8),
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: _goldAccent,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: _goldAccent.withValues(alpha: 0.3),
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
                ),
              ),
            ),
          ),
        ),

        // 3. 1-TAP BOUTIQUE ROOM LAUNCHER
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 22, 16, 10),
          child: Text(
            'Shop by Department',
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
                  width: 140,
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
                            room.subtitle,
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

        // 5. COMING SOON STORES (WITH REAL ASSETS & ZERO OVERFLOW)
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 22, 16, 10),
          child: Text(
            'Launching Next on RapidRun',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              _buildComingSoonStoreCard(
                storeId: 'aldi',
                title: 'ALDI Market',
                subtitle: 'Fresh Produce, Meat & Everyday Pantry',
                logoAsset: widget.aldiLogoAsset,
                fallbackIcon: Icons.shopping_basket_rounded,
                accentColor: const Color(0xFF38BDF8),
              ),
              const SizedBox(height: 10),
              _buildComingSoonStoreCard(
                storeId: 'target',
                title: 'Target',
                subtitle: 'Home Essentials, Tech & Everyday Favorites',
                logoAsset: widget.targetLogoAsset,
                fallbackIcon: Icons.gps_fixed_rounded,
                accentColor: const Color(0xFFF87171),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
      ],
    );
  }

  /// Renders the store's real PNG/SVG logo from assets/ inside a crisp rounded frame
  Widget _buildBrandLogoContainer({
    required String assetPath,
    required double size,
    required IconData fallbackIcon,
    required Color fallbackColor,
  }) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: Image.asset(
          assetPath,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Icon(
            fallbackIcon,
            color: fallbackColor,
            size: size * 0.48,
          ),
        ),
      ),
    );
  }

  Widget _buildComingSoonStoreCard({
    required String storeId,
    required String title,
    required String subtitle,
    required String logoAsset,
    required IconData fallbackIcon,
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
              // Real Store Logo from assets/
              _buildBrandLogoContainer(
                assetPath: logoAsset,
                size: 46,
                fallbackIcon: fallbackIcon,
                fallbackColor: accentColor,
              ),
              const SizedBox(width: 12),
              // Store Name + Coming Soon Pill (Flexible prevents any pixel overflow)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.88),
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
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
              const SizedBox(width: 10),
              // Interactive Notify Button
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
