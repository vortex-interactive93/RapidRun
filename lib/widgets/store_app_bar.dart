import 'package:flutter/material.dart';
import 'reactive_cart_badge.dart';

/// A standardized AppBar used across store browsing screens.
/// Provides consistent gold styling (via theme), optional cart badge,
/// and a slot for extra actions.
class StoreAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? extraActions;
  final bool showCartBadge;
  final bool centerTitle;
  final VoidCallback? onSearch;
  final bool showSearch;

  const StoreAppBar({
    super.key,
    required this.title,
    this.extraActions,
    this.showCartBadge = true,
    this.centerTitle = false,
    this.onSearch,
    this.showSearch = false,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final iconColor =
        Theme.of(context).appBarTheme.iconTheme?.color ??
        const Color(0xFFE6B450);
    return AppBar(
      centerTitle: centerTitle,
      title: Text(title),
      actions: [
        if (showSearch)
          IconButton(
            tooltip: 'Search',
            icon: const Icon(Icons.search),
            onPressed: onSearch,
          ),
        if (showCartBadge)
          ReactiveCartBadge(
            onPressed: () => Navigator.pushNamed(context, '/cart'),
            iconColor: iconColor,
          ),
        if (extraActions != null) ...extraActions!,
      ],
    );
  }
}
