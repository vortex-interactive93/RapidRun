# File: tool/enrich_bbw_hand_soaps.py

import json
import os
import re
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional

HAND_SOAP_SCENT_DICTIONARY = {
    "champagne toast": {
        "family": "Fruity Citrus",
        "top": ["Vintage Champagne", "Sparkling Berries"],
        "heart": ["Juicy Tangerine", "Nectarine Blossom"],
        "base": ["Sugared Musk", "Soft Amber"],
        "description": "A festive, bubbly celebration of vintage champagne, sparkling berries and juicy tangerine."
    },
    "strawberry pound cake": {
        "family": "Gourmand Sweet Berry",
        "top": ["Fresh Strawberries", "Wild Strawberries"],
        "heart": ["Golden Shortcake", "Baking Spice"],
        "base": ["Whipped Cream", "Vanilla Sugar"],
        "description": "A sweet, airy, freshly baked treat of fresh strawberries, golden shortcake and whipped cream."
    },
    "strawberry snowflakes": {
        "family": "Sweet Winter Berry",
        "top": ["Juicy Strawberry", "Iced Bergamot"],
        "heart": ["Whipped Cream", "Winter Blossom"],
        "base": ["Iced Vanilla", "Soft Musk"],
        "description": "A sweet, frosted winter berry dream of juicy strawberry, whipped cream and iced vanilla."
    },
    "champagne apple & honey": {
        "family": "Fruity Autumn Apple",
        "top": ["Pink Lady Apple", "Sparkling Champagne"],
        "heart": ["Jasmine Honey", "Autumn Woods"],
        "base": ["Sugared Amber", "Soft Musk"],
        "description": "A crisp, sweet, autumn orchard celebration of pink lady apple, sparkling champagne and jasmine honey."
    },
    "a thousand wishes": {
        "family": "Fruity Floral & Amber",
        "top": ["Pink Prosecco", "Starfruit", "Golden Quince"],
        "heart": ["Crystal Peonies", "Purple Freesia"],
        "base": ["Amaretto Crème", "Warm Amber", "Sugared Musk"],
        "description": "Warm, sparkling, sweet fragrance blend of pink prosecco, sparkling quince, crystal peonies and gilded amber."
    },
    "japanese cherry blossom": {
        "family": "Warm Floral",
        "top": ["Asian Pear", "Fuji Apple"],
        "heart": ["Japanese Cherry Blossom", "Mimosa Petals"],
        "base": ["Vanilla Rice", "Blushing Sandalwood"],
        "description": "An iconic, graceful blend of Japanese cherry blossom, Asian pear, fresh mimosa petals, white jasmine and blushing sandalwood."
    },
    "into the night": {
        "family": "Amber Floral & Musk",
        "top": ["Raspberry Noir", "Midnight Blackberries"],
        "heart": ["Velvety Rose Petals", "Night-Blooming Jasmine"],
        "base": ["Amber Crystals", "Mocha Musk"],
        "description": "An alluring, timeless blend of dark berries, midnight jasmine and rich amber."
    },
    "mahogany teakwood": {
        "family": "Rich Bold Wood",
        "top": ["Rich Mahogany", "Lavender Herb"],
        "heart": ["Black Teakwood", "Geranium Leaf"],
        "base": ["Dark Oak", "Frosted Cedar"],
        "description": "A rich, bold, woodsy classic blend of rich mahogany, black teakwood, dark oak and frosted cedar."
    },
    "sweater weather": {
        "family": "Fresh Crisp Autumn",
        "top": ["Fresh Sage", "Crisp Eucalyptus"],
        "heart": ["Autumn Apple", "Juniper Berry"],
        "base": ["Woods", "Soft Musk"],
        "description": "A fresh, crisp autumn walk in the woods scented with fresh sage, crisp eucalyptus, and autumn apple."
    },
    "leaves": {
        "family": "Warm Autumn Spice",
        "top": ["Crisp Red Apple", "Golden Nectar"],
        "heart": ["Warm Clove Spice", "Autumn Cinnamon"],
        "base": ["Spiced Clove", "Sheer Amber"],
        "description": "The quintessential scent of autumn crisp air with crisp red apple, golden nectar and warm clove spice."
    },
    "eucalyptus spearmint": {
        "family": "Aromatherapy Fresh Mint",
        "top": ["Fresh Eucalyptus", "Crisp Spearmint"],
        "heart": ["Clary Sage", "Peppermint Leaf"],
        "base": ["Clean Cedar", "Soft Woods"],
        "description": "An energizing, stress-relieving herbal sanctuary made with natural eucalyptus and spearmint essential oils."
    },
    "fresh balsam": {
        "family": "Fresh Pine & Forest",
        "top": ["Woodland Balsam", "Crisp Eucalyptus"],
        "heart": ["Fir Branches", "Pine Needles"],
        "base": ["Cedarwood", "Earthy Musk"],
        "description": "The fresh, invigorating scent of a evergreen forest with woodland balsam, crisp eucalyptus and cedarwood."
    },
    "warm vanilla sugar": {
        "family": "Warm Gourmand",
        "top": ["Sheer Florals", "Vanilla Orchid"],
        "heart": ["Vanilla Absolute", "Basmati Rice"],
        "base": ["Warm Vanilla", "White Sandalwood"],
        "description": "A cozy, enveloping, sweet comfort of sheer florals, vanilla absolute, basmati rice and warm vanilla."
    },
    "kitchen lemon": {
        "family": "Bright Zesty Citrus",
        "top": ["Zesty Fresh Lemon", "Sparkling Citrus"],
        "heart": ["Spearmint Leaf", "Italian Bergamot"],
        "base": ["Clean Woods", "Soft Musk"],
        "description": "Bright, uplifting, freshly squeezed kitchen lemons with a hint of mint."
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

def resolve_price(raw_price: Optional[str], sub_cat: str) -> (float, float):
    parsed = clean_price(raw_price)
    if parsed and parsed > 0:
        return (parsed, parsed)
    if sub_cat == "All Hand Sanitizers":
        return (1.95, 1.95)
    if sub_cat == "Foaming Hand Soaps Refills":
        return (13.95, 13.95)
    if sub_cat == "Soap Holders & Dispensers":
        return (12.95, 12.95)
    return (7.95, 7.95)

def resolve_unit(sub_cat: str, title: str) -> (str, str):
    combined = title.lower()
    if sub_cat == "Foaming Hand Soaps Refills":
        return ("36 fl oz / 1.06 L", "36 fl oz")
    if sub_cat == "Soap Holders & Dispensers":
        return ("1 ct", "1 ct")
    if sub_cat == "All Hand Sanitizers":
        if "holder" in combined:
            return ("1 ct", "1 ct")
        if "spray" in combined:
            return ("3 fl oz / 88 mL", "3 fl oz")
        if "pump" in combined or "7.6" in combined or "8 fl oz" in combined:
            return ("7.6 fl oz / 225 mL", "7.6 fl oz")
        return ("1 fl oz / 29 mL", "1 fl oz")
    if "8 fl oz" in combined or "gel" in combined:
        return ("8 fl oz / 236 mL", "8 fl oz")
    return ("8.75 fl oz / 258 mL", "8.75 fl oz")

def get_scent_profile(scent_name: str, name: str) -> Dict[str, Any]:
    search_key = scent_name.lower().strip().replace("+", "and").replace("&", "and")
    if not search_key:
        search_key = name.lower().strip().replace("+", "and").replace("&", "and")

    for k, profile in HAND_SOAP_SCENT_DICTIONARY.items():
        clean_k = k.replace("+", "and").replace("&", "and")
        if clean_k in search_key or search_key in clean_k:
            return profile

    return {
        "family": "Nourishing Fresh Scent",
        "top": ["Fresh Bergamot", "Wild Plum"],
        "heart": ["Soft Jasmine", "Rose Petals"],
        "base": ["Warm Amber", "Cedarwood"],
        "description": f"Formulated with natural essential oils to leave hands clean, soft, and beautifully fragranced with notes of {name}."
    }

def classify_sub_category(item: Dict[str, Any]) -> str:
    desc = (item.get("description") or "").strip().lower()
    title = (item.get("wick_image_description") or "").strip().lower()

    if "refill" in desc or "refill" in title:
        return "Foaming Hand Soaps Refills"
    elif "cleansing gel" in desc or "gel hand soap" in desc or "gel soap" in title:
        return "Gel Soaps"
    elif "moisturizing" in desc and "soap" in desc:
        return "Moisturizing Hand Soaps"
    elif "revitalizing" in desc and "soap" in desc:
        return "Revitalizing Hand Soaps"
    elif "foaming" in desc or "foaming" in title:
        return "Foaming Soaps"
    elif "soap holder" in desc or "soap holder" in title:
        return "Soap Holders & Dispensers"
    elif "sanitizer" in desc or "pocketbac" in desc or "sanitizer" in title or "pocketbac" in title or "pocketspray" in desc or "pocketspray" in title:
        return "All Hand Sanitizers"
    return "Foaming Soaps"

def process_hand_soaps_and_sanitizers(input_path: Path, repo_root: Path):
    with open(input_path, "r", encoding="utf-8") as f:
        raw_items = json.load(f)

    print(f"📦 Loaded {len(raw_items)} source items from: {input_path.name}")

    sub_cat_map = {
        "Foaming Soaps": "bbw_foaming_soaps.json",
        "Gel Soaps": "bbw_gel_soaps.json",
        "Moisturizing Hand Soaps": "bbw_moisturizing_soaps.json",
        "Revitalizing Hand Soaps": "bbw_revitalizing_soaps.json",
        "Foaming Hand Soaps Refills": "bbw_soap_refills.json",
        "Soap Holders & Dispensers": "bbw_soap_holders.json",
        "All Hand Sanitizers": "bbw_hand_sanitizers.json",
    }

    categorized_items: Dict[str, List[Dict[str, Any]]] = {k: [] for k in sub_cat_map.keys()}

    for i, item in enumerate(raw_items, start=1):
        url = item.get("wick_linkbox__overlay_url") or item.get("product_url") or ""
        sku_match = re.search(r"(\d{8,10})$", url) or re.search(r"-(\d{8,10})(?:\?|$)", url)
        sku = sku_match.group(1) if sku_match else f"hs_{i:04d}"

        scent_name = (item.get("wick_linkbox__overlay") or item.get("product_name") or "Hand Soap").strip()
        raw_title = item.get("wick_image_description") or item.get("product_full_title") or f"{scent_name} Hand Soap"
        full_title = clean_title(raw_title)

        sub_cat = classify_sub_category(item)
        raw_price_str = item.get("emotion_1x439jo") or item.get("emotion_hjuxxk") or item.get("price")
        sale_price, msrp_price = resolve_price(raw_price_str, sub_cat)
        rating = extract_rating(item.get("bv_off_screen") or item.get("reviews"))

        img_url = (item.get("wick_image_image") or "").replace("sw=1280", "sw=600")
        vol, vol_short = resolve_unit(sub_cat, full_title)
        profile = get_scent_profile(scent_name, full_title)

        if sub_cat == "Foaming Soaps":
            desc = "Gentle & Clean Foaming Hand Soap made with natural essential oils, vitamin E, shea extract, and aloe for a rich, creamy lather."
        elif sub_cat == "Gel Soaps":
            desc = "Cleansing Gel Hand Soap formulated with natural essential oils and soothing vitamin E for a deep, refreshing clean."
        elif sub_cat == "Moisturizing Hand Soaps":
            desc = "Daily Moisturizing Hand Soap rich in shea butter, cocoa butter, and coconut oil to lock in skin moisture."
        elif sub_cat == "Revitalizing Hand Soaps":
            desc = "Revitalizing Hand Soap with gentle exfoliating micro-beads and essential oils to leave hands smooth and renewed."
        elif sub_cat == "Foaming Hand Soaps Refills":
            desc = "Eco-friendly 36 fl oz carton refill fills over 4 standard Bath & Body Works foaming hand soap bottles."
        elif sub_cat == "Soap Holders & Dispensers":
            desc = "Decorative soap holder sleeve designed to fit standard Bath & Body Works foaming and gel hand soap bottles."
        else:
            desc = "Kills 99.9% of most common germs while nourishing skin with essential oils, aloe, and vitamin E."

        base_product = {
            "id": f"bbw_{sku}",
            "name": full_title,
            "brand": "Bath & Body Works",
            "store": "bath_and_body_works",
            "category": "Hand Soaps & Sanitizers",
            "subCategory": sub_cat,
            "price": sale_price,
            "msrp": msrp_price,
            "rating": rating,
            "unit": vol,
            "unitShort": vol_short,
            "imageUrl": img_url,
            "description": desc,
            "tags": ["bath_and_body_works", "hand_soaps_sanitizers", sub_cat.lower().replace(" ", "_"), scent_name.lower()],
            "cleanStandards": ["Natural Essential Oils", "Triclosan Free Formula", "Dermatologist Tested"]
        }

        if "holder" not in sub_cat.lower() and "dispenser" not in sub_cat.lower():
            base_product["fragranceProfile"] = {
                "family": profile["family"],
                "topNotes": profile["top"],
                "heartNotes": profile["heart"],
                "baseNotes": profile["base"]
            }

        categorized_items[sub_cat].append(base_product)

    out_dir = repo_root / "assets" / "stores" / "bath_and_body_works" / "hand_soaps_sanitizers"
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

    input_matches = list(downloads_dir.glob("hand-soap---hand-sanitizer--every-scent---bath---body-works-*.json"))
    if not input_matches:
        input_matches = list(repo_root.glob("**/hand-soap---hand-sanitizer--every-scent---bath---body-works-*.json"))

    if not input_matches:
        print("❌ Could not locate input hand soaps JSON file.")
        sys.exit(1)

    process_hand_soaps_and_sanitizers(input_matches[0], repo_root)
