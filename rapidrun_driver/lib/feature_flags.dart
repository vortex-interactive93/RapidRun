/// Centralized feature flags for the driver app.
/// Keep flags stable (no hot reload rename churn) so remote config mapping is easy later.
class FeatureFlags {
  FeatureFlags._();

  /// Enable the new Stage Sheet + Cinematic offer experience.
  /// When false, fall back to legacy single overlay + offers sheet/badge implementation.
  static const bool enableStageSheet = true; // TODO: wire to Remote Config

  /// Re-enable the legacy multi-offer queue (badge + sheet) for comparison / fallback.
  /// Mutually exclusive UX with Stage Sheet. If both true, Stage Sheet wins.
  static const bool enableLegacyOfferQueue = false;
}
