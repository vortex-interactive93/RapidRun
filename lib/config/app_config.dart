/// Central app configuration flags.
/// Adjusts behavior around authentication & feature gating.
class AppConfig {
  /// Allow browsing without being signed in.
  static const allowGuestBrowsing = true;

  /// Automatically attempt anonymous auth. If disabled, we defer user auth
  /// until they choose to log in (e.g. at checkout) and operate in pure guest mode.
  static const autoAnonymousAuth = false;

  /// Experimental: enable writing new orders to Firestore and hydrating
  /// order history from the network. When disabled we fall back to purely
  /// local (SharedPreferences) storage. Roll out gradually to validate
  /// security rules & performance.
  static const enableCloudOrders = false;
}

// Application configuration settings
// ...existing code...
