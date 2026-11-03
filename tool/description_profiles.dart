// Domain description profiles for deterministic enrichment across categories.
// Neutral, factual, copyright-safe.

class DomainProfile {
  final String id;
  final List<Pattern> namePatterns;
  final List<Pattern> typePatterns;
  final List<Pattern> sectionPatterns;
  final List<String> adjectives;
  final String noun;
  final String feature;
  final String usage;
  const DomainProfile({
    required this.id,
    required this.namePatterns,
    this.typePatterns = const [],
    this.sectionPatterns = const [],
    required this.adjectives,
    required this.noun,
    required this.feature,
    required this.usage,
  });
  bool matches({
    required String name,
    required String type,
    required String section,
    required String category,
  }) {
    final ln = name.toLowerCase();
    final lt = type.toLowerCase();
    final ls = section.toLowerCase();
    final lc = category.toLowerCase();
    bool any(List<Pattern> pats, String src) =>
        pats.isEmpty ||
        pats.any((p) {
          if (p is RegExp) return p.hasMatch(src);
          return src.contains(p.toString().toLowerCase());
        });
    if (!any(namePatterns, ln)) return false;
    if (!any(typePatterns, lt)) return false;
    if (!any(sectionPatterns, ls) && !any(sectionPatterns, lc)) return false;
    return true;
  }
}

final List<DomainProfile> domainProfiles = [
  DomainProfile(
    id: 'coffee',
    namePatterns: [RegExp(r'\\bcoffee\\b'), 'espresso', 'cold brew'],
    adjectives: ['aromatic', 'roasted'],
    noun: 'coffee beverage',
    feature: 'a balanced flavor profile',
    usage: 'Enjoy hot or iced as part of a daily routine.',
  ),
  DomainProfile(
    id: 'energy_drink',
    namePatterns: ['energy drink', 'energy'],
    adjectives: ['energizing', 'carbonated'],
    noun: 'energy drink',
    feature: 'caffeine and functional ingredients',
    usage: 'Consume responsibly, mindful of personal caffeine limits.',
  ),
  DomainProfile(
    id: 'chips',
    namePatterns: ['chips', 'chip', 'pretzel', 'pretzels', 'tortilla'],
    adjectives: ['crunchy', 'savory'],
    noun: 'snack chip',
    feature: 'shareable crunch',
    usage: 'Great for parties, lunches, or on-the-go snacking.',
  ),
  DomainProfile(
    id: 'candy',
    namePatterns: ['candy', 'gummy', 'gummies', 'sours', 'chews'],
    adjectives: ['bite-sized', 'sweet'],
    noun: 'candy treat',
    feature: 'fun flavor variety',
    usage: 'Enjoy in moderation as part of a balanced diet.',
  ),
  DomainProfile(
    id: 'chocolate',
    namePatterns: ['chocolate', 'cocoa'],
    adjectives: ['rich', 'indulgent'],
    noun: 'chocolate confection',
    feature: 'classic cocoa taste',
    usage: 'Suitable for dessert tables or gifting.',
  ),
  DomainProfile(
    id: 'vitamin',
    namePatterns: ['vitamin', 'multivitamin'],
    adjectives: ['daily', 'supplemental'],
    noun: 'vitamin supplement',
    feature: 'support for general nutritional needs',
    usage: 'Use as directed; consult a professional for personal guidance.',
  ),
  DomainProfile(
    id: 'fruit',
    namePatterns: [
      'apple',
      'banana',
      'berries',
      'berry',
      'grape',
      'orange',
      'citrus',
      'melon',
      'pineapple',
      'mango',
    ],
    adjectives: ['fresh', 'ready-to-eat'],
    noun: 'fruit',
    feature: 'natural sweetness',
    usage: 'Use for snacks, salads, or smoothies.',
  ),
  DomainProfile(
    id: 'vegetable',
    namePatterns: [
      'lettuce',
      'spinach',
      'kale',
      'pepper',
      'carrot',
      'broccoli',
      'onion',
      'tomato',
      'cucumber',
      'celery',
    ],
    adjectives: ['fresh', 'versatile'],
    noun: 'vegetable',
    feature: 'culinary versatility',
    usage: 'Add to salads, sides, or cooked dishes.',
  ),
  DomainProfile(
    id: 'frozen_pizza',
    namePatterns: ['pizza'],
    adjectives: ['ready-to-bake', 'convenient'],
    noun: 'frozen pizza',
    feature: 'a quick meal solution',
    usage: 'Bake from frozen for weeknight meals or gatherings.',
  ),
  DomainProfile(
    id: 'frozen_meal',
    namePatterns: [
      'frozen meal',
      'lasagna',
      'mac & cheese',
      'mac and cheese',
      'enchilada',
      'burrito bowl',
      'alfredo',
    ],
    adjectives: ['convenient', 'heat-and-serve'],
    noun: 'frozen meal',
    feature: 'single-serve simplicity',
    usage: 'Keep on hand for quick lunches or dinners.',
  ),
  DomainProfile(
    id: 'bakery_pastry',
    namePatterns: [
      'pastry',
      'croissant',
      'danish',
      'muffin',
      'donut',
      'bagel',
      'cupcake',
    ],
    adjectives: ['soft', 'bakery-style'],
    noun: 'pastry item',
    feature: 'morning or snack enjoyment',
    usage: 'Pair with coffee or tea.',
  ),
  DomainProfile(
    id: 'deli_meat',
    namePatterns: ['ham', 'turkey', 'salami', 'bologna', 'prosciutto'],
    adjectives: ['sliced', 'ready-to-use'],
    noun: 'deli meat',
    feature: 'sandwich versatility',
    usage: 'Use in sandwiches, wraps, or salads.',
  ),
  DomainProfile(
    id: 'rotisserie_hot',
    namePatterns: ['rotisserie', 'hot case'],
    adjectives: ['ready-to-serve', 'savory'],
    noun: 'prepared hot meal',
    feature: 'time-saving convenience',
    usage: 'Serve as an entrée with sides.',
  ),
];

class DomainProfileMatchResult {
  final DomainProfile profile;
  final String description;
  DomainProfileMatchResult(this.profile, this.description);
}

DomainProfileMatchResult? buildDomainProfileDescription({
  required String brand,
  required String name,
  required String type,
  required String section,
  required String category,
  required String baseName,
  required String packSentence,
  required bool concise,
}) {
  for (final p in domainProfiles) {
    if (p.matches(
      name: name,
      type: type,
      section: section,
      category: category,
    )) {
      final adj = p.adjectives.join(' ');
      final first =
          '$brand ${_capFirst(p.noun)} is a $adj ${p.noun} offering ${p.feature}.';
      final parts = <String>[first];
      if (!concise && p.usage.isNotEmpty) parts.add(p.usage);
      if (packSentence.isNotEmpty) parts.add('${_capFirst(packSentence)}.');
      return DomainProfileMatchResult(p, parts.join(' '));
    }
  }
  return null;
}

String _capFirst(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
