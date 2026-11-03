import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/product.dart';
import '../../services/favorites_cart_service.dart';
import '../reactive_cart_badge.dart';

class ProductOptionsSheet extends StatefulWidget {
  final Product product;

  const ProductOptionsSheet({super.key, required this.product});

  @override
  State<ProductOptionsSheet> createState() => _ProductOptionsSheetState();
}

class _ProductOptionsSheetState extends State<ProductOptionsSheet> {
  int _quantity = 1;
  ModifierOption? _selectedOption;
  bool _isAdding = false;
  // Track selections for all modifier groups
  final Map<String, Set<ModifierOption>> _selectedOptionsByGroup = {};

  // Find the size modifier group robustly by id or name

  @override
  void initState() {
    super.initState();
    // Initialize selections for all modifier groups
    for (final group in widget.product.modifiers) {
      final selected = <ModifierOption>{};
      if (group.selection.toLowerCase() == 'single') {
        final def = group.options.firstWhere(
          (o) => o.isDefault,
          orElse: () => group.options.first,
        );
        selected.add(def);
        if (group.id.toLowerCase() == 'size') {
          _selectedOption = def;
        }
      }
      _selectedOptionsByGroup[group.id] = selected;
    }
  }

  void _increment() {
    setState(() {
      _quantity++;
    });
  }

  void _decrement() {
    if (_quantity > 1) {
      setState(() {
        _quantity--;
      });
    }
  }

  Future<void> _addToCart() async {
    if (_isAdding) return;
    setState(() => _isAdding = true);

    try {
      // If an option is selected, create a product variant.
      if (_selectedOption != null) {
        final productToAdd = _createProductVariant(
          widget.product,
          _selectedOption!,
        );
        await CartService.instance.addVariant(productToAdd, _quantity);
      } else {
        // Otherwise, add the base product.
        await CartService.instance.add(widget.product.id, _quantity);
      }

      HapticFeedback.lightImpact();
      CartBadgePulse.pulse();
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Failed to add item to cart: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
        setState(() => _isAdding = false);
      }
    }
  }

  Product _createProductVariant(Product baseProduct, ModifierOption option) {
    return Product(
      id: '${baseProduct.id}_${option.id}',
      name: '${baseProduct.name} (${option.name})',
      price: (baseProduct.price ?? 0) + (option.priceDelta ?? 0),
      imageUrl: baseProduct.imageUrl,
      store: baseProduct.store,
      category: baseProduct.category,
      // Copy other fields as necessary
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final price =
        (widget.product.price ?? 0) + (_selectedOption?.priceDelta ?? 0);
    final screenH = MediaQuery.of(context).size.height;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(top: 8, left: 0, right: 0, bottom: 0),
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 0),
          constraints: BoxConstraints(
            // Keep the sheet at roughly ~60% of screen height like the screenshot
            maxHeight: screenH * 0.62,
          ),
          decoration: const BoxDecoration(
            color: Colors.black, // dark simple sheet
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              // Drag handle
              const SizedBox(height: 8),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20.0,
                      vertical: 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Product Image (hero)
                        if (widget.product.imageUrl != null)
                          Center(
                            child: Hero(
                              tag:
                                  'product:${(widget.product.store ?? 'unknown').toLowerCase().replaceAll(' ', '_')}:${widget.product.id}',
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(18),
                                child: Image.network(
                                  widget.product.imageUrl!,
                                  height: 240,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 18),
                        // Product Name
                        Text(
                          widget.product.name,
                          style:
                              theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 24,
                                letterSpacing: 0.1,
                              ) ??
                              const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 10),
                        // Show all modifiers
                        for (final group in widget.product.modifiers)
                          if (group.options.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    group.name,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 8),
                                  if (group.selection.toLowerCase() == 'single')
                                    SegmentedButton<ModifierOption>(
                                      style: SegmentedButton.styleFrom(
                                        minimumSize: const Size(0, 44),
                                        tapTargetSize:
                                            MaterialTapTargetSize.padded,
                                      ),
                                      segments: group.options
                                          .map(
                                            (
                                              option,
                                            ) => ButtonSegment<ModifierOption>(
                                              value: option,
                                              label: Text(
                                                option.priceDelta != null &&
                                                        option.priceDelta != 0
                                                    ? '${option.name} +\$${option.priceDelta!.toStringAsFixed(2)}'
                                                    : option.name,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                      selected:
                                          _selectedOptionsByGroup[group.id] ??
                                          {},
                                      onSelectionChanged: (newSelection) {
                                        setState(() {
                                          _selectedOptionsByGroup[group.id] =
                                              newSelection;
                                          if (group.id.toLowerCase() ==
                                              'size') {
                                            _selectedOption =
                                                newSelection.first;
                                          }
                                        });
                                      },
                                    )
                                  else
                                    Wrap(
                                      spacing: 8,
                                      children: group.options.map((option) {
                                        final selected =
                                            _selectedOptionsByGroup[group.id]
                                                ?.contains(option) ??
                                            false;
                                        return FilterChip(
                                          label: Text(option.name),
                                          selected: selected,
                                          onSelected: (val) {
                                            setState(() {
                                              final set =
                                                  _selectedOptionsByGroup[group
                                                      .id] ??
                                                  <ModifierOption>{};
                                              if (val) {
                                                set.add(option);
                                              } else {
                                                set.remove(option);
                                              }
                                              _selectedOptionsByGroup[group
                                                      .id] =
                                                  set;
                                            });
                                          },
                                        );
                                      }).toList(),
                                    ),
                                ],
                              ),
                            ),
                      ],
                    ),
                  ),
                ),
              ),
              // Sticky bottom section
              const Divider(height: 1, color: Colors.white10),
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 8.0,
                  horizontal: 20,
                ),
                child: Column(
                  children: [
                    // Quantity Selector
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: _decrement,
                        ),
                        Text('$_quantity', style: theme.textTheme.titleLarge),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: _increment,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Add to Order Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE6B450),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _addToCart,
                        child: _isAdding
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black,
                                ),
                              )
                            : Text(
                                'Add to Order - \$${(price * _quantity).toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ), // end main Column
        ), // end Container
      ), // end Padding
    ); // end SafeArea
  }
}
