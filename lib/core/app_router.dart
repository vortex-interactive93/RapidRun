import 'package:flutter/material.dart';
import '../screens/shell/bottom_nav_shell.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/complete_profile_screen.dart';
import '../screens/auth/onboarding_flow.dart';
import '../screens/auth/secure_setup_screen.dart';
import '../screens/diagnostics/diagnostics_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/profile/favorites_screen.dart';
import '../screens/shopping/cart_screen.dart';
import '../screens/takeout/takeout_screen.dart';
import '../screens/shopping_delivery/shopping_delivery_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/orders/order_history_screen.dart';
import '../screens/settings/personal_details_screen.dart';
import '../screens/checkout/checkout_gate_screen.dart';
import '../screens/search/store_search_screen.dart';
import '../screens/settings/address_book_screen.dart';
import '../screens/settings/notification_preferences_screen.dart';
import '../screens/settings/shopping_preferences_screen.dart';
import '../screens/settings/accessibility_preferences_screen.dart';
import '../screens/settings/privacy_data_screen.dart';
import '../screens/settings/payment_methods_screen.dart';
import '../screens/product_detail_screen.dart';
import '../screens/driver/driver_mode_screen.dart';

/// Central route enum to avoid stringly-typed navigation.
/// Use: Navigator.pushNamed(context, AppRoute.login.path)
/// or: Navigator.push(context, AppRoute.login.materialPageRoute());
enum AppRoute {
  home('/'),
  login('/login'),
  completeProfile('/complete-profile'),
  onboarding('/onboarding'),
  secureSetup('/secure-setup'),
  diagnostics('/diagnostics'),
  profile('/profile'),
  favorites('/favorites'),
  shopping('/shopping'),
  cart('/cart'),
  takeout('/takeout'),
  settings('/settings'),
  personalSettings('/settings/personal'),
  addressBook('/settings/addresses'),
  notificationPrefs('/settings/notifications'),
  shoppingPrefs('/settings/shopping-prefs'),
  accessibilityPrefs('/settings/accessibility'),
  privacyData('/settings/privacy-data'),
  paymentMethods('/settings/payments'),
  orders('/orders'),
  checkoutGate('/checkout-gate'),
  driver('/driver');

  final String path;
  const AppRoute(this.path);

  static Route<dynamic>? onGenerate(RouteSettings settings) {
    // First attempt enum match (static routes)
    final match = AppRoute.values
        .where((r) => r.path == settings.name)
        .firstOrNull;
    if (match != null) {
      return match.materialPageRoute(settings: settings);
    }
    // Dynamic routes: /store-search/<store>
    if (settings.name != null && settings.name!.startsWith('/store-search/')) {
      final store = settings.name!.substring('/store-search/'.length);
      return MaterialPageRoute(
        builder: (_) => StoreSearchScreen(store: store),
        settings: settings,
      );
    }
    // Product detail route (marketing wrappers & general product taps)
    if (settings.name == '/product') {
      final args = settings.arguments;
      String? id;
      String? name;
      double? price;
      String? brand;
      String? imageUrl;
      String description = '';
      String? unit;
      String? unitShort;
      bool bundleContext = false;
      String? wrapperId;
      Map<String, dynamic>? nutritionRaw;
      if (args is Map) {
        id = args['id']?.toString();
        name = args['name']?.toString();
        final p = args['price'];
        if (p is num) price = p.toDouble();
        brand = args['brand']?.toString();
        imageUrl = args['imageUrl']?.toString();
        description = (args['description'] ?? '').toString();
        unit = args['unit']?.toString();
        unitShort = args['unitShort']?.toString();
        bundleContext = args['bundleContext'] == true;
        wrapperId = args['wrapperId']?.toString();
        if (args['nutritionRaw'] is Map) {
          nutritionRaw = (args['nutritionRaw'] as Map).cast<String, dynamic>();
        }
      }
      if (id == null) {
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('Unknown Product')),
            body: const Center(child: Text('Missing product id.')),
          ),
          settings: settings,
        );
      }
      return MaterialPageRoute(
        builder: (_) => ProductDetailScreen(
          id: id!,
          name: name ?? 'Product',
          brand: brand,
          imageUrl: imageUrl,
          description: description,
          price: price,
          unit: unit,
          unitShort: unitShort,
          bundleContext: bundleContext,
          wrapperId: wrapperId,
          nutritionRaw: nutritionRaw,
        ),
        settings: settings,
      );
    }
    return null;
  }

  MaterialPageRoute materialPageRoute({RouteSettings? settings}) {
    return MaterialPageRoute(
      builder: (_) => _builder(),
      settings: settings ?? RouteSettings(name: path),
    );
  }

  Widget _builder() {
    switch (this) {
      case AppRoute.home:
        return const BottomNavShell();
      case AppRoute.login:
        return const LoginScreen();
      case AppRoute.completeProfile:
        return const CompleteProfileScreen();
      case AppRoute.onboarding:
        return const OnboardingFlow();
      case AppRoute.secureSetup:
        return const SecureSetupScreen();
      case AppRoute.diagnostics:
        return const DiagnosticsScreen();
      case AppRoute.profile:
        return const ProfileScreen();
      case AppRoute.favorites:
        return const FavoritesScreen();
      case AppRoute.shopping:
        return const ShoppingDeliveryScreen();
      case AppRoute.cart:
        return const CartScreen();
      case AppRoute.takeout:
        return const TakeoutScreen();
      case AppRoute.settings:
        return const SettingsScreen();
      case AppRoute.personalSettings:
        return const PersonalDetailsScreen();
      case AppRoute.addressBook:
        return const AddressBookScreen();
      case AppRoute.notificationPrefs:
        return const NotificationPreferencesScreen();
      case AppRoute.shoppingPrefs:
        return const ShoppingPreferencesScreen();
      case AppRoute.accessibilityPrefs:
        return const AccessibilityPreferencesScreen();
      case AppRoute.privacyData:
        return const PrivacyDataScreen();
      case AppRoute.paymentMethods:
        return const PaymentMethodsScreen();
      case AppRoute.orders:
        return const OrderHistoryScreen();
      case AppRoute.checkoutGate:
        return const CheckoutGateScreen();
      case AppRoute.driver:
        return const DriverModeScreen(
          driverId: 'test_driver',
          name: 'RapidRun Courier',
        );
    }
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
