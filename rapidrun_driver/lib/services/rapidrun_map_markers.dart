// File: rapidrun_driver/lib/services/rapidrun_map_markers.dart

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Generates crisp custom-painted BitmapDescriptors for RapidRun partner stores
/// & 3D vehicle navigation pucks so our UI stands out on the dark-titanium map.
class RapidRunMapMarkers {
  RapidRunMapMarkers._();

  static BitmapDescriptor? _cachedStorePin;
  static BitmapDescriptor? _cachedDriverPuck;

  static Future<BitmapDescriptor> getPartnerStoreMarker() async {
    if (_cachedStorePin != null) return _cachedStorePin!;

    const double size = 128.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const center = Offset(size / 2, size / 2 - 6);

    const gold = Color(0xFFE6B450);
    const obsidian = Color(0xFF14171E);

    // 1. Subtle outer gold ambient halo
    final haloPaint = Paint()
      ..color = gold.withValues(alpha: 0.24)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 46, haloPaint);

    // 2. Dark obsidian circular badge
    final bgPaint = Paint()
      ..color = obsidian
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 34, bgPaint);

    // 3. Signature RapidRun gold border ring
    final ringPaint = Paint()
      ..color = gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5;
    canvas.drawCircle(center, 34, ringPaint);

    // 4. Bottom pointer triangle so pin anchors accurately to store coordinates
    final pointerPath = Path()
      ..moveTo(center.dx - 11, center.dy + 31)
      ..lineTo(center.dx + 11, center.dy + 31)
      ..lineTo(center.dx, center.dy + 46)
      ..close();
    canvas.drawPath(pointerPath, Paint()..color = gold);

    // 5. Crisp storefront/shopping bag icon drawn inside the badge
    final iconPainter = TextPainter(textDirection: TextDirection.ltr);
    const iconData = Icons.storefront_rounded;
    iconPainter.text = TextSpan(
      text: String.fromCharCode(iconData.codePoint),
      style: TextStyle(
        fontSize: 34,
        fontFamily: iconData.fontFamily,
        package: iconData.fontPackage,
        color: gold,
      ),
    );
    iconPainter.layout();
    iconPainter.paint(
      canvas,
      Offset(
        center.dx - iconPainter.width / 2,
        center.dy - iconPainter.height / 2,
      ),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    _cachedStorePin = BitmapDescriptor.bytes(
      byteData!.buffer.asUint8List(),
      width: 52,
      height: 52,
    );
    return _cachedStorePin!;
  }

  static Future<BitmapDescriptor> getDriverNavigationPuck() async {
    if (_cachedDriverPuck != null) return _cachedDriverPuck!;

    const double size = 128.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const center = Offset(size / 2, size / 2);

    const gold = Color(0xFFE6B450);
    const obsidian = Color(0xFF12151C);

    // 1. Soft gold radar halo
    canvas.drawCircle(
      center,
      54,
      Paint()..color = gold.withValues(alpha: 0.22),
    );

    // 2. Crisp obsidian puck base with gold rim
    canvas.drawCircle(center, 36, Paint()..color = obsidian);
    canvas.drawCircle(
      center,
      36,
      Paint()
        ..color = gold
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.5,
    );

    // 3. Forward directional chevron pointing UP (0° north, rotated by Marker.rotation)
    final chevron = Path()
      ..moveTo(center.dx, center.dy - 21)
      ..lineTo(center.dx + 16, center.dy + 13)
      ..lineTo(center.dx, center.dy + 5)
      ..lineTo(center.dx - 16, center.dy + 13)
      ..close();
    canvas.drawPath(chevron, Paint()..color = gold);

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    _cachedDriverPuck = BitmapDescriptor.bytes(
      byteData!.buffer.asUint8List(),
      width: 48,
      height: 48,
    );
    return _cachedDriverPuck!;
  }
}
