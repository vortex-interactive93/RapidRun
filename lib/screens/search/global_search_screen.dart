import 'package:flutter/material.dart';
import '../../services/favorites_cart_service.dart';
import '../../models/product.dart';

/// Lightweight global search placeholder.
class GlobalSearchScreen extends StatefulWidget {
  const GlobalSearchScreen({super.key});
  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final products = ProductRepository.sampleProducts;
    final matches = _query.trim().isEmpty
        ? const <Product>[]
        : products
              .where((p) => p.name.toLowerCase().contains(_query.toLowerCase()))
              .toList();
    return Scaffold(
      backgroundColor: const Color(0xFF1f1f1f),
      appBar: AppBar(
        backgroundColor: const Color(0xFF181818),
        title: TextField(
          controller: _controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Search products',
            hintStyle: TextStyle(color: Colors.white54),
            border: InputBorder.none,
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
        actions: [
          if (_query.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _controller.clear();
                setState(() => _query = '');
              },
            ),
        ],
      ),
      body: _query.isEmpty
          ? const _EmptyHint()
          : matches.isEmpty
          ? const _NoResults()
          : ListView.separated(
              itemCount: matches.length,
              separatorBuilder: (_, __) => const Divider(height: 0),
              itemBuilder: (context, i) {
                final p = matches[i];
                final inCart = CartService.instance.quantityFor(p.id) > 0;
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  title: Text(
                    p.name,
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    p.store ?? '',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  trailing: Text(
                    p.price == null ? '' : '\$${p.price!.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Color(0xFFe6b450),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF333333),
                    child: Text(p.name.isNotEmpty ? p.name[0] : '?'),
                  ),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Open details for ${p.name} (placeholder)',
                        ),
                      ),
                    );
                  },
                  onLongPress: () {
                    CartService.instance.add(p.id, 1);
                    setState(() {});
                  },
                  selected: inCart,
                );
              },
            ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint();
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.search, color: Colors.white38, size: 56),
          SizedBox(height: 16),
          Text(
            'Start typing to search products',
            style: TextStyle(color: Colors.white54),
          ),
        ],
      ),
    ),
  );
}

class _NoResults extends StatelessWidget {
  const _NoResults();
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.search_off, color: Colors.white38, size: 56),
          SizedBox(height: 16),
          Text('No matching products', style: TextStyle(color: Colors.white54)),
        ],
      ),
    ),
  );
}
