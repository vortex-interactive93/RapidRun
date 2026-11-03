# File: tool/enrich_bbw_mens.py

import json
import os
import re
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional

MENS_SCENT_DICTIONARY = {
    "ocean": {
        "family": "Fresh Aquatic Wood",
        "top": ["Blue Cypress", "Fresh Vetiver"],
        "heart": ["Coastal Air", "Salty Waves"],
        "base": ["Warm Cedar", "Oakmoss"],
        "description": "An invigorating splash of blue cypress, fresh vetiver and coastal air."
    },
    "mahogany teakwood": {
        "family": "Rich Bold Wood",
        "top": ["Rich Mahogany", "Lavender Herb"],
        "heart": ["Black Teakwood", "Geranium Leaf"],
        "base": ["Dark Oak", "Frosted Cedar"],
        "description": "A rich, bold, woodsy classic blend of rich mahogany, black teakwood, dark oak and frosted cedar."
    },
    "noir": {
        "family": "Bold Amber & Vanilla",
        "top": ["Black Cardamom", "Smoky Vanilla"],
        "heart": ["Clary Sage", "Rich Amber"],
        "base": ["Dark Musk", "Cedarwood"],
        "description": "An intoxicating, dark, sophisticated blend of black cardamom, smoky vanilla and musk."
    },
    "bourbon": {
        "family": "Warm Oak & Spice",
        "top": ["White Pepper", "Dark Amber"],
        "heart": ["Kentucky Bourbon", "Oak Barrel"],
        "base": ["Warm Vanilla", "Sandalwood"],
        "description": "A smooth, rich blend of white pepper, dark amber and Kentucky oak barrel bourbon."
    },
    "graphite": {
        "family": "Fresh Woody Citrus",
        "top": ["Sage Leaf", "Crisp Bergamot"],
        "heart": ["Leather Spice", "Fresh Cedar"],
        "base": ["Dark Woods", "Musk"],
        "description": "A bold, invigorating blend of sage, crisp bergamot and dark leather woods."
    },
    "whiskey reserve": {
        "family": "Rich Barrel Amber",
        "top": ["Crisp Apple", "Aged Whiskey"],
        "heart": ["Warm Amber", "Smoky Oak"],
        "base": ["Vanilla Spice", "Cedar"],
        "description": "A smooth, distinguished blend of crisp apple, aged whiskey and warm amber."
    },
    "freshwater": {
        "family": "Clean Aquatic Citrus",
        "top": ["Italian Bergamot", "Mountain Spring Water"],
        "heart": ["Oakmoss", "Fresh Sage"],
        "base": ["White Cedar", "Soft Musk"],
        "description": "A clean, cool, refreshing splash of Italian bergamot, mountain spring water and oakmoss."
    },
    "coffee & whiskey": {
        "family": "Warm Rich Spirit",
        "top": ["Bold Irish Coffee", "Whiskey Barrel"],
        "heart": ["Vanilla Bean", "Roasted Espresso"],
        "base": ["Aged Amber", "Rich Cedar"],
        "description": "A rich, smooth blend of bold Irish coffee, barrel-aged whiskey and warm vanilla."
    }
}

def clean_price(val: Any) -> Optional[float]:
    if not val:
        return None
    cleaned = re.sub(r"[^\d.]", "", str(val))
    try:
        return float(cleaned)
    except ValueError:
        return None

def clean_title(text: str) -> str:
    cleaned = text.replace("&trade;", "™").replace("â„¢", "™").replace("&amp;", "&")
    return re.sub(r"\s+", " ", cleaned).strip()

def extract_rating(text: Optional[str]) -> float:
    if not text:
        return 4.8
    match = re.search(r"(\d+\.\d+)\s+out of 5", str(text))
    return float(match.group(1)) if match else 4.8

def resolve_price(raw_price: Optional[str], sub_cat: str, title: str) -> (float, float):
    parsed = clean_price(raw_price)
    if parsed and parsed > 0:
        return (parsed, parsed)
    combined = title.lower()
    if sub_cat == "Men's fragrance":
        if "mini" in combined:
            return (17.95, 17.95)
        return (59.95, 59.95)
    if sub_cat == "Deodorant":
        return (14.95, 14.95)
    if sub_cat == "Moisturizers":
        return (17.95, 17.95)
    if sub_cat == "Body Wash":
        return (15.95, 15.95)
    return (16.95, 16.95)

def resolve_unit(sub_cat: str, title: str) -> (str, str):
    combined = title.lower()
    if sub_cat == "Men's fragrance":
        if "mini" in combined or "0.5" in combined:
            return ("0.5 fl oz / 15 mL", "0.5 fl oz")
        return ("3.4 fl oz / 100 mL", "3.4 fl oz")
    if sub_cat == "Deodorant":
        return ("2.7 oz / 76 g", "2.7 oz")
    if sub_cat == "Moisturizers":
        if "travel" in combined or "2.5" in combined:
            return ("2.5 oz / 70 g", "2.5 oz")
        return ("8 oz / 226 g", "8 oz")
    if sub_cat == "Body Wash":
        if "travel" in combined or "3 fl oz" in combined:
            return ("3 fl oz / 88 mL", "3 fl oz")
        return ("10 fl oz / 295 mL", "10 fl oz")
    if "soap" in combined or "bar" in combined:
        return ("5 oz / 141 g", "5 oz")
    return ("3.7 oz / 104 g", "3.7 oz")

def get_scent_profile(scent_name: str, name: str) -> Dict[str, Any]:
    search_key = scent_name.lower().strip().replace("+", "and").replace("&", "and")
    if not search_key:
        search_key = name.lower().strip().replace("+", "and").replace("&", "and")

    for k, profile in MENS_SCENT_DICTIONARY.items():
        clean_k = k.replace("+", "and").replace("&", "and")
        if clean_k in search_key or search_key in clean_k:
            return profile

    return {
        "family": "Fresh Masculine Wood",
        "top": ["Crisp Bergamot", "Fresh Sage"],
        "heart": ["Blue Cypress", "Spiced Cardamom"],
        "base": ["Warm Amber", "Rich Cedar"],
        "description": f"Formulated for men with natural essential oils to leave skin clean, refreshed, and subtly fragranced with notes of {name}."
    }

def classify_sub_category(item: Dict[str, Any]) -> str:
    desc = (item.get("description") or "").strip().lower()
    title = (item.get("wick_image_description") or "").strip().lower()

    if "cologne" in desc or "cologne" in title:
        return "Men's fragrance"
    elif "antiperspirant" in desc or "antiperspirant" in title or ("deodorant" in desc and "spray" not in desc) or ("deodorant" in title and "spray" not in title):
        return "Deodorant"
    elif "wash" in desc or "wash" in title:
        return "Body Wash"
    elif "cream" in desc or "lotion" in desc or "moisturiz" in desc or "cream" in title or "lotion" in title:
        return "Moisturizers"
    else:
        return "All men's body care"

def process_mens_shop(input_path: Path, repo_root: Path):
    with open(input_path, "r", encoding="utf-8") as f:
        raw_items = json.load(f)

    print(f"📦 Loaded {len(raw_items)} source items from: {input_path.name}")

    sub_cat_map = {
        "All men's body care": "bbw_mens_body_care.json",
        "Men's fragrance": "bbw_mens_fragrance.json",
        "Body Wash": "bbw_mens_body_wash.json",
        "Moisturizers": "bbw_mens_moisturizers.json",
        "Deodorant": "bbw_mens_deodorant.json",
    }

    categorized_items: Dict[str, List[Dict[str, Any]]] = {k: [] for k in sub_cat_map.keys()}

    for i, item in enumerate(raw_items, start=1):
        url = item.get("wick_linkbox__overlay_url") or item.get("product_url") or ""
        sku_match = re.search(r"(\d{8,10})$", url) or re.search(r"-(\d{8,10})(?:\?|$)", url)
        sku = sku_match.group(1) if sku_match else f"m_{i:04d}"

        scent_name = (item.get("wick_linkbox__overlay") or item.get("product_name") or "Men's Shop").strip()
        raw_title = item.get("wick_image_description") or item.get("product_full_title") or f"{scent_name} Body Spray"
        full_title = clean_title(raw_title)

        sub_cat = classify_sub_category(item)
        raw_price_str = item.get("emotion_1x439jo") or item.get("emotion_hjuxxk") or item.get("price")
        sale_price, msrp_price = resolve_price(raw_price_str, sub_cat, full_title)
        rating = extract_rating(item.get("bv_off_screen") or item.get("reviews"))

        img_url = (item.get("wick_image_image") or "").replace("sw=1280", "sw=600")
        vol, vol_short = resolve_unit(sub_cat, full_title)
        profile = get_scent_profile(scent_name, full_title)

        if sub_cat == "Men's fragrance":
            desc = "Masterfully crafted Men's Cologne formulated with a high concentration of essential fragrance oils for a long-lasting scent signature."
        elif sub_cat == "Deodorant":
            desc = "Antiperspirant Deodorant stick provides 24-hour sweat and odor protection to keep you feeling dry, fresh, and confident."
        elif sub_cat == "Body Wash":
            desc = "3-in-1 Hair, Face & Body Wash with nourishing aloe and vitamin E leaves skin and hair clean, soft, and invigorated."
        elif sub_cat == "Moisturizers":
            desc = "Ultimate Hydration Body Cream with rich shea butter and hyaluronic acid provides 24-hour moisture for smooth, nourished skin."
        else:
            desc = "Deodorizing Body Spray provides all-over body fragrance and odor protection for lasting freshness throughout the day."

        base_product = {
            "id": f"bbw_{sku}",
            "name": full_title,
            "brand": "Bath & Body Works",
            "store": "bath_and_body_works",
            "category": "Men's Shop",
            "subCategory": sub_cat,
            "price": sale_price,
            "msrp": msrp_price,
            "rating": rating,
            "unit": vol,
            "unitShort": vol_short,
            "imageUrl": img_url,
            "description": desc,
            "tags": ["bath_and_body_works", "mens_shop", sub_cat.lower().replace(" ", "_"), scent_name.lower()],
            "cleanStandards": ["Formulated For Men", "Natural Essential Oils", "Dermatologist Tested"],
            "fragranceProfile": {
                "family": profile["family"],
                "topNotes": profile["top"],
                "heartNotes": profile["heart"],
                "baseNotes": profile["base"]
            }
        }

        categorized_items[sub_cat].append(base_product)

    out_dir = repo_root / "assets" / "stores" / "bath_and_body_works" / "mens_shop"
    out_dir.mkdir(parents=True, exist_ok=True)

    for cat_name, filename in sub_cat_map.items():
        items_list = categorized_items[cat_name]
        out_file = out_dir / filename
        with open(out_file, "w", encoding="utf-8") as f:
            json.dump(items_list, f, indent=2)
        print(f"🎉 Compiled {len(items_list)} items for '{cat_name}' to: {out_file.name}")

if __name__ == "__main__":
    repo_root = Path(__file__).resolve().parent.parent
    downloads_dir = Path.home() / "Downloads"

    input_matches = list(downloads_dir.glob("men-s-shop--body-care--cologne---more---bath---body-works-*.json"))
    if not input_matches:
        input_matches = list(repo_root.glob("**/men-s-shop--body-care--cologne---more---bath---body-works-*.json"))

    if not input_matches:
        print("❌ Could not locate input men's shop JSON file.")
        sys.exit(1)

    process_mens_shop(input_matches[0], repo_root)
