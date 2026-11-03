/// Utility helpers for rendering product unit strings consistently.
/// Prefers concise `unitShort` when available; falls back to sanitized `unit`.
class UnitFormat {
  /// Returns a compact unit string suitable for list tiles (max ~18 chars).
  static String compact({String? unitShort, String? unit, int max = 18}) {
    final raw = (unitShort ?? unit)?.trim();
    if (raw == null || raw.isEmpty) return '';
    var s = raw;
    // Remove verbose total clause if present.
    s = s
        .replaceAll(RegExp(r'\(total[^\)]*\)', caseSensitive: false), '')
        .trim();
    if (s.length > max) {
      s = s.substring(0, max - 1).trimRight() + '…';
    }
    return s;
  }

  /// Returns a medium display version without truncation; still strips verbose totals.
  static String medium({String? unitShort, String? unit}) {
    final raw = (unitShort ?? unit)?.trim();
    if (raw == null || raw.isEmpty) return '';
    return raw
        .replaceAll(RegExp(r'\(total[^\)]*\)', caseSensitive: false), '')
        .trim();
  }
}
