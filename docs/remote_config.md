# Remote Config (Firestore) for RapidRun

This app reads a single Firestore document to control feature gating and which stores are visible during beta.

Collection: `config`
Document: `app`

Fields (JSON example):

```json
{
  "inviteOnly": true,
  "paymentsTestOnly": true,
  "shoppingFeaturedNames": ["walmart"],
  "takeoutFeaturedIds": ["taco_bell"],
  "betaBannerText": "Beta – test payments only. Limited features for now.",
  "updatedAt": {"_serverTimestamp": true}
}
```

Notes:
- `shoppingFeaturedNames`: match against retailer display names in the Shopping & Delivery screen, lowercased (e.g., "walmart").
- `takeoutFeaturedIds`: match against restaurant ids in Takeout (e.g., "taco_bell").
- If any list is empty/missing, defaults are used (Walmart / Taco Bell).
- The app streams changes and updates UI live.

## Where it’s used
- `lib/services/config_service.dart`: singleton reader/streamer (`config/app`).
- `lib/screens/shopping_delivery/shopping_delivery_screen.dart`: filters retailers.
- `lib/screens/takeout/takeout_screen.dart`: filters restaurants.
- `lib/screens/home/home_page.dart`: clamps recommendation filters and content.
- `lib/screens/settings/settings_screen.dart`: shows a diagnostics banner with config values.

## Deploying rules
Ensure Firestore rules allow public read for `config/*` and admin-only writes (already implemented in `firestore.rules`).
