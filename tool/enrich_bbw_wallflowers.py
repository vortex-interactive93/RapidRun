# File: tool/enrich_bbw_wallflowers.py

import json
import os
import re
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional

WALLFLOWER_SCENT_DICTIONARY = {
    "santal + amber": {
        "family": "Creamy Santal & Amber",
        "top": ["Creamy Santal", "Golden Amber"],
        "heart": ["Cardamom Spice", "Iris Blossom"],
        "base": ["Cedarwood", "Velvet Musk"],
        "description": "An opulent, elevated sanctuary of creamy santal, golden amber and cardamom spice."
    },
    "lavender + jasmine": {
        "family": "Relaxing Floral Herbal",
        "top": ["French Lavender", "Night Jasmine"],
        "heart": ["Spring Blossoms", "Clary Sage"],
        "base": ["White Cedar", "Soft Musk"],
        "description": "A serene, calming floral garden. Scented with French lavender, night jasmine and white cedar."
    },
    "vanilla + tonka": {
        "family": "Decadent Gourmand",
        "top": ["Vanilla Bean", "Creamy Tonka"],
        "heart": ["Orchid Petals", "Warm Buttercream"],
        "base": ["Golden Amber", "Sugared Musk"],
        "description": "A rich, velvety vanilla dream. Made with vanilla bean, creamy tonka bean and warm amber."
    },
    "sweet orange + agave": {
        "family": "Bright Zesty Citrus",
        "top": ["Sweet Orange", "Agave Nectar"],
        "heart": ["Mandarin Zest", "Lime Leaf"],
        "base": ["Soft Amber", "Sugared Musk"],
        "description": "A bright, sunlit citrus splash. Made with sweet orange, agave nectar and mandarin zest."
    },
    "sea salt + musk": {
        "family": "Fresh Aquatic Musk",
        "top": ["Sea Salt Waters", "Crisp Air"],
        "heart": ["Solar Musk", "Coastal Water Lily"],
        "base": ["White Sandalwood", "Soft Driftwood"],
        "description": "A crisp, breezy, coastal ocean escape. Made with sea salt waters, solar musk and white sandalwood."
    },
    "laundry day": {
        "family": "Crisp Clean Linen",
        "top": ["Fresh Wash", "Crisp Air"],
        "heart": ["Eucalyptus Leaf", "Soft Lavender"],
        "base": ["Clean Musk", "White Sandalwood"],
        "description": "Continuous, effortless room-filling scent of fresh laundry drying in crisp air. Formulated with natural essential oils for up to 30 days of fragrance."
    },
    "champagne apple & honey": {
        "family": "Fruity Autumn Apple",
        "top": ["Pink Lady Apple", "Sparkling Champagne"],
        "heart": ["Jasmine Honey", "Autumn Woods"],
        "base": ["Sugared Amber", "Soft Musk"],
        "description": "A crisp, sweet, autumn orchard celebration. Scented with pink lady apple, sparkling champagne and jasmine honey."
    },
    "champagne toast": {
        "family": "Fruity Citrus",
        "top": ["Vintage Champagne", "Sparkling Berries"],
        "heart": ["Juicy Tangerine", "Nectarine Blossom"],
        "base": ["Sugared Musk", "Soft Amber"],
        "description": "A festive, bubbly celebration. Continuous room-filling scent of vintage champagne, sparkling berries and juicy tangerine."
    },
    "sweater weather": {
        "family": "Fresh Crisp Autumn",
        "top": ["Fresh Sage", "Crisp Eucalyptus"],
        "heart": ["Autumn Apple", "Juniper Berry"],
        "base": ["Woods", "Soft Musk"],
        "description": "A fresh, crisp autumn walk in the woods. Scented with fresh sage, crisp eucalyptus, and autumn apple."
    },
    "clean house vibes": {
        "family": "Clean Fresh Linen",
        "top": ["Crisp Fresh Air", "Eucalyptus Leaf"],
        "heart": ["Clean Cotton", "White Lily"],
        "base": ["Soft Musk", "Sheer Cedar"],
        "description": "The uplifting feeling of a freshly cleaned home. Made with crisp air, eucalyptus, and clean cotton."
    },
    "ray of sunshine": {
        "family": "Bright Solar Citrus",
        "top": ["Sunlit Lemon", "Golden Amber"],
        "heart": ["Solar Blossom", "Coconut Water"],
        "base": ["Soft Driftwood", "Warm Musk"],
        "description": "A warm, radiant splash of sunshine. Scented with sunlit lemon, solar blossom and golden amber."
    },
    "fancy apple": {
        "family": "Crisp Orchard Apple",
        "top": ["Honeycrisp Apple", "Sparkling Cider"],
        "heart": ["Red Pear", "Autumn Blossom"],
        "base": ["Sheer Woods", "Sugared Musk"],
        "description": "A crisp, juicy, orchard-fresh apple delight. Scented with honeycrisp apple and sparkling cider."
    },
    "vampire blood": {
        "family": "Dark Fruity Berry",
        "top": ["Red Berries", "Blood Orange"],
        "heart": ["Night-Blooming Jasmine", "Midnight Plum"],
        "base": ["Rich Plum Wood", "Dark Amber"],
        "description": "An eerie, sweet, fruity indulgence. Scented with red berries, night-blooming jasmine and plum."
    },
    "a thousand wishes": {
        "family": "Fruity Floral & Amber",
        "top": ["Pink Prosecco", "Starfruit", "Golden Quince"],
        "heart": ["Crystal Peonies", "Purple Freesia"],
        "base": ["Amaretto Crème", "Warm Amber", "Sugared Musk"],
        "description": "Warm, sparkling, sweet fragrance. A festive blend of pink prosecco, sparkling quince, crystal peonies and gilded amber."
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
        "description": "An alluring, timeless, dark mystery. A captivating blend of dark berries, midnight jasmine and rich amber."
    },
    "strawberry pound cake": {
        "family": "Gourmand Sweet Berry",
        "top": ["Fresh Strawberries", "Wild Strawberries"],
        "heart": ["Golden Shortcake", "Baking Spice"],
        "base": ["Whipped Cream", "Vanilla Sugar"],
        "description": "A sweet, airy, freshly baked treat. Scented with fresh strawberries, golden shortcake and whipped cream."
    },
    "mahogany teakwood": {
        "family": "Rich Bold Wood",
        "top": ["Rich Mahogany", "Lavender Herb"],
        "heart": ["Black Teakwood", "Geranium Leaf"],
        "base": ["Dark Oak", "Frosted Cedar"],
        "description": "A rich, bold, woodsy classic. Scented with rich mahogany, black teakwood, dark oak and frosted cedar."
    },
    "leaves": {
        "family": "Warm Autumn Spice",
        "top": ["Crisp Red Apple", "Golden Nectar"],
        "heart": ["Warm Clove Spice", "Autumn Cinnamon"],
        "base": ["Spiced Clove", "Sheer Amber"],
        "description": "The quintessential scent of autumn crisp air. Scented with crisp red apple, golden nectar and warm clove spice."
    },
    "eucalyptus spearmint": {
        "family": "Aromatherapy Fresh Mint",
        "top": ["Fresh Eucalyptus", "Crisp Spearmint"],
        "heart": ["Clary Sage", "Peppermint Leaf"],
        "base": ["Clean Cedar", "Soft Woods"],
        "description": "An energizing, stress-relieving herbal sanctuary. Made with natural eucalyptus and spearmint essential oils."
    },
    "fresh balsam": {
        "family": "Fresh Pine & Forest",
        "top": ["Woodland Balsam", "Crisp Eucalyptus"],
        "heart": ["Fir Branches", "Pine Needles"],
        "base": ["Cedarwood", "Earthy Musk"],
        "description": "The fresh, invigorating scent of a evergreen forest. Made with woodland balsam, crisp eucalyptus and cedarwood."
    },
    "pumpkin pecan waffles": {
        "family": "Warm Bakery Gourmand",
        "top": ["Maple Syrup", "Golden Waffles"],
        "heart": ["Pumpkin Spice", "Toasted Pecans"],
        "base": ["Warm Vanilla", "Brown Sugar"],
        "description": "A warm, sweet, maple-drenched morning waffle breakfast. Made with maple syrup, golden waffles, and pumpkin spice."
    },
    "marshmallow fireside": {
        "family": "Warm Smoky Gourmand",
        "top": ["Toasted Marshmallow", "Smoky Cacao"],
        "heart": ["Fireside Smolder", "Roasted Vanilla"],
        "base": ["Crystal Amber", "Warm Woods"],
        "description": "Cozying up by a crackling campfire. Scented with toasted marshmallow, smoldering woods and roasted vanilla."
    },
    "warm vanilla sugar": {
        "family": "Warm Gourmand",
        "top": ["Sheer Florals", "Vanilla Orchid"],
        "heart": ["Vanilla Absolute", "Basmati Rice"],
        "base": ["Warm Vanilla", "White Sandalwood"],
        "description": "A cozy, enveloping, sweet comfort. Scented with sheer florals, vanilla absolute, basmati rice and warm vanilla."
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

def resolve_refill_price(raw_price: Optional[str], title: str) -> (float, float):
    parsed = clean_price(raw_price)
    if parsed and parsed > 0:
        return (parsed, parsed)
    combined = title.lower()
    if "2-pack" in combined or "2 pack" in combined or "refill 2" in combined:
        return (14.95, 14.95)
    return (7.95, 7.95)

def resolve_plug_price(raw_price: Optional[str], title: str) -> (float, float):
    parsed = clean_price(raw_price)
    if parsed and parsed > 0:
        return (parsed, parsed)
    combined = title.lower()
    if "projector" in combined:
        return (39.95, 39.95)
    if "scent control" in combined or "nightlight" in combined:
        return (16.95, 16.95)
    return (5.95, 5.95)

def resolve_reed_price(raw_price: Optional[str], title: str) -> (float, float):
    parsed = clean_price(raw_price)
    if parsed and parsed > 0:
        return (parsed, parsed)
    combined = title.lower()
    if "vessel" in combined:
        return (14.95, 14.95)
    return (18.95, 18.95)

def resolve_spray_price(raw_price: Optional[str], title: str) -> (float, float):
    parsed = clean_price(raw_price)
    if parsed and parsed > 0:
        return (parsed, parsed)
    combined = title.lower()
    if "mist" in combined:
        return (14.95, 14.95)
    return (8.95, 8.95)

def resolve_car_price(raw_price: Optional[str], title: str) -> (float, float):
    parsed = clean_price(raw_price)
    if parsed and parsed > 0:
        return (parsed, parsed)
    combined = title.lower()
    if "holder" in combined:
        return (8.95, 8.95)
    if "hanging" in combined or "diffuser" in combined:
        return (6.95, 6.95)
    return (4.95, 4.95)

def resolve_refill_volume(title: str) -> (str, str):
    combined = title.lower()
    if "2-pack" in combined or "2 pack" in combined or "duo" in combined:
        return ("1.6 fl oz / 48 mL", "1.6 fl oz")
    return ("0.8 fl oz / 24 mL", "0.8 fl oz")

def get_scent_profile(scent_name: str, name: str) -> Dict[str, Any]:
    search_key = scent_name.lower().strip().replace("+", "and").replace("&", "and")
    if not search_key:
        search_key = name.lower().strip().replace("+", "and").replace("&", "and")

    for k, profile in WALLFLOWER_SCENT_DICTIONARY.items():
        clean_k = k.replace("+", "and").replace("&", "and")
        if clean_k in search_key or search_key in clean_k:
            return profile

    return {
        "family": "Continuous Room Fragrance",
        "top": ["Fresh Bergamot", "Wild Plum"],
        "heart": ["Soft Jasmine", "Rose Petals"],
        "base": ["Warm Amber", "Cedarwood"],
        "description": f"Effortless, continuous room-filling fragrance for up to 30 days. Made with natural essential oils. Scented with notes of {name}."
    }

def process_wallflower_refills(input_path: Path, repo_root: Path):
    with open(input_path, "r", encoding="utf-8") as f:
        raw_items = json.load(f)

    print(f"📦 Loaded {len(raw_items)} refill source items from: {input_path.name}")
    refills_list = []

    for i, item in enumerate(raw_items, start=1):
        url = item.get("wick_linkbox__overlay_url") or item.get("product_url") or ""
        sku_match = re.search(r"(\d{8,10})$", url) or re.search(r"-(\d{8,10})(?:\?|$)", url)
        sku = sku_match.group(1) if sku_match else f"wf_{i:04d}"

        scent_name = (item.get("wick_linkbox__overlay") or item.get("product_name") or "Wallflowers Refill").strip()
        full_title = clean_title(item.get("wick_image_description") or item.get("product_full_title") or f"{scent_name} Wallflowers Fragrance Refill")

        sale_price, msrp_price = resolve_refill_price(item.get("emotion_hjuxxk") or item.get("price"), full_title)
        rating = extract_rating(item.get("bv_off_screen") or item.get("reviews"))

        img_url = (item.get("wick_image_image") or item.get("wick_image_image_1") or "").replace("sw=1280", "sw=600")
        vol, vol_short = resolve_refill_volume(full_title)
        profile = get_scent_profile(scent_name, full_title)

        base_product = {
            "id": f"bbw_{sku}",
            "name": full_title,
            "brand": "Bath & Body Works",
            "store": "bath_and_body_works",
            "category": "Wallflowers & Diffusers",
            "subCategory": "Wallflowers Fragrance Refills",
            "price": sale_price,
            "msrp": msrp_price,
            "rating": rating,
            "unit": vol,
            "unitShort": vol_short,
            "imageUrl": img_url,
            "description": profile["description"],
            "tags": ["bath_and_body_works", "wallflowers_diffusers", "wallflowers_refill", scent_name.lower()],
            "fragranceProfile": {
                "family": profile["family"],
                "topNotes": profile["top"],
                "heartNotes": profile["heart"],
                "baseNotes": profile["base"]
            },
            "cleanStandards": ["Natural Essential Oils", "Up to 30 Days Continuous Scent", "Safety Tested Plug-In Bulb"]
        }

        refills_list.append(base_product)

    wf_dir = repo_root / "assets" / "stores" / "bath_and_body_works" / "wallflowers_diffusers"
    wf_dir.mkdir(parents=True, exist_ok=True)
    out_file = wf_dir / "bbw_wallflower_refill.json"

    with open(out_file, "w", encoding="utf-8") as f:
        json.dump(refills_list, f, indent=2)

    print(f"🎉 Compiled {len(refills_list)} Wallflowers refills to: {out_file}")

def process_wallflower_plugs(input_path: Path, repo_root: Path):
    with open(input_path, "r", encoding="utf-8") as f:
        raw_items = json.load(f)

    print(f"📦 Loaded {len(raw_items)} plug source items from: {input_path.name}")
    plugs_list = []

    for i, item in enumerate(raw_items, start=1):
        url = item.get("wick_linkbox__overlay_url") or item.get("product_url") or ""
        sku_match = re.search(r"(\d{8,10})$", url) or re.search(r"-(\d{8,10})(?:\?|$)", url)
        sku = sku_match.group(1) if sku_match else f"wp_{i:04d}"

        raw_title = item.get("wick_image_description") or item.get("product_full_title") or "Wallflowers Fragrance Plug"
        full_title = clean_title(raw_title)

        sale_price, msrp_price = resolve_plug_price(item.get("emotion_hjuxxk") or item.get("price"), full_title)
        rating = extract_rating(item.get("bv_off_screen") or item.get("reviews"))

        img_url = (item.get("wick_image_image") or item.get("wick_image_image_1") or "").replace("sw=1280", "sw=600")

        base_product = {
            "id": f"bbw_{sku}",
            "name": full_title,
            "brand": "Bath & Body Works",
            "store": "bath_and_body_works",
            "category": "Wallflowers & Diffusers",
            "subCategory": "Wallflowers Plugs",
            "price": sale_price,
            "msrp": msrp_price,
            "rating": rating,
            "unit": "1 ct",
            "unitShort": "1 ct",
            "imageUrl": img_url,
            "description": "Pairs with any Bath & Body Works Wallflowers fragrance refill bulb. Provides continuous 24/7 fragrance in any room with safety-tested plug technology.",
            "tags": ["bath_and_body_works", "wallflowers_diffusers", "wallflowers_plugs", "plug"],
            "cleanStandards": ["Pairs With All Wallflowers Bulbs", "Safety Tested Plug-In", "UL Certified Electrical"]
        }

        plugs_list.append(base_product)

    wf_dir = repo_root / "assets" / "stores" / "bath_and_body_works" / "wallflowers_diffusers"
    wf_dir.mkdir(parents=True, exist_ok=True)
    out_file = wf_dir / "bbw_wallflower_plugs.json"

    with open(out_file, "w", encoding="utf-8") as f:
        json.dump(plugs_list, f, indent=2)

    print(f"🎉 Compiled {len(plugs_list)} Wallflowers plugs to: {out_file}")

def process_infused_reeds(input_path: Path, repo_root: Path):
    with open(input_path, "r", encoding="utf-8") as f:
        raw_items = json.load(f)

    print(f"📦 Loaded {len(raw_items)} reed source items from: {input_path.name}")
    reeds_list = []

    for i, item in enumerate(raw_items, start=1):
        url = item.get("wick_linkbox__overlay_url") or item.get("product_url") or ""
        sku_match = re.search(r"(\d{8,10})$", url) or re.search(r"-(\d{8,10})(?:\?|$)", url)
        sku = sku_match.group(1) if sku_match else f"ir_{i:04d}"

        scent_name = (item.get("wick_linkbox__overlay") or item.get("product_name") or "Infused Reeds").strip()
        raw_title = item.get("wick_image_description") or item.get("product_full_title") or f"{scent_name} Fragrance-Infused Liquidless Reeds"
        full_title = clean_title(raw_title)

        sale_price, msrp_price = resolve_reed_price(item.get("emotion_hjuxxk") or item.get("price"), full_title)
        rating = extract_rating(item.get("bv_off_screen") or item.get("reviews"))

        img_url = (item.get("wick_image_image") or item.get("wick_image_image_1") or "").replace("sw=1280", "sw=600")
        is_vessel = "vessel" in full_title.lower()
        vol = "1 ct" if is_vessel else "5 ct"
        profile = get_scent_profile(scent_name, full_title)

        base_product = {
            "id": f"bbw_{sku}",
            "name": full_title,
            "brand": "Bath & Body Works",
            "store": "bath_and_body_works",
            "category": "Wallflowers & Diffusers",
            "subCategory": "Infused Reeds",
            "price": sale_price,
            "msrp": msrp_price,
            "rating": rating,
            "unit": vol,
            "unitShort": vol,
            "imageUrl": img_url,
            "description": f"Decorative ceramic reed vessel designed to hold and display fragrance-infused liquidless reeds." if is_vessel else f"Fragrance-infused liquidless reed sticks that fill any room with continuous, flame-free fragrance for up to 30 days. Designed for use with any Bath & Body Works ceramic reed vessel.",
            "tags": ["bath_and_body_works", "wallflowers_diffusers", "infused_reeds", "reed_diffuser"],
            "cleanStandards": ["Flame-Free Liquidless Scent", "Up to 30 Days Continuous Fragrance", "Mess-Free Natural Reeds"]
        }

        if not is_vessel:
            base_product["fragranceProfile"] = {
                "family": profile["family"],
                "topNotes": profile["top"],
                "heartNotes": profile["heart"],
                "baseNotes": profile["base"]
            }

        reeds_list.append(base_product)

    wf_dir = repo_root / "assets" / "stores" / "bath_and_body_works" / "wallflowers_diffusers"
    wf_dir.mkdir(parents=True, exist_ok=True)
    out_file = wf_dir / "bbw_infused_reeds.json"

    with open(out_file, "w", encoding="utf-8") as f:
        json.dump(reeds_list, f, indent=2)

    print(f"🎉 Compiled {len(reeds_list)} Infused Reeds to: {out_file}")

def process_room_sprays(input_path: Path, repo_root: Path):
    with open(input_path, "r", encoding="utf-8") as f:
        raw_items = json.load(f)

    print(f"📦 Loaded {len(raw_items)} spray/mist source items from: {input_path.name}")
    sprays_list = []

    for i, item in enumerate(raw_items, start=1):
        url = item.get("wick_linkbox__overlay_url") or item.get("product_url") or ""
        sku_match = re.search(r"(\d{8,10})$", url) or re.search(r"-(\d{8,10})(?:\?|$)", url)
        sku = sku_match.group(1) if sku_match else f"rs_{i:04d}"

        scent_name = (item.get("wick_linkbox__overlay") or item.get("product_name") or "Room Spray").strip()
        raw_title = item.get("wick_image_description") or item.get("product_full_title") or f"{scent_name} Concentrated Room Spray"
        full_title = clean_title(raw_title)

        is_mist = "mist" in full_title.lower()
        sub_cat = "Room Mist" if is_mist else "Concentrated Room Spray"

        sale_price, msrp_price = resolve_spray_price(item.get("emotion_hjuxxk") or item.get("price"), full_title)
        rating = extract_rating(item.get("bv_off_screen") or item.get("reviews"))

        img_url = (item.get("wick_image_image") or item.get("wick_image__2__image") or "").replace("sw=1280", "sw=600")
        vol = "3.4 fl oz / 100 mL" if is_mist else "1.5 oz / 42.5 g"
        vol_short = "3.4 fl oz" if is_mist else "1.5 oz"
        profile = get_scent_profile(scent_name, full_title)

        desc = f"Gentle, fine room mist made with natural essential oils to refresh your space instantly." if is_mist else f"Fills any room with instant, concentrated fragrance with 2 spritzes. Delivers up to 250 sprays per can."

        base_product = {
            "id": f"bbw_{sku}",
            "name": full_title,
            "brand": "Bath & Body Works",
            "store": "bath_and_body_works",
            "category": "Wallflowers & Diffusers",
            "subCategory": sub_cat,
            "price": sale_price,
            "msrp": msrp_price,
            "rating": rating,
            "unit": vol,
            "unitShort": vol_short,
            "imageUrl": img_url,
            "description": desc,
            "tags": ["bath_and_body_works", "wallflowers_diffusers", "room_sprays_mists", sub_cat.lower().replace(" ", "_")],
            "fragranceProfile": {
                "family": profile["family"],
                "topNotes": profile["top"],
                "heartNotes": profile["heart"],
                "baseNotes": profile["base"]
            },
            "cleanStandards": ["Instant Concentrated Fragrance", "Up to 250 Sprays Per Can", "Odor Neutralizing Formula"]
        }

        sprays_list.append(base_product)

    wf_dir = repo_root / "assets" / "stores" / "bath_and_body_works" / "wallflowers_diffusers"
    wf_dir.mkdir(parents=True, exist_ok=True)
    out_file = wf_dir / "bbw_room_sprays_mists.json"

    with open(out_file, "w", encoding="utf-8") as f:
        json.dump(sprays_list, f, indent=2)

    print(f"🎉 Compiled {len(sprays_list)} Room Sprays & Mists to: {out_file}")

def process_car_fragrance(input_path: Path, repo_root: Path):
    with open(input_path, "r", encoding="utf-8") as f:
        raw_items = json.load(f)

    print(f"📦 Loaded {len(raw_items)} car fragrance source items from: {input_path.name}")
    car_list = []

    for i, item in enumerate(raw_items, start=1):
        url = item.get("wick_linkbox__overlay_url") or item.get("product_url") or ""
        sku_match = re.search(r"(\d{8,10})$", url) or re.search(r"-(\d{8,10})(?:\?|$)", url)
        sku = sku_match.group(1) if sku_match else f"car_{i:04d}"

        scent_name = (item.get("wick_linkbox__overlay") or item.get("product_name") or "Car Fragrance").strip()
        raw_title = item.get("wick_image_description") or item.get("product_full_title") or f"{scent_name} Car Fragrance Refill"
        full_title = clean_title(raw_title)

        title_lower = full_title.lower()
        if "holder" in title_lower:
            sub_cat = "Car Fragrance Holder"
            vol = "1 ct"
            desc = "Stylish visor or vent clip car fragrance holder. Pairs with any Bath & Body Works car fragrance refill disc."
        elif "hanging" in title_lower or "diffuser" in title_lower:
            sub_cat = "Hanging Fragrance Diffuser"
            vol = "0.2 fl oz / 6 mL"
            desc = "Elegant hanging car fragrance diffuser with natural wooden top that absorbs and radiates continuous fragrance throughout your vehicle."
        else:
            sub_cat = "Car Fragrance Refill"
            vol = "0.2 fl oz / 6 mL"
            desc = "Radiates continuous, refreshing scent throughout your vehicle for up to 4-6 weeks. Built for use with any Bath & Body Works car fragrance clip holder."

        sale_price, msrp_price = resolve_car_price(item.get("emotion_hjuxxk") or item.get("price"), full_title)
        rating = extract_rating(item.get("bv_off_screen") or item.get("reviews"))

        img_url = (item.get("wick_image_image") or item.get("wick_image__2__image") or "").replace("sw=1280", "sw=600")
        profile = get_scent_profile(scent_name, full_title)

        base_product = {
            "id": f"bbw_{sku}",
            "name": full_title,
            "brand": "Bath & Body Works",
            "store": "bath_and_body_works",
            "category": "Wallflowers & Diffusers",
            "subCategory": sub_cat,
            "price": sale_price,
            "msrp": msrp_price,
            "rating": rating,
            "unit": vol,
            "unitShort": vol,
            "imageUrl": img_url,
            "description": desc,
            "tags": ["bath_and_body_works", "wallflowers_diffusers", "car_fragrance", sub_cat.lower().replace(" ", "_")],
            "cleanStandards": ["Continuous Car Fragrance", "Visor & Vent Clip Compatible", "Up to 4-6 Weeks Scent"]
        }

        if sub_cat != "Car Fragrance Holder":
            base_product["fragranceProfile"] = {
                "family": profile["family"],
                "topNotes": profile["top"],
                "heartNotes": profile["heart"],
                "baseNotes": profile["base"]
            }

        car_list.append(base_product)

    wf_dir = repo_root / "assets" / "stores" / "bath_and_body_works" / "wallflowers_diffusers"
    wf_dir.mkdir(parents=True, exist_ok=True)
    out_file = wf_dir / "bbw_car_fragrance.json"

    with open(out_file, "w", encoding="utf-8") as f:
        json.dump(car_list, f, indent=2)

    print(f"🎉 Compiled {len(car_list)} Car Fragrance items to: {out_file}")

if __name__ == "__main__":
    repo_root = Path(__file__).resolve().parent.parent
    downloads_dir = Path.home() / "Downloads"

    refill_matches = list(downloads_dir.glob("wallflowers-fragrance-refills---bath---body-works-*.json"))
    if not refill_matches:
        refill_matches = list(downloads_dir.glob("wallflowers--plug-in-scents-that-last---bath---body-works-*.json"))
    if not refill_matches:
        refill_matches = list(repo_root.glob("**/wallflowers-fragrance-refills---bath---body-works-*.json"))
    if refill_matches:
        process_wallflower_refills(refill_matches[0], repo_root)

    plug_matches = list(downloads_dir.glob("wallflowers-plugs--plug-in-fragrance---bath---body-works-*.json"))
    if not plug_matches:
        plug_matches = list(repo_root.glob("**/wallflowers-plugs--plug-in-fragrance---bath---body-works-*.json"))
    if plug_matches:
        process_wallflower_plugs(plug_matches[0], repo_root)

    reed_matches = list(downloads_dir.glob("fragrance-infused-liquidless-reeds--reed-diffusers---bath---body-works-*.json"))
    if not reed_matches:
        reed_matches = list(repo_root.glob("**/fragrance-infused-liquidless-reeds--reed-diffusers---bath---body-works-*.json"))
    if reed_matches:
        process_infused_reeds(reed_matches[0], repo_root)

    spray_matches = list(downloads_dir.glob("room-sprays---mists--home-fragrance---air-freshener---bath---body-works-*.json"))
    if not spray_matches:
        spray_matches = list(repo_root.glob("**/room-sprays---mists--home-fragrance---air-freshener---bath---body-works-*.json"))
    if spray_matches:
        process_room_sprays(spray_matches[0], repo_root)

    car_matches = list(downloads_dir.glob("car-air-freshener--car-fragrance---diffusers---bath---body-works-*.json"))
    if not car_matches:
        car_matches = list(repo_root.glob("**/car-air-freshener--car-fragrance---diffusers---bath---body-works-*.json"))
    if car_matches:
        process_car_fragrance(car_matches[0], repo_root)
