import 'package:flutter/material.dart';

class ShoppingPreferencesScreen extends StatefulWidget {
  const ShoppingPreferencesScreen({super.key});
  @override
  State<ShoppingPreferencesScreen> createState() =>
      _ShoppingPreferencesScreenState();
}

class _ShoppingPreferencesScreenState extends State<ShoppingPreferencesScreen> {
  String defaultStore = 'Walmart';
  final List<String> recentStores = ['Walmart'];
  bool glutenFreeFirst = false;
  bool hidePeanuts = false;
  bool hideTreeNuts = false;
  bool hideDairy = false;
  bool hideSoy = false;
  final Set<String> favoriteBrands = {'Great Value'};
  final Set<String> blockedBrands = <String>{};
  bool metricUnits = false;
  bool showUnitPrice = true;
  String defaultSort = 'price';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Shopping Preferences')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Default Store'),
            subtitle: Text(defaultStore),
            trailing: const Icon(Icons.storefront),
            onTap: () async {
              final selected = await showDialog<String>(
                context: context,
                builder: (_) => SimpleDialog(
                  title: const Text('Select Default Store'),
                  children: [
                    for (final s in {'Walmart'})
                      SimpleDialogOption(
                        onPressed: () => Navigator.pop(context, s),
                        child: Text(s),
                      ),
                  ],
                ),
              );
              if (selected != null) setState(() => defaultStore = selected);
            },
          ),
          ListTile(
            title: const Text('Recent Stores'),
            subtitle: Text(recentStores.join(', ')),
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Gluten-Free First'),
            value: glutenFreeFirst,
            onChanged: (v) => setState(() => glutenFreeFirst = v),
          ),
          SwitchListTile(
            title: const Text('Hide Peanuts'),
            value: hidePeanuts,
            onChanged: (v) => setState(() => hidePeanuts = v),
          ),
          SwitchListTile(
            title: const Text('Hide Tree Nuts'),
            value: hideTreeNuts,
            onChanged: (v) => setState(() => hideTreeNuts = v),
          ),
          SwitchListTile(
            title: const Text('Hide Dairy'),
            value: hideDairy,
            onChanged: (v) => setState(() => hideDairy = v),
          ),
          SwitchListTile(
            title: const Text('Hide Soy'),
            value: hideSoy,
            onChanged: (v) => setState(() => hideSoy = v),
          ),
          const Divider(),
          ListTile(
            title: const Text('Favorite Brands'),
            subtitle: Wrap(
              spacing: 4,
              children: [
                for (final b in favoriteBrands)
                  Chip(
                    label: Text(b),
                    onDeleted: () => setState(() => favoriteBrands.remove(b)),
                  ),
                ActionChip(
                  label: const Text('Add'),
                  onPressed: () async {
                    final brand = await _brandDialog();
                    if (brand != null)
                      setState(() => favoriteBrands.add(brand));
                  },
                ),
              ],
            ),
          ),
          ListTile(
            title: const Text('Blocked Brands'),
            subtitle: Wrap(
              spacing: 4,
              children: [
                for (final b in blockedBrands)
                  Chip(
                    label: Text(b),
                    onDeleted: () => setState(() => blockedBrands.remove(b)),
                  ),
                ActionChip(
                  label: const Text('Add'),
                  onPressed: () async {
                    final brand = await _brandDialog();
                    if (brand != null) setState(() => blockedBrands.add(brand));
                  },
                ),
              ],
            ),
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Metric Units'),
            value: metricUnits,
            onChanged: (v) => setState(() => metricUnits = v),
          ),
          SwitchListTile(
            title: const Text('Show Unit Price'),
            value: showUnitPrice,
            onChanged: (v) => setState(() => showUnitPrice = v),
          ),
          ListTile(
            title: const Text('Default Sorting'),
            subtitle: Text(defaultSort),
            trailing: const Icon(Icons.sort),
            onTap: () async {
              final sort = await showMenu<String>(
                context: context,
                position: const RelativeRect.fromLTRB(200, 200, 0, 0),
                items: const [
                  PopupMenuItem(value: 'price', child: Text('Price')),
                  PopupMenuItem(value: 'popularity', child: Text('Popularity')),
                  PopupMenuItem(
                    value: 'healthiness',
                    child: Text('Healthiness'),
                  ),
                ],
              );
              if (sort != null) setState(() => defaultSort = sort);
            },
          ),
        ],
      ),
    );
  }

  Future<String?> _brandDialog() async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Brand'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'Brand name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
