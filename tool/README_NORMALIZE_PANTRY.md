# Walmart Pantry Normalization

This tooling converts raw Walmart pantry JSON dumps into the unified product schema used in the app.

## Input
Place raw JSON files in a folder (default: `./downloads/pantry`). Each file should be an array of objects. Expected legacy keys:
- `name` or `w_iuh7`
- `image` or `imageUrl`
- `price` string containing a dollar amount (e.g. `"current price Now $1.68"`)

Some provided stubs only include `price`; those rows will be skipped because we cannot infer `name` or `imageUrl`.

## Config
Configuration: `tool/normalize_config.json`
- `storeId`: always "walmart"
- `category`: top-level category ("Pantry")
- `files`: list of objects `{ "file": "filename.json", "subCategory": "Readable Subcategory" }`

## Output
Normalized files written (overwritten) to `assets/stores/walmart/<filename>.json` each an array of objects with fields:
```
{
  id: string,              // walmart_<slug>_NNN
  name: string,
  price: number,           // parsed numeric
  imageUrl: string,
  description: null,
  benefits: null,
  unit: string|null,       // heuristic from name (e.g. "15.25 oz")
  storeId: "walmart",
  category: "Pantry",
  subCategory: string
}
```
Deduplication is by exact name.

## Running
From repo root:
```
dart run tool/normalize_walmart_pantries.dart --rawDir=./downloads/pantry
```
Adjust `--rawDir` if your raw files live elsewhere.

## Extending
1. Add a new entry in `normalize_config.json` with its subCategory.
2. Drop the raw file in the raw directory.
3. Re-run the script.

## Notes
- If a file has only price entries, its normalized output will be empty; supply enriched data to populate it.
- Unit extraction is heuristic; adjust `extractUnit` if you need more patterns.
- Further enrichment (description, benefits) can be layered later.
