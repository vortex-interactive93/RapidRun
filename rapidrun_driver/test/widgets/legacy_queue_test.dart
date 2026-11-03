import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rapidrun_driver/presentation/home/incoming_offer_overlay.dart';

class _LegacyHarness extends StatefulWidget {
  const _LegacyHarness();
  @override
  State<_LegacyHarness> createState() => _LegacyHarnessState();
}

class _LegacyHarnessState extends State<_LegacyHarness> {
  final List<IncomingOfferData> _offers = [];
  IncomingOfferData? _active;

  @override
  void initState() {
    super.initState();
    // Seed two offers to trigger badge logic parity.
    _offers.addAll([
      const IncomingOfferData(
        id: 'o1',
        store: 'Store A',
        dropoffArea: 'Area',
        pay: 10,
        distanceMiles: 2.0,
        eta: Duration(minutes: 8),
        expiresIn: Duration(seconds: 30),
      ),
      const IncomingOfferData(
        id: 'o2',
        store: 'Store B',
        dropoffArea: 'Area',
        pay: 12,
        distanceMiles: 3.5,
        eta: Duration(minutes: 11),
        expiresIn: Duration(seconds: 30),
      ),
    ]);
    _active = _offers.first;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            if (_offers.length > 1 && _active != null)
              Align(
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                  height: 260,
                  child: IncomingOfferOverlay(
                    data: _active!,
                    onAccept: () async {
                      final removed = _active!;
                      setState(() {
                        _offers.removeWhere((o) => o.id == removed.id);
                        _active = _offers.isEmpty ? null : _offers.first;
                      });
                    },
                    onDecline: () async {
                      final removed = _active!;
                      setState(() {
                        _offers.removeWhere((o) => o.id == removed.id);
                        _active = _offers.isEmpty ? null : _offers.first;
                      });
                    },
                    onExpire: () {},
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

void main() {
  group('Legacy multi-offer queue (harness)', () {
    testWidgets('accept then decline reduces offers until empty', (
      tester,
    ) async {
      await tester.pumpWidget(const _LegacyHarness());
      // Initial overlay shows first offer store name
      expect(find.text('Store A'), findsOneWidget);
      // Tap Accept
      final acceptFinder = find.text('ACCEPT');
      expect(acceptFinder, findsOneWidget);
      await tester.tap(acceptFinder);
      await tester.pump();
      // Now first offer removed; second becomes active
      expect(find.text('Store A'), findsNothing);
      expect(find.text('Store B'), findsOneWidget);
      // Decline second
      final declineFinder = find.text('DECLINE');
      await tester.tap(declineFinder);
      await tester.pump();
      // All offers consumed -> overlay gone
      expect(find.text('Store B'), findsNothing);
    });
  });
}
