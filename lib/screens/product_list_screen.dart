import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/rendering.dart';

import '../widgets/store_app_bar.dart';
import '../models/product.dart';
import '../widgets/product/product_card_v2.dart';
import '../widgets/product/product_options_sheet.dart';
import '../widgets/product/quick_add_product_card.dart';
import '../widgets/product/balanced_plate_dialog.dart';
import '../services/favorites_cart_service.dart';
import '../widgets/mini_cart_bar.dart';

class ProductListScreen extends StatefulWidget {
  final String category;
  final String? subCategory;
  final String? title;
  final List<String>? fileOverrides;
  const ProductListScreen({
    Key? key,
    required this.category,
    this.subCategory,
    this.title,
    this.fileOverrides,
  }) : super(key: key);

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  static const _gold = Color(0xFFE6B450);
  static const _bg = Color(0xFF1f1f1f);

  final ScrollController _scroll = ScrollController();
  final TextEditingController _searchC = TextEditingController();
  bool _showSearch = true;
  bool _loading = true;
  List<Map<String, dynamic>> _raw = [];
  List<Map<String, dynamic>> _filtered = [];
  List<_IndexedProduct> _index = [];
  String? _selectedAppetizerId; // currently expanded appetizer for quick add
  String _selectedAisle = 'All';

  bool get _isFragranceCategory {
    final cat = widget.category.toLowerCase();
    final sub = (widget.subCategory ?? '').toLowerCase();
    final title = (widget.title ?? '').toLowerCase();
    final files = (widget.fileOverrides ?? []).map((f) => f.toLowerCase()).toList();

    if (cat.contains("men's") || sub.contains("men's") || title.contains("men's")) {
      return false;
    }

    return (cat == 'fragrance' || sub == 'fragrance' || title == 'fragrance') ||
        files.any((f) => f.contains('body_care/fragrance/fragrance.json'));
  }

  bool get _isMoisturizersCategory {
    final sub = (widget.subCategory ?? '').toLowerCase();
    final title = (widget.title ?? '').toLowerCase();
    final files = (widget.fileOverrides ?? []).map((f) => f.toLowerCase()).toList();
    return sub.contains('moisturizers') ||
        title.contains('moisturizers') ||
        files.any((f) => f.contains('moisturizers.json'));
  }

  bool get _isBathShowerCategory {
    final sub = (widget.subCategory ?? '').toLowerCase();
    final title = (widget.title ?? '').toLowerCase();
    final files = (widget.fileOverrides ?? []).map((f) => f.toLowerCase()).toList();
    return sub.contains('bath & shower') ||
        sub.contains('bath_shower') ||
        title.contains('bath & shower') ||
        files.any((f) => f.contains('bbw_body_wash.json') || f.contains('bbw_body_scrub.json'));
  }

  bool get _isMinisCategory {
    final sub = (widget.subCategory ?? '').toLowerCase();
    final title = (widget.title ?? '').toLowerCase();
    final files = (widget.fileOverrides ?? []).map((f) => f.toLowerCase()).toList();
    return sub.contains('mini') ||
        sub.contains('travel') ||
        title.contains('mini') ||
        title.contains('travel') ||
        files.any((f) => f.contains('travel_minis.json'));
  }

  bool get _isCandlesCategory {
    final cat = widget.category.toLowerCase();
    final title = (widget.title ?? '').toLowerCase();
    final files = (widget.fileOverrides ?? []).map((f) => f.toLowerCase()).toList();
    return cat.contains('candle') ||
        title.contains('candle') ||
        files.any((f) => f.contains('candle'));
  }

  bool get _isRoomSpraysCategory {
    final sub = (widget.subCategory ?? '').toLowerCase();
    final title = (widget.title ?? '').toLowerCase();
    final files = (widget.fileOverrides ?? []).map((f) => f.toLowerCase()).toList();
    return sub.contains('room spray') ||
        sub.contains('room mist') ||
        title.contains('room spray') ||
        title.contains('room mist') ||
        files.any((f) => f.contains('bbw_room_sprays_mists.json'));
  }

  bool get _isCarFragranceCategory {
    final sub = (widget.subCategory ?? '').toLowerCase();
    final title = (widget.title ?? '').toLowerCase();
    final files = (widget.fileOverrides ?? []).map((f) => f.toLowerCase()).toList();
    return sub.contains('car fragrance') ||
        sub.contains('car air freshener') ||
        title.contains('car fragrance') ||
        title.contains('car air freshener') ||
        files.any((f) => f.contains('bbw_car_fragrance.json'));
  }

  bool get _isAllMensBodyCareCategory {
    final sub = (widget.subCategory ?? '').toLowerCase();
    final title = (widget.title ?? '').toLowerCase();
    final files = (widget.fileOverrides ?? []).map((f) => f.toLowerCase()).toList();
    return sub.contains("all men's body care") ||
        title.contains("all men's body care") ||
        (files.any((f) => f.contains('bbw_mens_body_care.json')) &&
            files.any((f) => f.contains('bbw_mens_fragrance.json')));
  }

  List<String> get _aisles {
    if (_isAllMensBodyCareCategory) {
      return const [
        'All',
        'Bar Soap',
        'Body Cream',
        'Body Spray & Mist',
        'Body Wash & Shower Gel',
        'Cologne',
        'Deodorant',
        'Mini Cologne',
      ];
    }
    if (_isFragranceCategory) {
      return const ['All', 'Perfume & Cologne', 'Body Sprays & Mists'];
    }
    if (_isMoisturizersCategory) {
      return const [
        'All',
        'Body Butter & Balm',
        'Body Cream',
        'Body Lotion',
        'Body Oil',
        'Hand Cream',
        'Lip Care',
        'Smooth & Soothe Body Cream',
        'Travel Size Body Cream',
      ];
    }
    if (_isBathShowerCategory) {
      return const [
        'All',
        'Bar Soap',
        'Body Scrub',
        'Body Wash & Shower Gel',
        'Moisturizing Body Wash',
        'Shower Steamers',
      ];
    }
    if (_isMinisCategory) {
      return const [
        'All',
        'Body Spray & Mist',
        'Hand Cream',
        'Travel Size Body Cream',
        'Travel Size Body Lotion',
        'Travel Size Body Wash',
        'Travel Size Essential Oil Mist',
        'Travel Size Fine Fragrance Mist',
        'Travel Size Perfume Mist',
        'Travel Size Ultimate Hydration Body Cream',
      ];
    }
    if (_isCandlesCategory) {
      return const [
        'All',
        '3-Wick Candle',
        '4-Wick Candle',
        'Single Wick Candle',
        'Candle Accessories',
      ];
    }
    if (_isRoomSpraysCategory) {
      return const [
        'All',
        'Room Spray',
        'Room Mist',
      ];
    }
    if (_isCarFragranceCategory) {
      return const [
        'All',
        'Car Fragrance Holder',
        'Car Fragrance Refill',
        'Hanging Fragrance Diffuser',
      ];
    }
    if (_isAllMensBodyCareCategory) {
      return const [
        'All',
        'Bar Soap',
        'Body Cream',
        'Body Spray & Mist',
        'Body Wash & Shower Gel',
        'Cologne',
        'Deodorant',
        'Mini Cologne',
      ];
    }
    final Set<String> set = {'All'};
    for (final p in _raw) {
      final a = p['subCategory'] ?? p['brand'];
      if (a != null && a.toString().trim().isNotEmpty) {
        set.add(a.toString().trim());
      }
    }
    return set.toList();
  }

  @override
  void initState() {
    super.initState();
    _searchC.addListener(_applyFilter);
    _scroll.addListener(_onScroll);
    _bootstrap();
  }

  void _onScroll() {
    final dir = _scroll.position.userScrollDirection;
    if (dir == ScrollDirection.reverse && _showSearch) {
      setState(() => _showSearch = false);
    } else if (dir == ScrollDirection.forward && !_showSearch) {
      setState(() => _showSearch = true);
    }
  }

  Future<void> _bootstrap() async {
    final data = await _loadProducts();
    _raw = data;
    _index = data.map(_IndexedProduct.fromMap).toList();
    _filtered = List.of(_raw);
    setState(() => _loading = false);
  }

  Future<List<Map<String, dynamic>>> _loadProducts() async {
    List<String> files =
        widget.fileOverrides ??
        [
          if (widget.subCategory != null)
            'assets/stores/aldi/aldi_${widget.subCategory!.toLowerCase().replaceAll(' ', '_')}.json'
          else
            'assets/stores/aldi/aldi_${widget.category.toLowerCase().replaceAll(' ', '_')}.json',
        ];

    // If this appears to be a Panda appetizers screen (title or category) but we
    // have no panda appetizer file specified, inject it so products load.
    final looksLikeAppetizers =
        (widget.title?.toLowerCase().contains('appetizer') ?? false) ||
        widget.category.toLowerCase().contains('appetizer');
    if (looksLikeAppetizers &&
        !files.any((f) => f.contains('panda-express-appetizers'))) {
      files.add('assets/stores/panda_express/panda-express-appetizers.json');
    }

    if (widget.fileOverrides != null && widget.fileOverrides!.isNotEmpty) {
      try {
        final manifestRaw = await rootBundle.loadString('AssetManifest.json');
        final Map<String, dynamic> manifest = json.decode(manifestRaw);
        final Set<String> expanded = {};
        for (final original in files) {
          expanded.add(original);
          if (!original.endsWith('.json')) continue;
          final partPattern = RegExp(
            '^' +
                RegExp.escape(original.replaceFirst('.json', '')) +
                r'-part\d+\.json$',
          );
          for (final key in manifest.keys) {
            if (!key.endsWith('.json') || key.endsWith('.json.bak')) continue;
            if (partPattern.hasMatch(key)) expanded.add(key);
          }
        }
        files = expanded.toList()..sort();
      } catch (e) {
        debugPrint('[ProductList] partition expansion failed: $e');
      }
    }

    final Map<String, Map<String, dynamic>> byId = {};
    final List<String> failed = [];
    for (final path in files) {
      try {
        final raw = await rootBundle.loadString(path);
        final List data = json.decode(raw) as List;
        for (final item in data) {
          if (item is Map<String, dynamic>) {
            final id = (item['id'] ?? '${path}_${byId.length}').toString();
            byId[id] = {...item};
          }
        }
      } catch (e) {
        debugPrint('[ProductList] failed $path: $e');
        failed.add(path);
      }
    }

    debugPrint(
      '[ProductList] files=${files.length} loaded=${byId.length} failed=${failed.length}',
    );

    if (byId.isEmpty && failed.isNotEmpty) {
      return [
        {
          'id': 'load_error',
          'name': 'Asset load failed',
          'description': 'Could not load:\n' + failed.join('\n'),
          'failed': true,
        },
      ];
    }

    final list = byId.values.toList()
      ..sort(
        (a, b) => (a['name'] ?? '').toString().compareTo(
          (b['name'] ?? '').toString(),
        ),
      );
    return list;
  }

  void _applyFilter() {
    final q = _searchC.text.trim().toLowerCase();
    var list = _raw;

    if (_selectedAisle != 'All') {
      if (_isFragranceCategory) {
        if (_selectedAisle == 'Perfume & Cologne') {
          list = list.where((p) {
            final text = '${p['name']} ${p['subCategory']}'.toLowerCase();
            return text.contains('perfume') ||
                text.contains('cologne') ||
                text.contains('eau de parfum') ||
                text.contains('rollerball') ||
                text.contains('parfum');
          }).toList();
        } else if (_selectedAisle == 'Body Sprays & Mists') {
          list = list.where((p) {
            final text = '${p['name']} ${p['subCategory']}'.toLowerCase();
            final isPerfumeOrCologne = text.contains('perfume') ||
                text.contains('cologne') ||
                text.contains('eau de parfum') ||
                text.contains('rollerball') ||
                text.contains('parfum');
            return !isPerfumeOrCologne;
          }).toList();
        }
      } else if (_isMoisturizersCategory) {
        list = list.where((p) {
          final text = '${p['name']} ${p['subCategory']}'.toLowerCase();
          final aisle = _selectedAisle;
          if (aisle == 'Body Butter & Balm') {
            return text.contains('butter') || text.contains('balm');
          }
          if (aisle == 'Body Cream') {
            return (text.contains('cream') || text.contains('hydration')) &&
                !text.contains('hand cream') &&
                !text.contains('travel') &&
                !text.contains('mini') &&
                !text.contains('smooth') &&
                !text.contains('soothe');
          }
          if (aisle == 'Body Lotion') {
            return text.contains('lotion');
          }
          if (aisle == 'Body Oil') {
            return text.contains('oil');
          }
          if (aisle == 'Hand Cream') {
            return text.contains('hand');
          }
          if (aisle == 'Lip Care') {
            return text.contains('lip');
          }
          if (aisle == 'Smooth & Soothe Body Cream') {
            return text.contains('smooth') || text.contains('soothe');
          }
          if (aisle == 'Travel Size Body Cream') {
            return text.contains('travel') || text.contains('mini');
          }
          return true;
        }).toList();
      } else if (_isBathShowerCategory) {
        list = list.where((p) {
          final text = '${p['name']} ${p['subCategory']} ${p['description']}'.toLowerCase();
          final aisle = _selectedAisle;
          if (aisle == 'Bar Soap') {
            return text.contains('bar') || (text.contains('soap') && !text.contains('hand'));
          }
          if (aisle == 'Body Scrub') {
            return text.contains('scrub') || text.contains('exfoliat');
          }
          if (aisle == 'Moisturizing Body Wash') {
            return text.contains('moisturizing') || text.contains('hydration');
          }
          if (aisle == 'Body Wash & Shower Gel') {
            return (text.contains('wash') || text.contains('gel') || text.contains('cleanser')) &&
                !text.contains('moisturizing');
          }
          if (aisle == 'Shower Steamers') {
            return text.contains('steamer');
          }
          return true;
        }).toList();
      } else if (_isMinisCategory) {
        list = list.where((p) {
          final text = '${p['name']} ${p['subCategory']}'.toLowerCase();
          final aisle = _selectedAisle;
          if (aisle == 'Body Spray & Mist') {
            return text.contains('body spray') || (text.contains('spray') && text.contains('mist'));
          }
          if (aisle == 'Hand Cream') {
            return text.contains('hand');
          }
          if (aisle == 'Travel Size Body Cream') {
            return text.contains('body cream') && !text.contains('ultimate');
          }
          if (aisle == 'Travel Size Body Lotion') {
            return text.contains('lotion');
          }
          if (aisle == 'Travel Size Body Wash') {
            return text.contains('wash');
          }
          if (aisle == 'Travel Size Essential Oil Mist') {
            return text.contains('essential oil');
          }
          if (aisle == 'Travel Size Fine Fragrance Mist') {
            return text.contains('fine fragrance mist');
          }
          if (aisle == 'Travel Size Perfume Mist') {
            return text.contains('perfume mist') || text.contains('cologne');
          }
          if (aisle == 'Travel Size Ultimate Hydration Body Cream') {
            return text.contains('ultimate hydration');
          }
          return true;
        }).toList();
      } else if (_isCandlesCategory) {
        list = list.where((p) {
          final sub = (p['subCategory'] ?? '').toString().toLowerCase();
          final text = '${p['name']} $sub'.toLowerCase();
          final aisle = _selectedAisle;
          if (aisle == '3-Wick Candle') {
            return text.contains('3-wick') || text.contains('3 wick');
          }
          if (aisle == '4-Wick Candle') {
            return text.contains('4-wick') || text.contains('4 wick');
          }
          if (aisle == 'Single Wick Candle') {
            return text.contains('single wick') || text.contains('single-wick');
          }
          if (aisle == 'Candle Accessories') {
            return text.contains('holder') || text.contains('pedestal') || text.contains('accessory') || text.contains('accessories');
          }
          return true;
        }).toList();
      } else if (_isRoomSpraysCategory) {
        list = list.where((p) {
          final text = '${p['name']} ${p['subCategory']}'.toLowerCase();
          final aisle = _selectedAisle;
          if (aisle == 'Room Spray') {
            return text.contains('spray');
          }
          if (aisle == 'Room Mist') {
            return text.contains('mist');
          }
          return true;
        }).toList();
      } else if (_isCarFragranceCategory) {
        list = list.where((p) {
          final text = '${p['name']} ${p['subCategory']}'.toLowerCase();
          final aisle = _selectedAisle;
          if (aisle == 'Car Fragrance Holder') {
            return text.contains('holder');
          }
          if (aisle == 'Car Fragrance Refill') {
            return text.contains('refill');
          }
          if (aisle == 'Hanging Fragrance Diffuser') {
            return text.contains('hanging') || text.contains('diffuser');
          }
          return true;
        }).toList();
      } else if (_isAllMensBodyCareCategory) {
        list = list.where((p) {
          final text = '${p['name']} ${p['subCategory']} ${p['description']}'.toLowerCase();
          final aisle = _selectedAisle;
          if (aisle == 'Bar Soap') {
            return text.contains('bar') || text.contains('cleansing bar') || (text.contains('soap') && !text.contains('wash'));
          }
          if (aisle == 'Body Cream') {
            return text.contains('cream') || text.contains('lotion');
          }
          if (aisle == 'Body Spray & Mist') {
            return text.contains('spray') || text.contains('mist');
          }
          if (aisle == 'Body Wash & Shower Gel') {
            return text.contains('wash') || text.contains('shower gel');
          }
          if (aisle == 'Cologne') {
            return text.contains('cologne') && !text.contains('mini') && !text.contains('travel');
          }
          if (aisle == 'Deodorant') {
            return (text.contains('deodorant') || text.contains('antiperspirant')) && !text.contains('spray');
          }
          if (aisle == 'Mini Cologne') {
            return (text.contains('mini') || text.contains('travel')) && text.contains('cologne');
          }
          return true;
        }).toList();
      } else {
        list = list.where((p) {
          final sub = (p['subCategory'] ?? p['brand'] ?? '').toString();
          return sub == _selectedAisle;
        }).toList();
      }
    }

    if (q.isNotEmpty) {
      list = list.where((p) {
        final text =
            '${p['name']} ${p['brand']} ${p['description']}'.toLowerCase();
        return text.contains(q);
      }).toList();
    }

    setState(() => _filtered = list);
  }

  Widget _buildAislePills() {
    final aisles = _aisles;
    if (aisles.length <= 2) return const SizedBox.shrink();

    return Container(
      height: 44,
      color: const Color(0xFF181818),
      padding: const EdgeInsets.only(bottom: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: aisles.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final a = aisles[i];
          final isSel = a == _selectedAisle;
          return InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              setState(() {
                _selectedAisle = a;
                _applyFilter();
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isSel
                    ? const Color(0xFFE6B450)
                    : const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSel
                      ? const Color(0xFFE6B450)
                      : Colors.white.withValues(alpha: 0.12),
                ),
              ),
              child: Center(
                child: Text(
                  a,
                  style: TextStyle(
                    color: isSel ? Colors.black : Colors.white70,
                    fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  bool _isPandaExpressDrinks() {
    // Check if this is displaying Panda Express drinks, crafted beverages, or appetizers
    final files = widget.fileOverrides ?? [];
    return files.any(
      (file) =>
          file.contains('panda-express-drinks') ||
          file.contains('panda-express-crafted-beverages') ||
          file.contains('panda-express-appetizers'),
    );
  }

  bool _isPandaExpressBeverages() {
    // Only drinks/crafted beverages (used for hidePrice + bottom sheet)
    final files = widget.fileOverrides ?? [];
    return files.any(
      (file) =>
          file.contains('panda-express-drinks.json') ||
          file.contains('panda-express-crafted-beverages.json'),
    );
  }

  @override
  void dispose() {
    _searchC.removeListener(_applyFilter);
    _scroll.removeListener(_onScroll);
    _searchC.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final titleText =
        widget.title ?? widget.subCategory ?? '${widget.category} Products';
    final products = _filtered;
    return Scaffold(
      backgroundColor: _bg,
      appBar: StoreAppBar(title: titleText),
      body: Stack(
        children: [
          _loading
              ? const Center(child: CircularProgressIndicator(color: _gold))
              : products.isEmpty
              ? const Center(
                  child: Text(
                    'No products found.',
                    style: TextStyle(color: Colors.white70),
                  ),
                )
              : _buildContent(products),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: MiniCartBar(
              onViewCart: () => Navigator.pushNamed(context, '/cart'),
              onCheckout: () => Navigator.pushNamed(context, '/cart'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(List<Map<String, dynamic>> products) {
    return Column(
      children: [
        ClipRect(
          child: AnimatedSize(
            duration: const Duration(milliseconds: 230),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: _showSearch
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        color: const Color(0xFF181818),
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                        child: TextField(
                          controller: _searchC,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'Search products...',
                            hintStyle: const TextStyle(color: Colors.white54),
                            prefixIcon: const Icon(
                              Icons.search,
                              color: _gold,
                              size: 20,
                            ),
                            filled: true,
                            fillColor: const Color(0xFF202020),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: _gold,
                                width: 0.6,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: _gold,
                                width: 0.4,
                              ),
                            ),
                            suffixIcon: _searchC.text.isEmpty
                                ? null
                                : IconButton(
                                    icon: const Icon(
                                      Icons.clear,
                                      color: Colors.white70,
                                      size: 18,
                                    ),
                                    onPressed: () {
                                      _searchC.clear();
                                      FocusScope.of(context).unfocus();
                                    },
                                  ),
                          ),
                        ),
                      ),
                      _buildAislePills(),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;

              // Check if this is Panda Express drinks category
              final isPandaDrinks = _isPandaExpressDrinks();
              final isPandaBeverages = _isPandaExpressBeverages();
              final isPandaBundles =
                  (widget.category.toLowerCase() == 'panda bundles');

              int cross;
              double aspect;

              if (isPandaDrinks) {
                cross = 1;
                aspect = 2.8;
              } else {
                // Standard grid layout for other categories
                if (width >= 900) {
                  cross = 4;
                  aspect = 0.68;
                } else if (width >= 600) {
                  cross = 3;
                  aspect = 0.68;
                } else {
                  // Strict 2-column layout on handheld mobile screens gives ~180px per card
                  cross = 2;
                  aspect = 0.70;
                }
              }

              if (isPandaBundles) {
                const order = <String, int>{
                  'panda_express_bundle_bowl': 0,
                  'panda_express_bundle_plate': 1,
                  'panda_express_bundle_bigger_plate': 2,
                };
                final sorted = List<Map<String, dynamic>>.from(products)
                  ..sort(
                    (a, b) => (order[a['id']] ?? 999).compareTo(
                      order[b['id']] ?? 999,
                    ),
                  );
                return ListView.separated(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 16),
                  itemCount: sorted.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final p = sorted[i];
                    if (p['failed'] == true) {
                      return Card(
                        color: const Color(0xFF3A1F1F),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            (p['description'] ?? 'Load failed').toString(),
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      );
                    }
                    final nameRaw = (p['name'] ?? '').toString();
                    final originalName = (p['originalName'] ?? '').toString();
                    final name =
                        originalName.isNotEmpty &&
                            originalName.length > nameRaw.length
                        ? originalName
                        : nameRaw;
                    final img = (p['imageUrl'] ?? '').toString();
                    final price = p['price'];
                    final unit = p['unit'];
                    final unitShort = p['unitShort'];
                    final brand = (p['brand'] ?? '').toString().trim();
                    final product = Product(
                      id: p['id']?.toString() ?? name,
                      name: name,
                      brand: brand.isEmpty ? null : brand,
                      store: null,
                      category: widget.category,
                      subCategory: widget.subCategory,
                      price: price is num ? price.toDouble() : null,
                      rating: (p['rating'] is num)
                          ? (p['rating'] as num).toDouble()
                          : null,
                      tags: const [],
                      imageUrl: img.isEmpty ? null : img,
                      imageAsset: null,
                      description: (p['description'] ?? '').toString(),
                      unit: unit?.toString(),
                      unitShort: unitShort?.toString(),
                      modifiers:
                          (p['modifiers'] as List?)
                              ?.map(
                                (m) => ProductModifier.fromJson(
                                  m as Map<String, dynamic>,
                                ),
                              )
                              .toList() ??
                          const [],
                      isBundleWrapper: p['isBundleWrapper'] == true,
                      bundleBaseProductId: p['bundleBaseProductId']?.toString(),
                      bundleRules: p['bundleRules'] is Map
                          ? BundleRules.fromJson(
                              (p['bundleRules'] as Map).cast<String, dynamic>(),
                            )
                          : null,
                    );
                    return ProductCardV2(
                      product: product,
                      highlight: _searchC.text,
                      isHorizontalLayout: true,
                      hidePrice: false,
                      onTap: () {
                        if (product.isBundleWrapper &&
                            product.bundleBaseProductId != null) {
                          Navigator.pushNamed(
                            context,
                            '/product',
                            arguments: {
                              'id': product.bundleBaseProductId!,
                              'bundleContext': true,
                              'wrapperId': product.id,
                              'name': product.name,
                              'brand': product.brand,
                              'imageUrl': product.imageUrl,
                              'description': product.description,
                              'price': product.price,
                              'unit': product.unit,
                              'unitShort': product.unitShort,
                            },
                          );
                          return;
                        }
                        Navigator.pushNamed(
                          context,
                          '/product',
                          arguments: {
                            'id': product.id,
                            'name': product.name,
                            'brand': product.brand,
                            'imageUrl': product.imageUrl,
                            'description': product.description,
                            'price': product.price,
                            'unit': product.unit,
                            'unitShort': product.unitShort,
                          },
                        );
                      },
                    );
                  },
                );
              }

              final filesForDetect = widget.fileOverrides ?? [];
              final isAppetizers =
                  filesForDetect.any(
                    (f) => f.contains('panda-express-appetizers'),
                  ) ||
                  (widget.title?.toLowerCase().contains('appetizer') ??
                      false) ||
                  widget.category.toLowerCase().contains('appetizer');

              if (isAppetizers) {
                // Use a vertical list (no grid) to prevent vertical overflow with expandable quick add UI.
                return ListView.separated(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 24),
                  itemCount: products.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final p = products[i];
                    if (p['failed'] == true) {
                      return Card(
                        color: const Color(0xFF3A1F1F),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            (p['description'] ?? 'Load failed').toString(),
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      );
                    }
                    final nameRaw = (p['name'] ?? '').toString();
                    final originalName = (p['originalName'] ?? '').toString();
                    final name =
                        originalName.isNotEmpty &&
                            originalName.length > nameRaw.length
                        ? originalName
                        : nameRaw;
                    final img = (p['imageUrl'] ?? '').toString();
                    final price = p['price'];
                    final unit = p['unit'];
                    final unitShort = p['unitShort'];
                    final brand = (p['brand'] ?? '').toString().trim();
                    final product = Product(
                      id: p['id']?.toString() ?? name,
                      name: name,
                      brand: brand.isEmpty ? null : brand,
                      store: null,
                      category: widget.category,
                      subCategory: widget.subCategory,
                      price: price is num ? price.toDouble() : null,
                      rating: (p['rating'] is num)
                          ? (p['rating'] as num).toDouble()
                          : null,
                      tags: const [],
                      imageUrl: img.isEmpty ? null : img,
                      imageAsset: null,
                      description: (p['description'] ?? '').toString(),
                      unit: unit?.toString(),
                      unitShort: unitShort?.toString(),
                      modifiers:
                          (p['modifiers'] as List?)
                              ?.map(
                                (m) => ProductModifier.fromJson(
                                  m as Map<String, dynamic>,
                                ),
                              )
                              .toList() ??
                          const [],
                      isBundleWrapper: p['isBundleWrapper'] == true,
                      bundleBaseProductId: p['bundleBaseProductId']?.toString(),
                      bundleRules: p['bundleRules'] is Map
                          ? BundleRules.fromJson(
                              (p['bundleRules'] as Map).cast<String, dynamic>(),
                            )
                          : null,
                    );
                    final isSimple =
                        !product.isBundleWrapper &&
                        product.modifiers.isEmpty &&
                        product.choiceGroups.isEmpty &&
                        product.price != null;
                    if (!isSimple) {
                      return ProductCardV2(
                        product: product,
                        highlight: _searchC.text,
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            '/product',
                            arguments: {
                              'id': product.id,
                              'name': product.name,
                              'brand': product.brand,
                              'imageUrl': product.imageUrl,
                              'description': product.description,
                              'price': product.price,
                              'unit': product.unit,
                              'unitShort': product.unitShort,
                            },
                          );
                        },
                      );
                    }
                    final selected = _selectedAppetizerId == product.id;
                    return AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      child: QuickAddProductCard(
                        key: ValueKey('ap-${product.id}-$selected'),
                        product: product,
                        selected: selected,
                        onSelect: () {
                          setState(() => _selectedAppetizerId = product.id);
                        },
                        onAdd: (qty) async {
                          await CartService.instance.add(product.id, qty);
                          if (mounted) {
                            setState(
                              () => _selectedAppetizerId = null,
                            ); // collapse after add
                          }
                        },
                      ),
                    );
                  },
                );
              }

              // Balanced Protein Plates: present as vertical list like bundles instead of grid.
              final isBalancedProteinCategory =
                  (widget.title ?? widget.category).toLowerCase().contains(
                    'balanced protein',
                  );
              if (isBalancedProteinCategory) {
                return ListView.separated(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                  itemCount: products.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) {
                    final p = products[i];
                    if (p['failed'] == true) {
                      return Card(
                        color: const Color(0xFF3A1F1F),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            (p['description'] ?? 'Load failed').toString(),
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      );
                    }
                    final nameRaw = (p['name'] ?? '').toString();
                    final originalName = (p['originalName'] ?? '').toString();
                    final name =
                        originalName.isNotEmpty &&
                            originalName.length > nameRaw.length
                        ? originalName
                        : nameRaw;
                    final img = (p['imageUrl'] ?? '').toString();
                    final price = p['price'];
                    final unit = p['unit'];
                    final unitShort = p['unitShort'];
                    final brand = (p['brand'] ?? '').toString().trim();
                    final product = Product(
                      id: p['id']?.toString() ?? name,
                      name: name,
                      brand: brand.isEmpty ? null : brand,
                      store: null,
                      category: widget.category,
                      subCategory: widget.subCategory,
                      price: price is num ? price.toDouble() : null,
                      rating: (p['rating'] is num)
                          ? (p['rating'] as num).toDouble()
                          : null,
                      tags: const [],
                      imageUrl: img.isEmpty ? null : img,
                      imageAsset: null,
                      description: (p['description'] ?? '').toString(),
                      unit: unit?.toString(),
                      unitShort: unitShort?.toString(),
                      modifiers: const [],
                      isBundleWrapper: false,
                      bundleBaseProductId: null,
                      bundleRules: null,
                    );
                    return _BalancedPlateListTile(
                      product: product,
                      onTap: () => showBalancedPlateDialog(context, product),
                    );
                  },
                );
              }

              return GridView.builder(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cross,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: aspect,
                ),
                itemCount: products.length,
                itemBuilder: (_, i) {
                  final p = products[i];
                  if (p['failed'] == true) {
                    return Card(
                      color: const Color(0xFF3A1F1F),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          (p['description'] ?? 'Load failed').toString(),
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    );
                  }
                  final nameRaw = (p['name'] ?? '').toString();
                  final originalName = (p['originalName'] ?? '').toString();
                  final name =
                      originalName.isNotEmpty &&
                          originalName.length > nameRaw.length
                      ? originalName
                      : nameRaw;
                  final img = (p['imageUrl'] ?? '').toString();
                  final price = p['price'];
                  final unit = p['unit'];
                  final unitShort = p['unitShort'];
                  final brand = (p['brand'] ?? '').toString().trim();
                  final product = Product(
                    id: p['id']?.toString() ?? name,
                    name: name,
                    brand: brand.isEmpty ? null : brand,
                    store: null,
                    category: widget.category,
                    subCategory: widget.subCategory,
                    price: price is num ? price.toDouble() : null,
                    rating: (p['rating'] is num)
                        ? (p['rating'] as num).toDouble()
                        : null,
                    tags: const [],
                    imageUrl: img.isEmpty ? null : img,
                    imageAsset: null,
                    description: (p['description'] ?? '').toString(),
                    unit: unit?.toString(),
                    unitShort: unitShort?.toString(),
                    modifiers:
                        (p['modifiers'] as List?)
                            ?.map(
                              (m) => ProductModifier.fromJson(
                                m as Map<String, dynamic>,
                              ),
                            )
                            .toList() ??
                        const [],
                    // Pass through bundle wrapper/meta fields (ignored if absent)
                    isBundleWrapper: p['isBundleWrapper'] == true,
                    bundleBaseProductId: p['bundleBaseProductId']?.toString(),
                    bundleRules: p['bundleRules'] is Map
                        ? BundleRules.fromJson(
                            (p['bundleRules'] as Map).cast<String, dynamic>(),
                          )
                        : null,
                  );

                  final looksLikeAppetizers =
                      (widget.title?.toLowerCase().contains('appetizer') ??
                          false) ||
                      widget.category.toLowerCase().contains('appetizer');

                  final isAppetizer =
                      (widget.fileOverrides ?? []).any(
                        (f) => f.contains('panda-express-appetizers'),
                      ) ||
                      looksLikeAppetizers;
                  final isSimple =
                      !product.isBundleWrapper &&
                      product.modifiers.isEmpty &&
                      product.choiceGroups.isEmpty &&
                      product.price != null;
                  // Use quick add card only for simple appetizers when not searching (to avoid clutter when user searches broadly across categories if that ever happens)
                  if (isAppetizer && isSimple) {
                    return QuickAddProductCard(product: product);
                  }
                  return ProductCardV2(
                    product: product,
                    highlight: _searchC.text,
                    isHorizontalLayout: isPandaDrinks,
                    hidePrice: isPandaBeverages,
                    onTap: () {
                      final lowerCat = (product.category ?? '').toLowerCase();
                      final isBalancedPlate =
                          product.id.startsWith('panda_express_balanced_') ||
                          lowerCat.contains('balanced protein');
                      if (isBalancedPlate) {
                        showBalancedPlateDialog(context, product);
                        return;
                      }
                      if (isPandaBeverages) {
                        showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => ProductOptionsSheet(product: product),
                        );
                        return;
                      }
                      // If this is a bundle wrapper, navigate to base product with bundle context.
                      if (product.isBundleWrapper &&
                          product.bundleBaseProductId != null) {
                        Navigator.pushNamed(
                          context,
                          '/product',
                          arguments: {
                            'id': product.bundleBaseProductId!,
                            'bundleContext': true,
                            'wrapperId': product.id,
                            'name': product.name,
                            'brand': product.brand,
                            'imageUrl': product.imageUrl,
                            'description': product.description,
                            'price': product.price,
                            'unit': product.unit,
                            'unitShort': product.unitShort,
                          },
                        );
                        return;
                      }
                      // Generic navigation for other products (including combos) so they become tappable.
                      Navigator.pushNamed(
                        context,
                        '/product',
                        arguments: {
                          'id': product.id,
                          'name': product.name,
                          'brand': product.brand,
                          'imageUrl': product.imageUrl,
                          'description': product.description,
                          'price': product.price,
                          'unit': product.unit,
                          'unitShort': product.unitShort,
                        },
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class DiapersWipesWashScreen extends ProductListScreen {
  DiapersWipesWashScreen({Key? key})
    : super(
        key: key,
        category: 'Baby Items',
        subCategory: 'Diapers, Wipes & Wash',
        fileOverrides: ['assets/stores/aldi/aldi_diapers_wipes_wash.json'],
        title: 'Diapers, Wipes & Wash',
      );
}

class _IndexedProduct {
  final Map<String, dynamic> data;
  final String searchText;
  _IndexedProduct(this.data, this.searchText);
  factory _IndexedProduct.fromMap(Map<String, dynamic> m) {
    final parts = <String?>[
      m['name']?.toString(),
      m['originalName']?.toString(),
      m['shortName']?.toString(),
      m['brand']?.toString(),
      m['description']?.toString(),
    ];
    final search = parts
        .where((e) => e != null && e.trim().isNotEmpty)
        .map((e) => e!.toLowerCase())
        .join(' ');
    return _IndexedProduct(m, search);
  }
}

class _BalancedPlateListTile extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;
  const _BalancedPlateListTile({required this.product, required this.onTap});

  static const Map<String, String> _composition = {
    'panda_express_balanced_double_protein_plate':
        '2X Grilled Teriyaki Chicken with Half White Steamed Rice + Half Super Greens',
    'panda_express_balanced_harmonious_macros_plate':
        'Grilled Teriyaki Chicken and Broccoli Beef with Super Greens',
    'panda_express_balanced_bold_flavorful_plate':
        'Kung Pao Chicken and Black Pepper Sirloin Steak with Super Greens',
    'panda_express_balanced_power_packed_plate':
        'Black Pepper Sirloin Steak and Broccoli Beef with Super Greens',
    'panda_express_balanced_protein_fiber_plate':
        'String Bean Chicken Breast and Kung Pao Chicken with Super Greens',
  };

  @override
  Widget build(BuildContext context) {
    final gold = const Color(0xFFE6B450);
    final comp = _composition[product.id];
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF181818),
          borderRadius: BorderRadius.circular(22),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 84,
                height: 84,
                child: product.imageUrl != null
                    ? Image.network(product.imageUrl!, fit: BoxFit.cover)
                    : Container(
                        color: Colors.grey[800],
                        child: const Icon(Icons.image, color: Colors.white24),
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (product.description?.isNotEmpty == true) ...[
                    Text(
                      product.description!
                          .replaceAll('(Base + 2 Entrées)', '')
                          .trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12.5,
                        height: 1.25,
                      ),
                    ),
                  ],
                  if (comp != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      comp,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11.5,
                        height: 1.25,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  if (product.price != null)
                    Text(
                      '\$' + product.price!.toStringAsFixed(2),
                      style: TextStyle(
                        color: gold,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: Colors.white38),
          ],
        ),
      ),
    );
  }
}
