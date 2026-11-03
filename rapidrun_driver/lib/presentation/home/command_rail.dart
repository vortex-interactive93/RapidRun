import 'package:flutter/material.dart';
import 'package:rapidrun_driver/theme/design_tokens.dart';

/// Collapsible vertical command rail – Phase 1 scaffold.
/// Future: dynamic badges, unread indicators, radial expansion, personalization.
class CommandRail extends StatefulWidget {
  final bool expandedInitially;
  final VoidCallback? onMenu;
  final VoidCallback? onMetrics;
  final VoidCallback? onInfo;
  final VoidCallback? onRecenter;
  final VoidCallback? onToggleBloom;
  final bool bloomActive;

  const CommandRail({
    super.key,
    this.expandedInitially = false,
    this.onMenu,
    this.onMetrics,
    this.onInfo,
    this.onRecenter,
    this.onToggleBloom,
    this.bloomActive = false,
  });

  @override
  State<CommandRail> createState() => _CommandRailState();
}

class _CommandRailState extends State<CommandRail> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.expandedInitially;
  }

  void _toggle() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    final items = [
      _RailItem(icon: Icons.menu, label: 'Menu', onTap: widget.onMenu),
      _RailItem(
        icon: Icons.bar_chart_rounded,
        label: 'Metrics',
        onTap: widget.onMetrics,
      ),
      _RailItem(
        icon: Icons.local_fire_department_rounded,
        label: 'Bloom',
        onTap: widget.onToggleBloom,
        active: widget.bloomActive,
      ),
      _RailItem(icon: Icons.info_outline, label: 'Info', onTap: widget.onInfo),
      _RailItem(
        icon: Icons.gps_fixed,
        label: 'Center',
        onTap: widget.onRecenter,
      ),
    ];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      width: _expanded ? 168 : 62, // reduced to avoid orb overlap
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.08),
            Colors.white.withOpacity(0.02),
          ],
        ),
        color: Colors.white.withOpacity(0.06),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(26),
          bottomRight: Radius.circular(26),
          topLeft: Radius.circular(20),
          bottomLeft: Radius.circular(20),
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 22,
            offset: Offset(0, 6),
          ),
        ],
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
      ),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: _toggle,
              child: AnimatedRotation(
                turns: _expanded ? 0.0 : 0.25,
                duration: const Duration(milliseconds: 360),
                curve: Curves.easeOutBack,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.all(6),
                  child: const Icon(
                    Icons.chevron_left,
                    color: Colors.white70,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (final item in items) ...[
            _RailButton(expanded: _expanded, item: item),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _RailItem {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;
  _RailItem({
    required this.icon,
    required this.label,
    this.onTap,
    this.active = false,
  });
}

class _RailButton extends StatelessWidget {
  final bool expanded;
  final _RailItem item;
  const _RailButton({required this.expanded, required this.item});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: DesignTokens.primary.withOpacity(0.2),
        highlightColor: Colors.white.withOpacity(0.05),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
          padding: EdgeInsets.symmetric(
            vertical: 12,
            horizontal: expanded ? 16 : 0,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.07), width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: item.active
                        ? [
                            DesignTokens.bloomCore.withOpacity(0.95),
                            DesignTokens.bloomHot.withOpacity(0.9),
                          ]
                        : [
                            DesignTokens.primary.withOpacity(0.9),
                            DesignTokens.secondary.withOpacity(0.9),
                          ],
                  ),
                  boxShadow: item.active
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
                child: Icon(item.icon, color: Colors.white, size: 18),
              ),
              if (expanded) ...[
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    item.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.35,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
