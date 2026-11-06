// File: lib/screens/shopping/cart_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:rapidrun_shared/rapidrun_shared.dart';
import '../checkout/checkout_screen.dart';
import '../cart/luxury_empty_cart_view.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final NumberFormat _currency = NumberFormat.simpleCurrency();

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFE6B450);

    return ListenableBuilder(
      listenable: cartState,
      builder: (context, _) {
        final items = cartState.items;
        final isEmpty = items.isEmpty;
        final subtotal = cartState.subtotal;

        return Scaffold(
          backgroundColor: const Color(0xFF1F1F1F),
          appBar: AppBar(
            backgroundColor: const Color(0xFF181818),
            iconTheme: const IconThemeData(color: gold),
            title: const Text(
              'Cart',
              style: TextStyle(color: gold, fontWeight: FontWeight.bold),
            ),
            actions: [
              if (!isEmpty)
                TextButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    cartState.clearCart();
                  },
                  child: const Text('Clear', style: TextStyle(color: gold)),
                ),
            ],
          ),
          body: isEmpty
              ? LuxuryEmptyCartView(
                  onExploreTapped: () {
                    HapticFeedback.mediumImpact();
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    }
                    navigationState.resetToHome();
                  },
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    if (index == items.length) {
                      return Card(
                        color: const Color(0xFF181818),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Total items',
                                style: TextStyle(color: Colors.white70),
                              ),
                              Text(
                                '${cartState.totalItemCount}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final item = items[index];
                    return Card(
                      color: const Color(0xFF181818),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: SizedBox(
                                width: 52,
                                height: 52,
                                child: item.imageUrl.isEmpty
                                    ? Container(
                                        color: Colors.black26,
                                        child: const Icon(
                                          Icons.shopping_bag,
                                          color: Colors.white54,
                                        ),
                                      )
                                    : Image.network(
                                        item.imageUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          color: Colors.black26,
                                          child: const Icon(
                                            Icons.broken_image,
                                            color: Colors.white54,
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Text(
                                        'Qty: ${item.quantity}',
                                        style: const TextStyle(
                                          color: Colors.white54,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        _currency.format(item.price * item.quantity),
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.remove_circle_outline,
                                    size: 20,
                                  ),
                                  color: gold,
                                  onPressed: () {
                                    cartState.updateQuantity(item.id, item.quantity - 1);
                                  },
                                ),
                                Text(
                                  '${item.quantity}',
                                  style: const TextStyle(color: Colors.white),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.add_circle_outline,
                                    size: 20,
                                  ),
                                  color: gold,
                                  onPressed: () {
                                    cartState.updateQuantity(item.id, item.quantity + 1);
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
          bottomNavigationBar: isEmpty
              ? null
              : SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Subtotal',
                              style: TextStyle(color: Colors.white70),
                            ),
                            Text(
                              _currency.format(subtotal),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: gold,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              final cartEntries = items.map((i) {
                                return {
                                  'id': i.id,
                                  'name': i.name,
                                  'quantity': i.quantity,
                                  'price': i.price,
                                  'aisle': 'Fragrance Wall • Bay 1',
                                };
                              }).toList();

                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CheckoutScreen(
                                    cartItems: cartEntries,
                                    subtotal: subtotal,
                                  ),
                                ),
                              );
                            },
                            child: Text('Checkout (${cartState.totalItemCount} items)'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }
}
