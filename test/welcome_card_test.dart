import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rapidrun/screens/home/widgets/welcome_card.dart';

void main() {
  testWidgets('WelcomeCard builds inside scroll view without layout errors', (
    tester,
  ) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Pump inside MaterialApp + Scaffold + SingleChildScrollView to mimic usage.
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: WelcomeCard())),
      ),
    );
    // Allow a frame.
    await tester.pump();
    // Expect icon and text present.
    expect(find.byIcon(Icons.local_shipping), findsOneWidget);
    expect(find.text('Welcome to RapidRun'), findsOneWidget);
  });
}
