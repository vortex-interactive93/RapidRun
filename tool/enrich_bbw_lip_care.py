# File: tool/enrich_bbw_lip_care.py

import json
import os
import re
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional

LIP_SCENT_DICTIONARY = {
    "my favorite night balm": {
        "family": "Nourishing Night Care",
        "top": ["Vanilla Mint", "Sweet Almond"],
        "description": "Deeply conditioning, ultra-moisturizing lip balm with shea butter and jojoba oil to restore dry lips overnight."
    },
    "vanilla 2x": {
        "family": "Sweet Vanilla Gourmand",
        "top": ["Double Vanilla Bean", "Sweet Cream"],
        "description": "High-shine, double-vanilla lip gloss infused with peppermint oil for an invigorating, shiny finish."
    },
    "whipped vanilla": {
        "family": "Warm Bakery Gourmand",
        "top": ["Whipped Vanilla", "Buttercream"],
        "description": "Rich, cushiony lip butter that melts into lips to deliver continuous moisture and a delicious vanilla scent."
    },
    "mentha": {
        "family": "Refreshing Peppermint",
        "top": ["Peppermint Oil", "Cool Menthol"],
        "description": "100% natural peppermint flavor lip gloss that cools, freshens breath, and gives a glossy shine."
    },
    "vampire blood": {
        "family": "Dark Fruity Berry",
        "top": ["Red Berries", "Night Plum"],
        "description": "A sheer, berry-tinted hydrating lip oil with a sweet fruity scent that leaves lips feeling soft and glossy."
    },
    "bare blush": {
        "family": "Peptide Lip Treatment",
        "top": ["Sheer Rose", "Peptide Complex"],
        "description": "Advanced peptide-infused lip treatment designed to plump, smooth, and restore youthful softness with a subtle nude blush."
    },
    "shimmer tint pink": {
        "family": "Shimmer Floral Pink",
        "top": ["Pink Peony", "Sweet Strawberry"],
        "description": "Sparkling pink lip gloss with light-reflecting shimmer that provides a lush, glossy sheen."
    },
    "strawberry pound cake": {
        "family": "Gourmand Sweet Berry",
        "top": ["Fresh Strawberries", "Whipped Cream"],
        "description": "A sweet, glossy lip balm scented with fresh strawberries and golden shortcake."
    },
    "bare mint": {
        "family": "Cooling Mint Shine",
        "top": ["Spearmint Leaf", "Sweet Sugar"],
        "description": "Cooling, high-shine lip gloss with natural mint extract for a fresh, crisp lip feel."
    },
    "black cherry": {
        "family": "Deep Fruity Cherry",
        "top": ["Black Cherry", "Dark Plum"],
        "description": "Nourishing peptide lip treatment with a rich black cherry tint to plump and deeply moisturize."
    },
    "magenta mint": {
        "family": "Vibrant Berry Mint",
        "top": ["Magenta Berries", "Crisp Peppermint"],
        "description": "Vibrant berry-tinted lip gloss infused with cooling peppermint for a bold, glossy look."
    },
    "champagne toast": {
        "family": "Sparkling Citrus Berry",
        "top": ["Vintage Champagne", "Sparkling Berries"],
        "description": "Fruity, sparkling lip oil with coconut oil and vitamin E for a lightweight, non-sticky shine."
    },
    "pink satin": {
        "family": "Satin Pink Peptide",
        "top": ["Satin Pink Petals", "Peptide Complex"],
        "description": "Luxe peptide lip treatment with a silky pink sheen that visibly smooths and plumps dry lips."
    },
    "wine not": {
        "family": "Deep Wine Berry",
        "top": ["Rich Blackberry", "Aged Plum"],
        "description": "Deeply nourishing wine-tinted lip oil that hydrates and leaves a gorgeous berry shine."
    },
    "pink mint": {
        "family": "Sweet Pink Peppermint",
        "top": ["Pink Sugar", "Fresh Mint"],
        "description": "Playful pink lip gloss with a refreshing minty burst and glossy sheen."
    },
    "barely there": {
        "family": "Nude Lip Nourishment",
        "top": ["Nude Coconut", "Sheer Honey"],
        "description": "Nourishing lip tint that enhances natural lip color with weightless moisture."
    },
    "rosy cheeks": {
        "family": "Lush Rose Petal",
        "top": ["Ruby Red Rose", "Sweet Raspberry"],
        "description": "Lush, rose-tinted lip oil that conditions and gives lips a healthy, glowing sheen."
    },
    "honey glaze": {
        "family": "Golden Honey Nectar",
        "top": ["Golden Honey", "Warm Vanilla"],
        "description": "Golden, honey-infused lip oil that coats lips in luxurious moisture and high shine."
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

def resolve_lip_price(product_type: str, title: str, raw_price: Optional[str]) -> (float, float):
    parsed = clean_price(raw_price)
    if parsed and parsed > 0:
        return (parsed, parsed)
    combined = f"{product_type} {title}".lower()
    if "peptide" in combined:
        return (14.95, 14.95)
    if "oil" in combined or "tint" in combined:
        return (12.95, 12.95)
    return (8.95, 8.95)

def resolve_lip_volume(product_type: str, title: str) -> (str, str):
    combined = f"{product_type} {title}".lower()
    if "oil" in combined:
        return ("0.34 fl oz / 10 mL", "0.34 fl oz")
    if "butter" in combined or "balm" in combined:
        return ("0.5 oz / 14 g", "0.5 oz")
    return ("0.47 fl oz / 14 mL", "0.47 fl oz")

def get_scent_profile(scent_name: str, name: str) -> Dict[str, Any]:
    search_key = scent_name.lower().strip()
    if not search_key:
        search_key = name.lower().strip()

    for k, profile in LIP_SCENT_DICTIONARY.items():
        if k in search_key or search_key in k:
            return profile

    return {
        "family": "Lip Care & Gourmand",
        "top": ["Sweet Vanilla", "Peppermint Oil"],
        "description": f"Nourishing lip care infused with shea butter and vitamin E. Scented with notes of {name}."
    }

def process_lip_care(input_path: Path, repo_root: Path):
    with open(input_path, "r", encoding="utf-8") as f:
        raw_items = json.load(f)

    print(f"📦 Loaded {len(raw_items)} source items from: {input_path.name}")

    lip_care_list = []

    for i, item in enumerate(raw_items, start=1):
        url = item.get("product_url") or ""
        sku_match = re.search(r"(\d{8,10})$", url) or re.search(r"-(\d{8,10})(?:\?|$)", url)
        sku = sku_match.group(1) if sku_match else f"lip_{i:04d}"

        scent_name = (item.get("product_name") or "Lip Care").strip()
        product_type = (item.get("product_type") or "Lip Gloss").strip()
        full_title = (item.get("product_full_title") or f"{scent_name} {product_type}").strip()

        sale_price, msrp_price = resolve_lip_price(product_type, full_title, item.get("price"))
        rating = extract_rating(item.get("reviews"))

        img_url = (item.get("wick_image_image") or item.get("image_1") or "").replace("sw=1280", "sw=600")
        vol, vol_short = resolve_lip_volume(product_type, full_title)
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
            "tags": ["bath_and_body_works", "body_care", "lip_care", product_type.lower()],
            "fragranceProfile": {
                "family": profile["family"],
                "topNotes": profile["top"],
                "heartNotes": [],
                "baseNotes": []
            },
            "cleanStandards": ["Paraben-Free", "Phthalate-Free", "Dermatologist Tested"]
        }

        lip_care_list.append(base_product)

    lip_care_dir = repo_root / "assets" / "stores" / "bath_and_body_works" / "body_care" / "skin_care"
    lip_care_dir.mkdir(parents=True, exist_ok=True)

    out_file = lip_care_dir / "bbw_lip_care.json"

    with open(out_file, "w", encoding="utf-8") as f:
        json.dump(lip_care_list, f, indent=2)

    print(f"🎉 Compiled {len(lip_care_list)} lip care products to: {out_file}")

if __name__ == "__main__":
    repo_root = Path(__file__).resolve().parent.parent
    downloads_dir = Path.home() / "Downloads"

    input_matches = list(downloads_dir.glob("lip-care--gloss--oils---balm---bath---body-works-*.json"))
    if not input_matches:
        input_matches = list(repo_root.glob("**/lip-care--gloss--oils---balm---bath---body-works-*.json"))

    if not input_matches:
        print("❌ Could not locate input lip care JSON file.")
        sys.exit(1)

    process_lip_care(input_matches[0], repo_root)
