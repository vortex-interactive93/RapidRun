# File: tool/enrich_bbw_minis.py

import json
import os
import re
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional

SCENT_DICTIONARY = {
    "a thousand wishes": {
        "family": "Fruity Floral & Amber",
        "top": ["Pink Prosecco", "Starfruit", "Golden Quince"],
        "heart": ["Crystal Peonies", "Purple Freesia"],
        "base": ["Amaretto Crème", "Warm Amber", "Sugared Musk"],
        "description": "Warm, sparkling, sweet fragrance in a travel-friendly size. Infused with shea butter, coconut oil and vitamin E."
    },
    "japanese cherry blossom": {
        "family": "Warm Floral",
        "top": ["Asian Pear", "Fuji Apple", "Ume Plum"],
        "heart": ["Japanese Cherry Blossom", "Butterfly Lily", "Kyoto Rose"],
        "base": ["Vanilla Rice", "Imperial Amber", "Silk Musk"],
        "description": "An iconic, graceful blend of Japanese cherry blossom, Asian pear, fresh mimosa petals, white jasmine and blushing sandalwood."
    },
    "champagne toast": {
        "family": "Fruity Citrus",
        "top": ["Vintage Champagne", "Sparkling Berries"],
        "heart": ["Juicy Tangerine", "Nectarine Blossom"],
        "base": ["Sugared Musk", "Soft Amber"],
        "description": "A fruity, sweet, sparkling celebration on the go. Scented with vintage champagne, sparkling berries and juicy tangerine."
    },
    "into the night": {
        "family": "Amber Floral & Musk",
        "top": ["Raspberry Noir", "Midnight Blackberries"],
        "heart": ["Velvety Rose Petals", "Night-Blooming Jasmine"],
        "base": ["Amber Crystals", "Mocha Musk", "Rich Patchouli"],
        "description": "An alluring, timeless, dark mystery. A captivating blend of dark berries, midnight jasmine and rich amber."
    },
    "butterfly": {
        "family": "Fruity Floral",
        "top": ["Raspberry Nectar", "Crisp Apple"],
        "heart": ["Iris Petals", "Pink Lotus"],
        "base": ["Airy Vanilla", "Soft Musk"],
        "description": "An inspiring, flight-of-fancy fragrance. Scented with raspberry nectar, iris petals and airy vanilla."
    },
    "strawberry pound cake": {
        "family": "Gourmand Sweet",
        "top": ["Fresh Strawberries", "Wild Strawberries"],
        "heart": ["Golden Shortcake", "Baking Spice"],
        "base": ["Whipped Cream", "Vanilla Sugar"],
        "description": "A sweet, airy, freshly baked treat. Scented with fresh strawberries, golden shortcake and whipped cream."
    },
    "gingham gorgeous": {
        "family": "Bright Floral",
        "top": ["Pink Strawberries", "Sun-Kissed Peach"],
        "heart": ["Peach Nectar", "Peony Petals"],
        "base": ["White Woods", "Soft Musk"],
        "description": "Our most gorgeous, floral Gingham yet. A happiest celebration of pink strawberries, peach nectar and peony petals."
    },
    "warm vanilla sugar": {
        "family": "Warm Gourmand",
        "top": ["Sheer Florals", "Vanilla Orchid"],
        "heart": ["Vanilla Absolute", "Basmati Rice", "Sweet Jasmine"],
        "base": ["Warm Vanilla", "White Sandalwood", "Brown Sugar"],
        "description": "A cozy, enveloping, sweet comfort. Scented with sheer florals, vanilla absolute, basmati rice and warm vanilla."
    },
    "at the beach": {
        "family": "Fresh Aquatic & Coconut",
        "top": ["Bergamot Waters", "Sea Salt"],
        "heart": ["Frangipani Blossoms", "Toasted Coconut"],
        "base": ["Sunkissed Sand", "Soft Driftwood"],
        "description": "A refreshing, sun-soaked day at the shore. Scented with frangipani blossoms, toasted coconut and bergamot waters."
    },
    "midnight addiction": {
        "family": "Rich Amber Plum",
        "top": ["Black Plum", "Dark Cherry"],
        "heart": ["Midnight Orchid", "Night Jasmine"],
        "base": ["Sheer Amber", "Vanilla Musk"],
        "description": "A dark, seductive, intoxicating fragrance. Formulated with black plum, midnight orchid and sheer amber."
    },
    "amber era": {
        "family": "Warm Woody Amber",
        "top": ["Golden Amber", "Bergamot Zest"],
        "heart": ["Rich Sandalwood", "Cashmere Wood"],
        "base": ["Warm Vanilla", "Velvet Musk"],
        "description": "An opulent, radiant amber scent. A warm blend of rich amber, golden sandalwood and warm vanilla."
    },
    "viva vanilla": {
        "family": "Decadent Gourmand",
        "top": ["Vanilla Bean", "Golden Plum"],
        "heart": ["Creamy Tonka", "Orchid Petals"],
        "base": ["Warm Amber", "Sugared Musk"],
        "description": "A rich, irresistible vanilla dream. Formulated with rich vanilla, creamy tonka bean and warm amber."
    },
    "touch of gold": {
        "family": "Gilded Floral Amber",
        "top": ["Sparkling Bergamot", "Golden Quince"],
        "heart": ["Golden Honey", "Solar Floral"],
        "base": ["Soft Cashmere Musk", "Warm Amber"],
        "description": "A luminous, gilded touch of luxury. Scented with golden honey, sparkling bergamot and soft cashmere musk."
    },
    "worth wanting": {
        "family": "Velvet Rose & Wood",
        "top": ["Wild Berries", "Pink Pepper"],
        "heart": ["Velvet Rose", "Damask Petals"],
        "base": ["Cashmere Wood", "Rich Patchouli"],
        "description": "An intoxicating, glamorous floral wood scent. Notes of wild berries, velvet rose and cashmere wood."
    },
    "platinum": {
        "family": "Crisp Woody Bergamot",
        "top": ["Sparkling Bergamot", "Crisp Apple"],
        "heart": ["Fresh Cypress", "Silver Cedar"],
        "base": ["Silver Amber", "Clean Musk"],
        "description": "A polished, brilliant, modern fragrance. Scented with sparkling bergamot, silver amber and fresh cypress."
    },
    "in the stars": {
        "family": "Warm Sparkle & Sandalwood",
        "top": ["Sugared Tangelo", "Starflower"],
        "heart": ["Sandalwood Musk", "White Borage"],
        "base": ["Agarwood", "Amber", "Radiant Musk"],
        "description": "A warm, sparkling, out-of-this-world fragrance. Made with starflower, sandalwood musk, sugared tangelo and radiant amber."
    },
    "orchid effect": {
        "family": "Lush Wild Floral",
        "top": ["Wild Orchid", "Mandarin Zest"],
        "heart": ["Midnight Plum", "Night Violet"],
        "base": ["Sheer Musk", "Velvet Sandalwood"],
        "description": "A lush, mysterious bloom. Formulated with wild orchid, midnight plum and sheer musk."
    },
    "midnight rouge": {
        "family": "Seductive Dark Floral",
        "top": ["Dark Rose", "Crimson Plum"],
        "heart": ["Velvet Amber", "Red Peony"],
        "base": ["Smoky Vanilla", "Rich Leather"],
        "description": "A bold, seductive crimson floral scent. Scented with dark rose, crimson plum and velvet amber."
    },
    "milk": {
        "family": "Comforting Creamy Gourmand",
        "top": ["Warm Milk", "Steamed Oat"],
        "heart": ["Oat Extract", "Almond Milk"],
        "base": ["Vanilla Bean", "Soft Sugared Musk"],
        "description": "A cozy, comforting, warm hug. Scented with warm milk, oat extract and vanilla bean."
    },
    "ocean": {
        "family": "Fresh Woody Aquatic",
        "top": ["Blue Cypress", "Crisp Air"],
        "heart": ["Coastal Vetiver", "Sea Salt Water"],
        "base": ["Ocean Driftwood", "Clean Cedar"],
        "description": "An invigorating dive into blue waters. Scented with blue cypress, coastal vetiver and ocean driftwood."
    },
    "noir": {
        "family": "Dark Woody Spice",
        "top": ["Black Cardamom", "Crisp Bergamot"],
        "heart": ["Smoky Vanilla", "Clary Sage"],
        "base": ["Rich Musk", "Dark Cedarwood"],
        "description": "A dark, mysterious, handsome scent. Scented with black cardamom, smoky vanilla and dark cedarwood."
    },
    "bourbon": {
        "family": "Warm Woody Amber",
        "top": ["White Pepper", "Crisp Bergamot"],
        "heart": ["Dark Amber", "Barrel Oak"],
        "base": ["Kentucky Bourbon", "Rich Cedar"],
        "description": "A smooth, warm, barrel-aged blend. Scented with white pepper, dark amber and Kentucky bourbon."
    },
    "graphite": {
        "family": "Fresh Bold Herbal Wood",
        "top": ["Sage Leaf", "Crisp Bergamot"],
        "heart": ["Leather Woods", "Geranium"],
        "base": ["Dense Cedar", "Vetiver"],
        "description": "A bold, modern, adventurous blend. Scented with sage leaf, leather woods and crisp bergamot."
    },
    "lavender vanilla": {
        "family": "Aromatherapy Relaxing Floral",
        "top": ["Lavender Oil", "Crisp Bergamot"],
        "heart": ["French Lavender", "Jasmine Petals"],
        "base": ["Vanilla Absolute", "Warm Amber"],
        "description": "A relaxing, soothing, tranquil evening ritual. Scented with natural lavender oil and vanilla absolute."
    },
    "eucalyptus spearmint": {
        "family": "Aromatherapy Eucalyptus Mint",
        "top": ["Eucalyptus Oil", "Spearmint Oil"],
        "heart": ["Clary Sage", "Peppermint Leaf"],
        "base": ["Clean Musk", "Soft Woods"],
        "description": "An energizing, restorative herbal blend. Formulated with eucalyptus and spearmint essential oils."
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

def extract_rating(text: Optional[str]) -> float:
    if not text:
        return 4.8
    match = re.search(r"(\d+\.\d+)\s+out of 5", str(text))
    return float(match.group(1)) if match else 4.8

def resolve_mini_volume(product_type: str, title: str) -> (str, str):
    combined = f"{product_type} {title}".lower()
    if "hand cream" in combined:
        return ("1 fl oz / 29 mL", "1 fl oz")
    if "cream" in combined or "butter" in combined:
        return ("2.5 oz / 70 g", "2.5 oz")
    if "mist" in combined or "spray" in combined or "lotion" in combined or "wash" in combined or "cologne" in combined:
        return ("2.5 fl oz / 75 mL", "2.5 fl oz")
    return ("2.5 fl oz / 75 mL", "2.5 fl oz")

def resolve_mini_price(product_type: str, title: str, raw_price: Optional[str]) -> (float, float):
    parsed = clean_price(raw_price)
    if parsed and parsed > 0:
        return (parsed, parsed)
    combined = f"{product_type} {title}".lower()
    if "mist" in combined or "spray" in combined or "cologne" in combined:
        return (9.95, 9.95)
    return (8.95, 8.95)

def get_scent_profile(scent_name: str, name: str) -> Dict[str, Any]:
    search_key = scent_name.lower().strip()
    if not search_key:
        search_key = name.lower().strip()

    for k, profile in SCENT_DICTIONARY.items():
        if k in search_key or search_key in k:
            return profile

    return {
        "family": "Travel Size Fragrance",
        "top": ["Fresh Bergamot", "Sparkling Citrus"],
        "heart": ["Soft Jasmine", "Rose Petals"],
        "base": ["Warm Amber", "Silk Musk"],
        "description": f"Travel-friendly size perfect for on-the-go nourishment. Scented with notes of {name}."
    }

def process_minis(input_path: Path, repo_root: Path):
    with open(input_path, "r", encoding="utf-8") as f:
        raw_items = json.load(f)

    print(f"📦 Loaded {len(raw_items)} source items from: {input_path.name}")

    minis_list = []

    for i, item in enumerate(raw_items, start=1):
        url = item.get("product_url") or ""
        sku_match = re.search(r"(\d{8,10})$", url) or re.search(r"-(\d{8,10})(?:\?|$)", url)
        sku = sku_match.group(1) if sku_match else f"tm_{i:04d}"

        scent_name = (item.get("product_name") or "Fragrance").strip()
        product_type = (item.get("product_type") or "Travel Size Fine Fragrance Mist").strip()
        full_title = (item.get("product_full_title") or f"{scent_name} {product_type}").strip()

        sale_price, msrp_price = resolve_mini_price(product_type, full_title, item.get("price"))
        rating = extract_rating(item.get("reviews"))

        img_url = (item.get("image_1") or item.get("image_2") or "").replace("sw=1280", "sw=600")
        vol, vol_short = resolve_mini_volume(product_type, full_title)
        profile = get_scent_profile(scent_name, full_title)

        base_product = {
            "id": f"bbw_{sku}",
            "name": full_title,
            "brand": "Bath & Body Works",
            "store": "bath_and_body_works",
            "category": "Body Care",
            "subCategory": product_type,
            "price": sale_price,
            "msrp": msrp_price,
            "rating": rating,
            "unit": vol,
            "unitShort": vol_short,
            "imageUrl": img_url,
            "description": profile["description"],
            "tags": ["bath_and_body_works", "body_care", "minis", "travel", product_type.lower()],
            "fragranceProfile": {
                "family": profile["family"],
                "topNotes": profile["top"],
                "heartNotes": profile["heart"],
                "baseNotes": profile["base"]
            },
            "cleanStandards": ["Paraben-Free", "Phthalate-Free", "TSA Approved / Travel Friendly"]
        }

        minis_list.append(base_product)

    minis_dir = repo_root / "assets" / "stores" / "bath_and_body_works" / "body_care" / "minis"
    minis_dir.mkdir(parents=True, exist_ok=True)

    out_file = minis_dir / "travel_minis.json"

    with open(out_file, "w", encoding="utf-8") as f:
        json.dump(minis_list, f, indent=2)

    print(f"🎉 Compiled {len(minis_list)} travel minis to: {out_file}")

if __name__ == "__main__":
    repo_root = Path(__file__).resolve().parent.parent
    downloads_dir = Path.home() / "Downloads"

    input_matches = list(downloads_dir.glob("travel-size-toiletries---minis---bath---body-works-*.json"))
    if not input_matches:
        input_matches = list(repo_root.glob("**/travel-size-toiletries---minis---bath---body-works-*.json"))

    if not input_matches:
        print("❌ Could not locate input travel minis JSON file.")
        sys.exit(1)

    process_minis(input_matches[0], repo_root)
