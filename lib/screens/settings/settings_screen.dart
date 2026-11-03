import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../theme/tokens.dart';
import '../../services/firebase_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/preferences_service.dart';
import '../../services/display_preferences.dart';
import '../../services/config_service.dart';
import 'package:flutter/services.dart';
import 'delivery_instructions_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notifications = true; // persisted
  bool _mergeOnLogin = true; // persisted
  bool _loadingPrefs = true;
  bool _reduceMotion = false; // persisted
  bool _highContrast = false; // persisted
  bool _biometricLock = false; // persisted
  double _textScale = 1.0; // persisted

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    try {
      _notifications = await PreferencesService.getNotificationsEnabled();
      _mergeOnLogin = await PreferencesService.getMergeOnLogin();
      final dp = DisplayPreferences.instance.value;
      _reduceMotion = dp.reduceMotion;
      _highContrast = dp.highContrast;
      _biometricLock = dp.biometricLock;
      _textScale = dp.textScale;
    } catch (_) {}
    if (mounted) setState(() => _loadingPrefs = false);
  }

  Future<void> _savePrefs() async {
    try {
      await PreferencesService.setNotificationsEnabled(_notifications);
      await PreferencesService.setMergeOnLogin(_mergeOnLogin);
    } catch (_) {}
  }

  Future<void> _changePassword() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(appSnackBar('Sign in first', icon: Icons.lock_outline));
      return;
    }
    if (user.email == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        appSnackBar(
          'Email user required for password change',
          icon: Icons.mail_outline,
        ),
      );
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: user.email!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          appSnackBar('Password reset email sent', icon: Icons.mark_email_read),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        appSnackBar(
          e.message ?? e.code,
          icon: Icons.error_outline,
          background: Colors.redAccent.withValues(alpha: 0.85),
        ),
      );
    }
  }

  Future<void> _deleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(appSnackBar('Not signed in', icon: Icons.lock_outline));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Account?'),
        content: const Text(
          'This will permanently remove your account. This demo does not yet delete related Firestore docs.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await user.delete();
      if (mounted) Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        appSnackBar(
          e.message ?? e.code,
          icon: Icons.error_outline,
          background: Colors.redAccent.withValues(alpha: 0.85),
        ),
      );
    }
  }

  void _stub(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      appSnackBar('$label request queued (stub).', icon: Icons.pending_actions),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Ensure config updates listener started
    ConfigService.instance.ensureListening();
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: _loadingPrefs
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<User?>(
              stream: FirebaseService.userStream,
              initialData: FirebaseService.user,
              builder: (context, authSnap) {
                final user = authSnap.data;
                return ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                      child: Text(
                        'Account',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Colors.white70,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    _groupCard(
                      children: [
                        if (user == null)
                          ListTile(
                            leading: const Icon(Icons.person_outline),
                            title: const Text('Guest'),
                            subtitle: const Text('Not signed in'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () async {
                              final changed = await Navigator.pushNamed(
                                context,
                                '/login',
                              );
                              if (changed == true && mounted)
                                setState(
                                  () {},
                                ); // rebuild to refresh dependent UI
                            },
                          )
                        else
                          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                            stream: FirebaseFirestore.instance
                                .collection('users')
                                .doc(user.uid)
                                .snapshots(),
                            builder: (context, snap) {
                              final phoneVerified =
                                  (snap.data?.data()?['phoneVerified'] ==
                                      true) ||
                                  (user.phoneNumber != null);
                              final emailVerified = user.emailVerified;
                              return ListTile(
                                leading: const Icon(Icons.person),
                                title: Text(user.email ?? 'Account'),
                                subtitle: Wrap(
                                  spacing: 6,
                                  runSpacing: -8,
                                  children: [
                                    Chip(
                                      label: Text(
                                        emailVerified ? 'Email ✓' : 'Email ✕',
                                        style: TextStyle(
                                          color: emailVerified
                                              ? Colors.greenAccent
                                              : Colors.redAccent,
                                        ),
                                      ),
                                      backgroundColor: Colors.black.withValues(
                                        alpha: 0.05,
                                      ),
                                    ),
                                    Chip(
                                      label: Text(
                                        phoneVerified ? 'Phone ✓' : 'Phone ✕',
                                        style: TextStyle(
                                          color: phoneVerified
                                              ? Colors.greenAccent
                                              : Colors.redAccent,
                                        ),
                                      ),
                                      backgroundColor: Colors.black.withValues(
                                        alpha: 0.05,
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: TextButton(
                                  onPressed: () async {
                                    await FirebaseAuth.instance.signOut();
                                    if (!mounted) return;
                                    // Remain in app as guest; rebuild to refresh UI
                                    setState(() {});
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      appSnackBar('Signed out (guest mode)'),
                                    );
                                  },
                                  child: const Text('Sign Out'),
                                ),
                                onTap: () => Navigator.pushNamed(
                                  context,
                                  '/settings/personal',
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // PERSONALIZATION & PREFERENCES
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                      child: Text(
                        'Preferences',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Colors.white70,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    _groupCard(
                      children: [
                        SwitchListTile(
                          title: const Text('Enable Notifications'),
                          value: _notifications,
                          onChanged: (v) => setState(() {
                            _notifications = v;
                            _savePrefs();
                          }),
                        ),
                        _navTile(
                          icon: Icons.notifications_active_outlined,
                          title: 'Notification Preferences',
                          subtitle: 'Quiet hours, digest, categories',
                          route: '/settings/notifications',
                        ),
                        SwitchListTile(
                          title: const Text('Merge local data on next login'),
                          subtitle: const Text(
                            'Uploads guest cart & favorites after signing in.',
                          ),
                          value: _mergeOnLogin,
                          onChanged: (v) => setState(() {
                            _mergeOnLogin = v;
                            _savePrefs();
                          }),
                        ),
                        _navTile(
                          icon: Icons.store_mall_directory_outlined,
                          title: 'Shopping Preferences',
                          subtitle: 'Dietary filters, sorting, units',
                          route: '/settings/shopping-prefs',
                        ),
                        ListTile(
                          leading: const Icon(Icons.filter_alt_outlined),
                          title: const Text('Dietary & Allergens'),
                          subtitle: const Text(
                            'Intolerances & ingredient filters (stub)',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _stub('Dietary filters'),
                        ),
                        ListTile(
                          leading: const Icon(Icons.delivery_dining),
                          title: const Text('Delivery Instructions'),
                          subtitle: const Text(
                            'Leave at door, ring/knock, notes',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const DeliveryInstructionsScreen(),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // ACCESSIBILITY
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                      child: Text(
                        'Accessibility',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Colors.white70,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    _groupCard(
                      children: [
                        SwitchListTile(
                          title: const Text('Reduce Motion'),
                          subtitle: const Text('Limit large animations'),
                          value: _reduceMotion,
                          onChanged: (v) => setState(() {
                            _reduceMotion = v;
                            DisplayPreferences.instance.setReduceMotion(v);
                          }),
                        ),
                        SwitchListTile(
                          title: const Text('High Contrast'),
                          subtitle: const Text('Stronger color separation'),
                          value: _highContrast,
                          onChanged: (v) => setState(() {
                            _highContrast = v;
                            DisplayPreferences.instance.setHighContrast(v);
                          }),
                        ),
                        ListTile(
                          leading: const Icon(Icons.format_size),
                          title: const Text('Text Size'),
                          subtitle: Text(
                            'Scale ${(_textScale * 100).round()}% (stub)',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            setState(() {
                              if (_textScale < 1.2) {
                                _textScale = double.parse(
                                  (_textScale + 0.1).toStringAsFixed(2),
                                );
                              } else {
                                _textScale = 1.0;
                              }
                            });
                            DisplayPreferences.instance.setTextScale(
                              _textScale,
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              appSnackBar(
                                'Text scale ${(_textScale * 100).round()}%',
                              ),
                            );
                          },
                        ),
                      ],
                    ),

                    if (user != null) ...[
                      const SizedBox(height: 16),
                      // ORDERS & PAYMENT
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                        child: Text(
                          'Orders & Payment',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: Colors.white70,
                                letterSpacing: 0.5,
                              ),
                        ),
                      ),
                      _groupCard(
                        children: [
                          _navTile(
                            icon: Icons.receipt_long,
                            title: 'Order History',
                            subtitle: 'View previous demo orders',
                            route: '/orders',
                          ),
                          _navTile(
                            icon: Icons.credit_card,
                            title: 'Payment Methods & Tips',
                            subtitle: 'Saved cards, default tip',
                            route: '/settings/payments',
                          ),
                          _navTile(
                            icon: Icons.location_on_outlined,
                            title: 'Address Book',
                            subtitle: 'Saved delivery locations',
                            route: '/settings/addresses',
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),
                      // SECURITY & PRIVACY
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                        child: Text(
                          'Security & Privacy',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: Colors.white70,
                                letterSpacing: 0.5,
                              ),
                        ),
                      ),
                      _groupCard(
                        children: [
                          _navTile(
                            icon: Icons.person_outline,
                            title: 'Personal Details',
                            subtitle: 'Manage email, phone & profile',
                            route: '/settings/personal',
                          ),
                          SwitchListTile(
                            title: const Text('Biometric / App Lock'),
                            subtitle: const Text(
                              'Require biometrics on launch (stub)',
                            ),
                            value: _biometricLock,
                            onChanged: (v) => setState(() {
                              _biometricLock = v;
                              DisplayPreferences.instance.setBiometricLock(v);
                            }),
                          ),
                          ListTile(
                            leading: const Icon(Icons.lock_reset),
                            title: const Text('Password Reset Email'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: _changePassword,
                          ),
                          _navTile(
                            icon: Icons.privacy_tip_outlined,
                            title: 'Privacy & Data',
                            subtitle: 'Personalization, tracking consent',
                            route: '/settings/privacy-data',
                          ),
                          ListTile(
                            leading: const Icon(
                              Icons.delete_forever,
                              color: Colors.redAccent,
                            ),
                            title: const Text('Delete Account'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: _deleteAccount,
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 16),
                    // BETA & DIAGNOSTICS (moved lower for typical user priority)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                      child: Text(
                        'Beta & Diagnostics',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Colors.white70,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    StreamBuilder<AppRemoteConfig>(
                      stream: ConfigService.instance.stream,
                      initialData: ConfigService.instance.current,
                      builder: (context, snap) {
                        final cfg = snap.data ?? ConfigService.instance.current;
                        final text =
                            cfg.betaBannerText ??
                            'Beta – test payments only. Features limited.';
                        return _groupCard(
                          children: [
                            ListTile(
                              leading: const Icon(
                                Icons.delivery_dining,
                                color: Color(0xFFE6B450),
                              ),
                              title: const Text(
                                'Courier / Driver Mode',
                                style: TextStyle(
                                  color: Color(0xFFE6B450),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: const Text(
                                'Launch courier dispatch, order acceptance & live fulfillment view',
                              ),
                              trailing: const Icon(
                                Icons.chevron_right,
                                color: Color(0xFFE6B450),
                              ),
                              onTap: () => Navigator.pushNamed(context, '/driver'),
                            ),
                            ListTile(
                              leading: const Icon(Icons.science_outlined),
                              title: Text(text),
                              subtitle: Text(
                                'Invite-only: ${cfg.inviteOnly ? 'Yes' : 'No'}  •  Test payments: ${cfg.paymentsTestOnly ? 'On' : 'Off'}',
                              ),
                            ),
                            ListTile(
                              leading: const Icon(Icons.copy_all_outlined),
                              title: const Text(
                                'Copy diagnostics to clipboard',
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () async {
                                final info =
                                    'betaBanner="${text.replaceAll('\n', ' ')}"\n'
                                    'inviteOnly=${cfg.inviteOnly}\n'
                                    'paymentsTestOnly=${cfg.paymentsTestOnly}\n'
                                    'shoppingFeatured=${cfg.shoppingFeaturedNames.join(',')}\n'
                                    'takeoutFeatured=${cfg.takeoutFeaturedIds.join(',')}';
                                await Clipboard.setData(
                                  ClipboardData(text: info),
                                );
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  appSnackBar('Diagnostics copied'),
                                );
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.restore_outlined),
                              title: const Text('Reset local preferences'),
                              subtitle: const Text(
                                'Clears notifications/quiet hours, tips, delivery notes',
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () async {
                                await PreferencesService.resetAll();
                                if (!mounted) return;
                                setState(() {
                                  _notifications = true;
                                  _mergeOnLogin = true;
                                  _reduceMotion = false;
                                  _highContrast = false;
                                  _biometricLock = false;
                                  _textScale = 1.0;
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  appSnackBar('Preferences reset'),
                                );
                              },
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 16),
                    // LEGAL
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                      child: Text(
                        'Legal',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Colors.white70,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    _groupCard(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.description),
                          title: const Text('Privacy Policy'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {},
                        ),
                        ListTile(
                          leading: const Icon(Icons.rule),
                          title: const Text('Terms of Service'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {},
                        ),
                        ListTile(
                          leading: const Icon(Icons.download),
                          title: const Text('Request Data Export'),
                          subtitle: const Text(
                            'Stub: would email you a data archive.',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _stub('Data export'),
                        ),
                        ListTile(
                          leading: const Icon(Icons.shield),
                          title: const Text('Request Data Deletion'),
                          subtitle: const Text(
                            'Stub: GDPR/CCPA style request.',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _stub('Data deletion'),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                    Text(
                      'Version 0.2.0',
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.white54),
                    ),
                  ],
                );
              },
            ),
    );
  }

  // Simple helper to render a rounded card with thin dividers.
  Widget _groupCard({required List<Widget> children}) {
    return Card(
      color: const Color(0xFF181818),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            children[i],
          ],
        ],
      ),
    );
  }

  Widget _navTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required String route,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.pushNamed(context, route),
    );
  }
}
