// File: lib/screens/profile/profile_screen.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rapidrun_shared/rapidrun_shared.dart';
import '../account/noir_membership_screen.dart';
import '../account/order_receipt_detail_sheet.dart';
import '../account/saved_favorites_sheet.dart';
import '../account/tier_features_deep_dive_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _devTapCount = 0;

  @override
  void initState() {
    super.initState();
    customerState.addListener(_onStateChange);
  }

  @override
  void dispose() {
    customerState.removeListener(_onStateChange);
    super.dispose();
  }

  void _onStateChange() {
    if (mounted) setState(() {});
  }

  void _handleDevTap() {
    _devTapCount++;
    if (_devTapCount >= 3) {
      _devTapCount = 0;
      HapticFeedback.heavyImpact();
      _showDevConsole(context);
    }
  }

  void _openTierComparison() async {
    HapticFeedback.mediumImpact();
    final newTierStr = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => NoirMembershipScreen(currentTier: customerState.tierName),
      ),
    );

    if (newTierStr != null && mounted) {
      MembershipTier newTier = MembershipTier.noirVip;
      if (newTierStr.contains('Classic')) newTier = MembershipTier.classic;
      if (newTierStr.contains('Velocity')) newTier = MembershipTier.velocity;

      customerState.setTier(newTier);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Membership updated to ${customerState.tierName}!'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    }
  }

  void _editAddressAndGateCode() {
    HapticFeedback.lightImpact();
    final addressController = TextEditingController(text: customerState.address);
    final gateCodeController = TextEditingController(text: customerState.gateCode);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF14171D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'PRIMARY DROP-OFF LOCATION',
              style: TextStyle(
                color: Color(0xFFE5A93C),
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: addressController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Street Address',
                labelStyle: const TextStyle(color: Colors.white60),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.04),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: gateCodeController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Gate Code / Access Note',
                labelStyle: const TextStyle(color: Colors.white60),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.04),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE5A93C),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                customerState.updateAddress(addressController.text, gateCodeController.text);
                Navigator.of(context).pop();
                HapticFeedback.mediumImpact();
              },
              child: const Text('SAVE DROP-OFF DETAILS', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _openTipAndPaymentSheet() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF14171D),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'DEFAULT COURIER GRATUITY',
                style: TextStyle(
                  color: Color(0xFFE5A93C),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '100% of tips pass directly to your personal courier.',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [15, 20, 25, 30].map((tip) {
                  final isSel = customerState.defaultTipPercent == tip;
                  return GestureDetector(
                    onTap: () {
                      setModalState(() => customerState.setTipPercent(tip));
                      HapticFeedback.selectionClick();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSel ? const Color(0xFFE5A93C) : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSel ? const Color(0xFFE5A93C) : Colors.white10,
                        ),
                      ),
                      child: Text(
                        '$tip%',
                        style: TextStyle(
                          color: isSel ? Colors.black : Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE5A93C),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('CONFIRM DEFAULT TIP', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDevConsole(BuildContext context) {
    const gold = Color(0xFFE6B450);
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF14171D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.terminal_rounded, color: gold, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'ENGINEERING & DIAGNOSTICS',
                    style: TextStyle(color: gold, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.rocket_launch_rounded, color: gold),
                title: const Text('Seed Test Dispatch Batch', style: TextStyle(color: Colors.white, fontSize: 14)),
                subtitle: const Text('Writes orders/ document directly to Firestore', style: TextStyle(color: Colors.white54, fontSize: 11)),
                onTap: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Test order dispatched to driver pool')),
                  );
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.cleaning_services_rounded, color: Colors.redAccent),
                title: const Text('Clear Local Cart & App Cache', style: TextStyle(color: Colors.white, fontSize: 14)),
                onTap: () => Navigator.pop(ctx),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFE6B450);
    const bg = Color(0xFF101216);
    const cardBg = Color(0xFF171A21);

    final user = FirebaseAuth.instance.currentUser;
    final userName = user?.displayName ?? (user?.email != null ? user!.email!.split('@').first : 'Thomas Davis');
    final userEmail = user?.email ?? 'tjaysds@gmail.com';
    final isNoir = customerState.tier == MembershipTier.noirVip;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Account & Concierge',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.headset_mic_outlined, color: gold),
            onPressed: () {},
            tooltip: 'Concierge Support',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120), // 120px bottom clearance for mini-cart
        children: [
          // 1. RapidRun Noir Concierge VIP Pass
          GestureDetector(
            onTap: _openTierComparison,
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF262A34), Color(0xFF14161C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isNoir ? gold.withValues(alpha: 0.35) : Colors.white12,
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.55),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Color(0xFFFCD34D), Color(0xFFD97706)],
                          ),
                        ),
                        child: const Center(
                          child: Icon(Icons.bolt_rounded, color: Colors.black, size: 24),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              userName,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              userEmail,
                              style: const TextStyle(color: Colors.white54, fontSize: 11.5),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(
                          color: gold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: gold.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              customerState.tierName.toUpperCase(),
                              style: const TextStyle(color: gold, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.6),
                            ),
                            const SizedBox(width: 2),
                            const Icon(Icons.chevron_right, color: gold, size: 14),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  const Divider(color: Colors.white10, height: 1),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('PRIMARY DROP-OFF', style: TextStyle(color: Colors.white38, fontSize: 9.5, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text(
                              customerState.address,
                              style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('DISPATCH TIER', style: TextStyle(color: Colors.white38, fontSize: 9.5, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text(
                            customerState.dispatchTier,
                            style: TextStyle(
                              color: isNoir ? const Color(0xFF4ADE80) : Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 2. Inset Group 1: Fulfillment & Logistics
          _buildSectionHeader('DELIVERY & FULFILLMENT'),
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Column(
              children: [
                _buildTile(
                  icon: Icons.location_on_outlined,
                  title: 'Saved Addresses & Gate Codes',
                  subtitle: '${customerState.address} • Gate ${customerState.gateCode}',
                  onTap: _editAddressAndGateCode,
                ),
                _buildDivider(),
                _buildTile(
                  icon: Icons.receipt_long_outlined,
                  title: 'Past Orders & Itemized Receipts',
                  subtitle: 'Bath & Body Works and store deliveries',
                  onTap: () {
                    HapticFeedback.lightImpact();
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (ctx) => const OrderReceiptDetailSheet(orderId: '46342444'),
                    );
                  },
                ),
                _buildDivider(),
                _buildTile(
                  icon: Icons.favorite_border_rounded,
                  title: 'Saved Favorite Products',
                  subtitle: 'Fine Fragrance Mists, Body Creams',
                  onTap: () {
                    HapticFeedback.lightImpact();
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (ctx) => const SavedFavoritesSheet(),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // 3. Inset Group 2: Payment & Security
          _buildSectionHeader('PAYMENT & CONCIERGE'),
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Column(
              children: [
                _buildTile(
                  icon: Icons.layers_outlined,
                  title: 'Tier Specifications & Feature Matrix',
                  subtitle: 'Compare Classic, Velocity Pass, and Noir VIP',
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TierFeaturesDeepDiveScreen()),
                    );
                  },
                ),
                _buildDivider(),
                _buildTile(
                  icon: Icons.credit_card_rounded,
                  title: 'Payment Methods & Default Tip',
                  subtitle: 'Apple Pay, Cards • ${customerState.defaultTipPercent}% Default Courier Tip',
                  onTap: _openTipAndPaymentSheet,
                ),
                _buildDivider(),
                _buildTile(
                  icon: Icons.fingerprint_rounded,
                  title: 'Biometric App Authentication',
                  subtitle: 'Require Face ID / Fingerprint on checkout',
                  trailing: Switch(
                    value: customerState.biometricsEnabled,
                    activeColor: gold,
                    onChanged: (v) {
                      customerState.toggleBiometrics(v);
                      HapticFeedback.selectionClick();
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // 4. Inset Group 3: System & Account
          _buildSectionHeader('ACCOUNT'),
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Column(
              children: [
                _buildTile(
                  icon: Icons.notifications_none_rounded,
                  title: 'Push Notifications',
                  subtitle: 'Real-time order stage progressions',
                  trailing: Switch(
                    value: customerState.pushNotifications,
                    activeColor: gold,
                    onChanged: (v) {
                      customerState.toggleNotifications(v);
                      HapticFeedback.selectionClick();
                    },
                  ),
                ),
                _buildDivider(),
                _buildTile(
                  icon: Icons.logout_rounded,
                  title: 'Sign Out',
                  titleColor: Colors.redAccent,
                  onTap: () async {
                    await FirebaseAuth.instance.signOut();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // 5. Version String (Easter-Egg Developer Trigger)
          Center(
            child: GestureDetector(
              onTap: _handleDevTap,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'RapidRun Client • v1.0.4 (Build 88)',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 11),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 6, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.6),
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(color: Colors.white10, height: 1, indent: 52);
  }

  Widget _buildTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Color? titleColor,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    const gold = Color(0xFFE6B450);

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: titleColor ?? gold, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: titleColor ?? Colors.white,
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            )
          : null,
      trailing: trailing ?? const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 14),
    );
  }
}
