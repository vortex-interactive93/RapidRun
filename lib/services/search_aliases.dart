/// Static search alias map.
/// Keys and values should be lowercase; values are phrases or tokens that
/// users might intend when they type the key (or vice versa).
const Map<String, List<String>> kSearchAliases = {
  'soda': ['soft drink', 'pop', 'cola'],
  'soft drink': ['soda', 'pop', 'cola'],
  'qtip': ['cotton swab'],
  'qtips': ['cotton swab', 'cotton swabs'],
  'bandaid': ['adhesive bandage', 'bandage'],
  'band-aid': ['adhesive bandage', 'bandage'],
  'tp': ['toilet paper'],
  'toilet paper': ['tp', 'bath tissue'],
  'paper towels': ['paper towel'],
  'bbq': ['barbecue', 'grill'],
  'grilling': ['bbq', 'barbecue', 'grill'],
  'veggies': ['vegetables'],
  'fries': ['french fries'],
  'chips': ['crisps'],
  'laundry soap': ['laundry detergent', 'detergent'],
  'dish soap': ['dish detergent'],
  'ground beef': ['minced beef', 'hamburger meat'],
  'burger buns': ['hamburger buns'],
};
