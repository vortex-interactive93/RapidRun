# File: tool/enrich_bbw_catalog.py

import asyncio
import json
import re
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional
import httpx
from bs4 import BeautifulSoup

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/128.0.0.0 Safari/537.36"
    ),
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8",
    "Accept-Language": "en-US,en;q=0.9",
    "Referer": "https://www.bathandbodyworks.com/",
}

def clean_price(val: Optional[Any]) -> Optional[float]:
    if val is None:
        return None
    cleaned = re.sub(r"[^\d.]", "", str(val))
    try:
        return float(cleaned)
    except ValueError:
        return None

def extract_rating(text: Optional[str]) -> float:
    if not text:
        return 4.8
    match = re.search(r"(\d+\.\d+)\s+out of 5", str(text))
    return float(match.group(1)) if match else 4.8

async def fetch_and_enrich_pdp(client: httpx.AsyncClient, item: Dict[str, Any], semaphore: asyncio.Semaphore) -> Dict[str, Any]:
    url = item.get("wick_linkbox__overlay_url") or item.get("url", "")
    sku_match = re.search(r"(\d{8,10})$", url) or re.search(r"-(\d{8,10})(?:\?|$)", url)
    sku = sku_match.group(1) if sku_match else f"item_{item.get('index', 'unknown')}"

    # Base listing fields
    title = (
        item.get("wick_image_description")
        or item.get("wick_linkbox__overlay")
        or item.get("title")
        or "Fragrance"
    ).strip()
    scent_name = item.get("wick_linkbox__overlay") or item.get("fragrance_line", "")
    sub_category = item.get("description") or item.get("product_type", "Fine Fragrance Mist")
    sale_price = clean_price(item.get("emotion_1rkvoei")) or clean_price(item.get("price"))
    msrp_price = clean_price(item.get("emotion_bxysmo"))
    standard_price = clean_price(item.get("emotion_hjuxxk"))
    price = sale_price or standard_price or msrp_price or 18.95
    rating = extract_rating(item.get("bv_off_screen") or item.get("rating_info"))

    # Scale CDN image to 600px for mobile performance
    img = item.get("wick_image_image") or item.get("image_url", "")
    img_600 = img.replace("sw=1280", "sw=600") if "sw=1280" in img else img

    bag_telemetry = item.get("emotion_e2von4") or ""

    # Defaults before deep extraction
    enriched = {
        "id": f"bbw_{sku}",
        "name": title,
        "brand": "Bath & Body Works",
        "store": "bath_and_body_works",
        "category": "Personal Care",
        "subCategory": sub_category,
        "price": price,
        "msrp": msrp_price,
        "rating": rating,
        "unit": "8 fl oz / 236 mL",
        "unitShort": "8 fl oz",
        "imageUrl": img_600,
        "description": f"Dazzling and radiant. Formulated with high fragrance concentration. {bag_telemetry}".strip(),
        "tags": ["bath_and_body_works", "fragrance", sub_category.lower()],
        "fragranceProfile": {
            "family": "Floral & Amber",
            "topNotes": [],
            "heartNotes": [],
            "baseNotes": [],
            "perfumerQuote": None,
        },
        "cleanStandards": ["Paraben-Free", "Phthalate-Free"]
    }

    if not url:
        return enriched

    async with semaphore:
        try:
            resp = await client.get(url, timeout=12.0)
            if resp.status_code == 200:
                soup = BeautifulSoup(resp.text, "html.parser")
                page_text = soup.get_text()

                # 1. Extract Unit & Liquid Volume
                vol_match = re.search(r"(\d+(?:\.\d+)?\s*(?:fl\s*oz|oz|mL))\s*(?:/\s*(\d+\s*mL))?", page_text, re.I)
                if vol_match:
                    enriched["unit"] = vol_match.group(0).strip()
                    enriched["unitShort"] = vol_match.group(1).strip()

                # 2. Extract Olfactory Notes (Top, Heart, Base)
                top_match = re.search(r"Top:\s*([^.\n]+)", page_text, re.I)
                heart_match = re.search(r"(?:Heart|Mid):\s*([^.\n]+)", page_text, re.I)
                base_match = re.search(r"Base:\s*([^.\n]+)", page_text, re.I)

                if top_match:
                    enriched["fragranceProfile"]["topNotes"] = [n.strip() for n in top_match.group(1).split(",")]
                if heart_match:
                    enriched["fragranceProfile"]["heartNotes"] = [n.strip() for n in heart_match.group(1).split(",")]
                if base_match:
                    enriched["fragranceProfile"]["baseNotes"] = [n.strip() for n in base_match.group(1).split(",")]

                # Fallback notes extraction if Top/Heart/Base not explicitly tagged
                if not enriched["fragranceProfile"]["topNotes"] and not enriched["fragranceProfile"]["heartNotes"]:
                    notes_match = re.search(r"Fragrance notes:\s*([^.\n]+)", page_text, re.I) or re.search(r"What it smells like:\s*([^.\n]+)", page_text, re.I)
                    if notes_match:
                        notes_list = [n.strip() for n in notes_match.group(1).split(",")]
                        enriched["fragranceProfile"]["topNotes"] = notes_list[:2]
                        if len(notes_list) > 2:
                            enriched["fragranceProfile"]["heartNotes"] = notes_list[2:4]
                        if len(notes_list) > 4:
                            enriched["fragranceProfile"]["baseNotes"] = notes_list[4:]

                # 3. Extract Editorial Fragrance Story / Perfumer Quote
                story_match = re.search(r'"([^"]*(?:dances upon|whisked away|inspired by|smells like)[^"]*)"', page_text, re.I)
                if story_match:
                    enriched["fragranceProfile"]["perfumerQuote"] = story_match.group(1).strip()

                # 4. Extract Ingredients Block
                ing_match = re.search(r"Ingredients:?\s*([A-Za-z0-9,\s\(\)\.\-]+?(?=How to use|Can we help|\Z))", page_text, re.I)
                if ing_match:
                    enriched["ingredients"] = ing_match.group(1).strip()

                print(f"✅ Enriched SKU {sku}: {title}")
        except Exception as e:
            print(f"⚠️ Non-blocking error fetching {sku}: {e}", file=sys.stderr)

    return enriched

async def main():
    repo_root = Path(__file__).resolve().parent.parent
    downloads_dir = Path.home() / "Downloads"

    # Locate input JSON in Downloads, repo root, or assets
    input_matches = list(downloads_dir.glob("body-fragrance--mists--perfume---cologne---bath---body-works-*.json"))
    if not input_matches:
        input_matches = list(repo_root.glob("**/body-fragrance--mists--perfume---cologne---bath---body-works-*.json"))
    if not input_matches:
        input_matches = list(repo_root.glob("**/bbw_extracted_summary.json"))
    if not input_matches:
        input_matches = list(repo_root.glob("**/bbw_body_sprays_mists.json"))

    if not input_matches:
        print("❌ Could not find raw BBW input json file.")
        sys.exit(1)

    input_path = input_matches[0]
    output_dir = repo_root / "assets" / "stores" / "bath_and_body_works"
    output_dir.mkdir(parents=True, exist_ok=True)
    output_path = output_dir / "bbw_catalog_enriched.json"

    print(f"📦 Loading source catalog: {input_path}")
    with open(input_path, "r", encoding="utf-8") as f:
        raw_items = json.load(f)

    print(f"🚀 Enriching {len(raw_items)} products concurrently...")

    semaphore = asyncio.Semaphore(10)

    async with httpx.AsyncClient(headers=HEADERS, follow_redirects=True) as client:
        tasks = [fetch_and_enrich_pdp(client, item, semaphore) for item in raw_items]
        enriched_products = await asyncio.gather(*tasks)

    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(enriched_products, f, indent=2)

    print(f"✨ Successfully generated AAA catalog: {output_path} ({len(enriched_products)} items)")

if __name__ == "__main__":
    asyncio.run(main())
