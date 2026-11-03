// File: rapidrun_driver/lib/widgets/alerts/driver_top_alert.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DriverTopAlert {
  static OverlayEntry? _currentEntry;

  /// Drops an obsidian alert pill from the top of the screen
  static void show(
    BuildContext context, {
    required String message,
    IconData icon = Icons.check_circle_rounded,
    Color accentColor = const Color(0xFF10B981),
    Duration duration = const Duration(milliseconds: 2500),
  }) {
    // Dismiss any active overlay immediately
    dismiss();
    HapticFeedback.mediumImpact();

    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (context) => _TopAlertWidget(
        message: message,
        icon: icon,
        accentColor: accentColor,
        onDismiss: dismiss,
      ),
    );

    _currentEntry = entry;
    overlay.insert(entry);

    Future.delayed(duration, () {
      if (_currentEntry == entry) {
        dismiss();
      }
    });
  }

  static void dismiss() {
    _currentEntry?.remove();
    _currentEntry = null;
  }
}

class _TopAlertWidget extends StatefulWidget {
  final String message;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onDismiss;

  const _TopAlertWidget({
    required this.message,
    required this.icon,
    required this.accentColor,
    required this.onDismiss,
  });

  @override
  State<_TopAlertWidget> createState() => _TopAlertWidgetState();
}

class _TopAlertWidgetState extends State<_TopAlertWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _offsetAnim = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      top: topPadding + 8,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _offsetAnim,
        child: GestureDetector(
          onVerticalDragUpdate: (details) {
            if (details.primaryDelta! < -4) widget.onDismiss();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF14171D), // Obsidian Surface
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: widget.accentColor.withValues(alpha: 0.5),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: widget.accentColor.withValues(alpha: 0.12),
                  blurRadius: 12,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: widget.accentColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(widget.icon, color: widget.accentColor, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.none,
                          fontFamily: 'sans-serif',
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
