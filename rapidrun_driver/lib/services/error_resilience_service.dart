import 'dart:async';

/// Centralized helper for retry logic and friendly error messaging for
/// network / Firestore driven operations.
class ErrorResilienceService {
  ErrorResilienceService._();
  static final instance = ErrorResilienceService._();

  /// Executes [op] with retry for transient failures.
  /// A transient failure is detected by [isTransient].
  /// Backoff: 300ms * attempt index (1-based) unless overridden.
  Future<T> runWithRetry<T>(
    Future<T> Function() op, {
    int maxAttempts = 3,
    Duration Function(int attempt)? backoff,
  }) async {
    int attempt = 0;
    Object? lastError;
    while (attempt < maxAttempts) {
      attempt++;
      try {
        return await op();
      } catch (e) {
        lastError = e;
        if (!_isTransient(e) || attempt >= maxAttempts) rethrow;
        final wait =
            backoff?.call(attempt) ?? Duration(milliseconds: 300 * attempt);
        await Future.delayed(wait);
      }
    }
    // Should never reach here due to rethrow above.
    throw lastError ?? StateError('unknown_error');
  }

  /// Human friendly error message.
  String friendly(Object error) {
    final raw = error.toString();
    if (_isClaimed(error)) return 'Offer no longer available';
    if (raw.contains('not the assigned'))
      return 'Another driver owns this order.';
    if (raw.contains('Invalid transition'))
      return 'That step is no longer valid.';
    if (_isTransient(error)) return 'Network issue – tap retry.';
    if (raw.contains('permission')) return 'Permission denied.';
    if (raw.contains('no longer exists')) return 'Item no longer exists.';
    return 'Action failed';
  }

  bool isClaimed(Object error) => _isClaimed(error);

  bool _isClaimed(Object error) {
    if (error is StateError && error.message == 'Order already claimed')
      return true;
    final s = error.toString().toLowerCase();
    return s.contains('already claimed');
  }

  bool _isTransient(Object error) {
    final s = error.toString();
    return s.contains('UNAVAILABLE') ||
        s.contains('DEADLINE') ||
        s.contains('ABORTED') ||
        s.contains('INTERNAL') ||
        s.toLowerCase().contains('network');
  }
}
