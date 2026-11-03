/// Simple fuzzy matching utilities (Damerau-Levenshtein with early exit).
/// Optimized for short query tokens (length <= 30).
class FuzzyMatch {
  /// Returns true if edit distance (Damerau-Levenshtein) between a and b
  /// is <= maxDistance. Early exits when distance surpasses threshold.
  static bool withinDistance(String a, String b, int maxDistance) {
    if (a == b) return true;
    if ((a.length - b.length).abs() > maxDistance) return false;
    // Ensure a is shorter.
    if (a.length > b.length) {
      final tmp = a;
      a = b;
      b = tmp;
    }
    final m = a.length;
    final n = b.length;
    if (m == 0) return n <= maxDistance;
    List<int> prev = List<int>.generate(n + 1, (j) => j);
    List<int> curr = List<int>.filled(n + 1, 0);
    for (int i = 1; i <= m; i++) {
      curr[0] = i;
      int minInRow = curr[0];
      final ca = a.codeUnitAt(i - 1);
      for (int j = 1; j <= n; j++) {
        final cost = ca == b.codeUnitAt(j - 1) ? 0 : 1;
        int val = _min3(
          prev[j] + 1, // deletion
          curr[j - 1] + 1, // insertion
          prev[j - 1] + cost, // substitution
        );
        if (i > 1 &&
            j > 1 &&
            a.codeUnitAt(i - 1) == b.codeUnitAt(j - 2) &&
            a.codeUnitAt(i - 2) == b.codeUnitAt(j - 1)) {
          val = val < prev[j - 2] + cost
              ? val
              : prev[j - 2] + cost; // transposition
        }
        curr[j] = val;
        if (val < minInRow) minInRow = val;
      }
      if (minInRow > maxDistance) return false; // early exit
      final tmp = prev;
      prev = curr;
      curr = tmp;
    }
    return prev[n] <= maxDistance;
  }

  static int _min3(int a, int b, int c) =>
      (a < b ? (a < c ? a : c) : (b < c ? b : c));
}
