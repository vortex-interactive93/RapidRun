// File: lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'services/firebase_service.dart';
import 'services/theme_service.dart';
import 'services/favorites_cart_service.dart';
import 'services/user_preferences_service.dart';
import 'services/data_seeder_service.dart';
import 'core/app_router.dart';
import 'services/display_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  try {
    await FirebaseService.initialize();
    DataSeederService.seedAllCatalogs();
  } catch (e) {
    debugPrint('[RapidRun] Firebase initialization warning: $e');
  }

  try {
    FavoritesService.instance.bootstrap();
    CartService.instance.bootstrap();
    await UserPreferencesService.instance.bootstrap();
    await DisplayPreferences.instance.load();
  } catch (e) {
    debugPrint('[RapidRun] Bootstrap warning: $e');
  }

  runApp(
    const ProviderScope(
      child: RapidRunBootstrap(initOk: true),
    ),
  );
}

class RapidRunBootstrap extends StatelessWidget {
  final bool initOk;
  final String? error;
  const RapidRunBootstrap({super.key, required this.initOk, this.error});

  @override
  Widget build(BuildContext context) {
    if (!initOk) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeService.getThemeData(),
        home: Scaffold(
          appBar: AppBar(title: const Text('RapidRun')),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error, color: Colors.red, size: 48),
                const SizedBox(height: 12),
                const Text('Initialization failed'),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(error!, style: const TextStyle(fontSize: 12)),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return ValueListenableBuilder<DisplayPrefsState>(
      valueListenable: DisplayPreferences.instance,
      builder: (context, prefs, _) {
        final baseTheme = ThemeService.getThemeData();
        ThemeData adjusted = prefs.highContrast
            ? baseTheme.copyWith(
                colorScheme: baseTheme.colorScheme.copyWith(
                  primary: Colors.amberAccent,
                  secondary: Colors.lightBlueAccent,
                  surface: const Color(0xFF101010),
                ),
              )
            : baseTheme;

        if (prefs.textScale != 1.0) {
          adjusted = adjusted.copyWith(
            textTheme: adjusted.textTheme.apply(
              fontSizeFactor: prefs.textScale,
            ),
          );
        }

        return MaterialApp(
          title: 'RapidRun',
          debugShowCheckedModeBanner: false,
          theme: adjusted,
          initialRoute: AppRoute.home.path,
          onGenerateRoute: AppRoute.onGenerate,
        );
      },
    );
  }
}
