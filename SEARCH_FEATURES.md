## Search Features Overview

Implemented capabilities:
1. Store-scoped search via route `/store-search/<store>`.
2. Debounced (300ms) incremental searching.
3. Result scoring (prefix, word-boundary, tag, category, substring fallback).
4. Category facet filter (horizontal chips) for active store.
5. Recent searches (persisted per store, last 5).
6. Term highlighting inside product names.

### Store Facet Filters (Clarification)
In a multi-store global search scenario, "store facet filters" let users run one query across all stores and then narrow results by selecting one or more store chips (facets). Current implementation instead chooses the store up front (store-scoped). To add true store facets, you'd:
* Aggregate all products across stores in a global search service.
* Return results + counts per store (facet counts).
* Render chips like: `All (120)  Aldi (45)  Target (40)  Walmart (35)`; toggling a chip refines the visible subset without re-query (or triggers refined query if using server-side facet counts).

### Next Potential Enhancements
| Feature | Effort | Notes |
|---------|--------|-------|
| Global multi-store search with store facets | Medium | Add `searchAll(query)` returning map<store,List<Product>> + counts. |
| Tag/price filters | Low | Additional chips/sliders. |
| Fuzzy matching (typo tolerance) | Medium | Implement Damerau-Levenshtein threshold or integrate a lightweight fuzzy lib. |
| Highlight multiple terms / tokenization | Low | Split query on whitespace; highlight each token. |
| Ranking telemetry | Low | Log selections to refine boosting. |

### Scoring Summary
```
 +120 name startsWith(query)
 +70 word boundary match in name
 +80 exact tag == query
 +50 tag startsWith(query)
 +25 tag contains(query)
 +40 category == query (else +15 contains)
 +35 subCategory == query (else +12 contains)
 +20 generic substring (only if no higher boosts)
 -0.01 * name.length tie-breaker
```

---
Last updated: 2025-08-15
