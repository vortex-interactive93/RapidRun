// File: lib/widgets/navigation/breadcrumb_back_button.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BreadcrumbBackButton extends StatelessWidget {
  final List<String> stackTitles;

  const BreadcrumbBackButton({
    super.key,
    this.stackTitles = const ['Home', 'Bath & Body Works', 'Body Care'],
  });

  void _showStackJumpSheet(BuildContext context) {
    HapticFeedback.heavyImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF14171D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'JUMP TO PREVIOUS SCREEN',
              style: TextStyle(
                color: Color(0xFFE5A93C),
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            ...List.generate(stackTitles.length, (index) {
              final title = stackTitles[index];
              final isHome = index == 0;
              return ListTile(
                leading: Icon(
                  isHome ? Icons.home_rounded : Icons.subdirectory_arrow_left_rounded,
                  color: isHome ? const Color(0xFFE5A93C) : Colors.white60,
                ),
                title: Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: isHome ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  if (isHome) {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  } else {
                    final int popsNeeded = stackTitles.length - 1 - index;
                    for (int i = 0; i < popsNeeded; i++) {
                      Navigator.of(context).pop();
                    }
                  }
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () => _showStackJumpSheet(context),
      child: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70, size: 20),
        onPressed: () => Navigator.of(context).pop(),
      ),
    );
  }
}
