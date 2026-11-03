import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rapidrun_driver/widgets/runtime_status_banner.dart';
import 'dart:async';
import 'package:rapidrun_driver/services/connectivity_permission_service.dart';

void main() {
  group('RuntimeStatusBanner', () {
    testWidgets('hidden when healthy (no banner)', (tester) async {
      final controller = StreamController<DriverRuntimeStatus>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RuntimeStatusBanner(
              statusStream: controller.stream,
              initialStatus: const DriverRuntimeStatus(
                online: true,
                locationGranted: true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byIcon(Icons.wifi_off), findsNothing);
      expect(find.byIcon(Icons.location_off), findsNothing);
      await controller.close();
    });

    testWidgets('shows offline message', (tester) async {
      final controller = StreamController<DriverRuntimeStatus>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RuntimeStatusBanner(
              statusStream: controller.stream,
              initialStatus: const DriverRuntimeStatus(
                online: true,
                locationGranted: true,
              ),
            ),
          ),
        ),
      );
      controller.add(
        const DriverRuntimeStatus(online: false, locationGranted: true),
      );
      await tester.pump();
      expect(find.byIcon(Icons.wifi_off), findsOneWidget);
      expect(find.textContaining('Offline'), findsOneWidget);
      await controller.close();
    });

    testWidgets('shows location permission message', (tester) async {
      final controller = StreamController<DriverRuntimeStatus>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RuntimeStatusBanner(
              statusStream: controller.stream,
              initialStatus: const DriverRuntimeStatus(
                online: true,
                locationGranted: true,
              ),
            ),
          ),
        ),
      );
      controller.add(
        const DriverRuntimeStatus(online: true, locationGranted: false),
      );
      await tester.pump();
      expect(find.byIcon(Icons.location_off), findsOneWidget);
      expect(find.textContaining('permission'), findsOneWidget);
      await controller.close();
    });

    testWidgets('shows combined offline + location message', (tester) async {
      final controller = StreamController<DriverRuntimeStatus>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RuntimeStatusBanner(
              statusStream: controller.stream,
              initialStatus: const DriverRuntimeStatus(
                online: true,
                locationGranted: true,
              ),
            ),
          ),
        ),
      );
      controller.add(
        const DriverRuntimeStatus(online: false, locationGranted: false),
      );
      await tester.pump();
      expect(find.byIcon(Icons.wifi_off), findsOneWidget);
      // Combined message contains 'Offline' and 'permission'
      expect(find.textContaining('Offline'), findsOneWidget);
      expect(find.textContaining('permission'), findsOneWidget);
      await controller.close();
    });
  });
}
