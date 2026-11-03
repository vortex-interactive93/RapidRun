/// Optional mapping of Taco Bell modifier / ingredient option ids to image URLs.
/// Populate with remote or local asset paths if available. If an entry is
/// missing the UI will fall back to a generated letter avatar.
///
/// NOTE: Keep URLs royalty-free or owned. Product-level images already use
/// Taco Bell CDN assets; mirror that pattern only if usage remains compliant.
const Map<String, String> tacoBellIngredientImageUrls = {
  // These sample mappings use Taco Bell public CDN style URLs. Replace or remove
  // any that aren't appropriate or if licensing / usage policies change.
  'seasoned_beef': 'https://www.tacobell.com/images/22163_seasoned_beef_64.jpg',
  'chicken': 'https://www.tacobell.com/images/22163_shredded_chicken_64.jpg',
  'black_beans': 'https://www.tacobell.com/images/22163_black_beans_64.jpg',
  'refried_beans': 'https://www.tacobell.com/images/22163_refried_beans_64.jpg',
  'cheddar_cheese':
      'https://www.tacobell.com/images/22163_shredded_cheese_64.jpg',
  'lettuce': 'https://www.tacobell.com/images/22163_lettuce_64.jpg',
  'tomatoes': 'https://www.tacobell.com/images/22163_diced_tomatoes_64.jpg',
  'onions': 'https://www.tacobell.com/images/22163_onions_64.jpg',
  'sour_cream': 'https://www.tacobell.com/images/22163_sour_cream_64.jpg',
  'nacho_cheese_sauce':
      'https://www.tacobell.com/images/22163_nacho_cheese_64.jpg',
  'chipotle_sauce':
      'https://www.tacobell.com/images/22163_chipotle_sauce_64.jpg',
  'spicy_ranch': 'https://www.tacobell.com/images/22163_spicy_ranch_64.jpg',
  'potatoes': 'https://www.tacobell.com/images/22163_potatoes_64.jpg',
  'jalapenos': 'https://www.tacobell.com/images/22163_jalapenos_64.jpg',
  'avocado_ranch': 'https://www.tacobell.com/images/22163_avocado_ranch_64.jpg',
};
