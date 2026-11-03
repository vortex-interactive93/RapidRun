/// Pure merge utilities extracted from stateful services so we can
/// unit test merge semantics without needing Firebase or SharedPreferences.
/// These mirrors the logic implemented inside FavoritesService & CartService.

/// Merge favorite IDs: returns union of local + remote.  If [remote]
/// contains IDs already present locally they remain; order not preserved.
Set<String> mergeFavorites(Set<String> local, Iterable<String> remote) {
  final merged = <String>{...local, ...remote};
  return merged;
}

/// Merge cart quantities by taking the max quantity per product id.
/// Returns a new map (does not mutate inputs) representing the merged state.
Map<String, int> mergeCartQuantities(
  Map<String, int> local,
  Map<String, int> remote,
) {
  final out = <String, int>{};
  // Start with local
  local.forEach((k, v) {
    if (v > 0) out[k] = v;
  });
  // Integrate remote, prefer larger positive quantity
  remote.forEach((k, rv) {
    final lv = out[k] ?? 0;
    final merged = rv > lv ? rv : lv;
    if (merged > 0) out[k] = merged;
  });
  return out;
}
