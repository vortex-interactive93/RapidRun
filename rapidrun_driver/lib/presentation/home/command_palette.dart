import 'package:flutter/material.dart';
import 'package:rapidrun_driver/theme/design_tokens.dart';

/// A compact horizontal command palette replacing the vertical rail.
/// Sits top-right, minimal visual weight. Expands into a pill with icons only.
class CommandPalette extends StatelessWidget {
  final VoidCallback? onMenu;
  final VoidCallback? onMetrics;
  final VoidCallback? onInfo;
  final VoidCallback? onRecenter;
  final VoidCallback? onToggleBloom;
  final bool bloomActive;
  final bool enableBloom;

  const CommandPalette({
    super.key,
    this.onMenu,
    this.onMetrics,
    this.onInfo,
    this.onRecenter,
    this.onToggleBloom,
    this.bloomActive = false,
    this.enableBloom = false,
  });

  @override
  Widget build(BuildContext context) {
    final buttons = <_CmdButtonSpec>[
      _CmdButtonSpec(icon: Icons.menu, tooltip: 'Menu', onTap: onMenu),
      _CmdButtonSpec(
        icon: Icons.bar_chart_rounded,
        tooltip: 'Metrics',
        onTap: onMetrics,
      ),
      if (enableBloom)
        _CmdButtonSpec(
          icon: Icons.local_fire_department_rounded,
          tooltip: bloomActive ? 'Disable Bloom' : 'Enable Bloom',
          onTap: onToggleBloom,
          active: bloomActive,
        ),
      _CmdButtonSpec(icon: Icons.info_outline, tooltip: 'Info', onTap: onInfo),
      _CmdButtonSpec(
        icon: Icons.gps_fixed,
        tooltip: 'Center Map',
        onTap: onRecenter,
      ),
    ];

    return Semantics(
      label: 'Command palette',
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.35),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
          boxShadow: const [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final b in buttons) ...[
                _CmdButton(spec: b),
                if (b != buttons.last) const SizedBox(width: 4),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CmdButtonSpec {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool active;
  _CmdButtonSpec({
    required this.icon,
    required this.tooltip,
    this.onTap,
    this.active = false,
  });
}

class _CmdButton extends StatelessWidget {
  final _CmdButtonSpec spec;
  const _CmdButton({required this.spec});

  @override
  Widget build(BuildContext context) {
    final active = spec.active;
    return Semantics(
      label: spec.tooltip,
      button: true,
      child: Tooltip(
        message: spec.tooltip,
        waitDuration: const Duration(milliseconds: 600),
        child: InkWell(
          onTap: spec.onTap,
          customBorder: const CircleBorder(),
          splashColor: DesignTokens.primary.withOpacity(0.25),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOut,
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: active
                  ? LinearGradient(
                      colors: [
                        DesignTokens.bloomCore.withOpacity(0.95),
                        DesignTokens.bloomHot.withOpacity(0.9),
                      ],
                    )
                  : LinearGradient(
                      colors: [
                        DesignTokens.primary.withOpacity(0.95),
                        DesignTokens.secondary.withOpacity(0.9),
                      ],
                    ),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: DesignTokens.bloomHot.withOpacity(0.55),
                        blurRadius: 18,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: Icon(spec.icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}
