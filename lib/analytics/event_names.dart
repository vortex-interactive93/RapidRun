/// Central analytics event name constants to avoid typos & enable refactors.
class AppEvent {
  AppEvent._();
  static const checkoutReviewOpen = 'checkout_review_open';
  static const orderPlaceAttempt = 'order_place_attempt';
  static const orderPlaceSuccess = 'order_place_success';
  static const orderPlaceFail = 'order_place_fail';
  static const productAddToCart = 'product_add_to_cart';
  static const cartView = 'cart_view';
  static const favoritesToggle = 'favorites_toggle';
  // Search / discovery
  static const productListSearch =
      'product_list_search'; // executed (debounced) search/filter in category list
  static const productListItemTap = 'product_list_item_tap';
  static const productListSearchStart = 'product_list_search_start';
  static const productVariantSwitch = 'product_variant_switch';
  // Preferences
  static const preferencesUpdate = 'preferences_update';
}
