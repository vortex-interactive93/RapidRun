# File: tool/enrich_bbw_moisturizers.py

import json
import os
import re
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
        "(KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36"
    ),
}

SCENT_DICTIONARY = {
    "a thousand wishes": {
        "family": "Fruity Floral & Amber",
        "top": ["Pink Prosecco", "Starfruit", "Golden Quince"],
        "heart": ["Crystal Peonies", "Purple Freesia"],
        "base": ["Amaretto Crème", "Warm Amber", "Sugared Musk"],
        "description": "Warm, sparkling, sweet fragrance. Infused with shea butter, coconut oil and vitamin E for 24 hours of nourishing moisture."
    },
    "japanese cherry blossom": {
        "family": "Warm Floral",
        "top": ["Asian Pear", "Fuji Apple", "Ume Plum"],
        "heart": ["Japanese Cherry Blossom", "Butterfly Lily", "Kyoto Rose", "Mimosa Petals"],
        "base": ["Vanilla Rice", "Imperial Amber", "Silk Musk", "Cinnamon Incense"],
        "description": "An iconic, graceful blend of Japanese cherry blossom, Asian pear, fresh mimosa petals, white jasmine and blushing sandalwood."
    },
    "champagne toast": {
        "family": "Fruity Citrus",
        "top": ["Vintage Champagne", "Sparkling Berries"],
        "heart": ["Juicy Tangerine", "Nectarine Blossom"],
        "base": ["Sugared Musk", "Soft Amber"],
        "description": "A fruity, sweet, sparkling celebration. Scented with vintage champagne, sparkling berries and juicy tangerine."
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
    "trace of blue": {
        "family": "Cool Fresh Aquatic",
        "top": ["Blue Bergamot", "Crisp Air"],
        "heart": ["Sea Salt Water Lily", "Lotus Flower"],
        "base": ["Sheer Driftwood", "Clean Musk"],
        "description": "A serene, fresh aquatic breeze. Formulated with blue bergamot, sea salt water lily and sheer driftwood."
    },
    "very violet": {
        "family": "Powdery Sweet Floral",
        "top": ["Sugared Violet", "Fresh Violet Leaf"],
        "heart": ["Sheer Iris", "Candied Petals"],
        "base": ["Soft Vanilla", "White Amber"],
        "description": "A charming, sweet violet dream. Scented with sugared violet, sheer iris and soft vanilla."
    },
    "forever cherry blossom": {
        "family": "Romantic Floral",
        "top": ["Cherry Blossom", "White Peach"],
        "heart": ["Blushing Peony", "Jasmine Petals"],
        "base": ["Soft Musk", "Creamy Sandalwood"],
        "description": "A timeless romantic floral garden. Scented with cherry blossom, blushing peony and creamy sandalwood."
    },
    "vampire blood": {
        "family": "Dark Fruity Plum",
        "top": ["Red Berries", "Blood Orange"],
        "heart": ["Night-Blooming Jasmine", "Midnight Plum"],
        "base": ["Rich Plum Wood", "Dark Amber"],
        "description": "An eerie, sweet, fruity indulgence. Scented with red berries, night-blooming jasmine and plum."
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
    "mahogany teakwood": {
        "family": "Rich Bold Wood",
        "top": ["Rich Mahogany", "Lavender Herb"],
        "heart": ["Black Teakwood", "Geranium Leaf"],
        "base": ["Dark Oak", "Frosted Cedar"],
        "description": "A rich, bold, woodsy classic. Scented with rich mahogany, black teakwood and dark oak."
    },
    "almond croissant": {
        "family": "Warm Bakery Gourmand",
        "top": ["Warm Croissant", "Butter Crust"],
        "heart": ["Almond Extract", "Toasted Pecan"],
        "base": ["Powdered Sugar", "Vanilla Bean"],
        "description": "A warm, flaky, golden morning pastry. Scented with warm croissant, almond extract and powdered sugar."
    },
    "pink matcha latte": {
        "family": "Sweet Tea Gourmand",
        "top": ["Pink Dragonfruit", "Matcha Tea Leaf"],
        "heart": ["Creamy Oat Milk", "Green Tea Blossom"],
        "base": ["Sugared Vanilla", "Soft Musk"],
        "description": "A trendy, creamy, sweet tea treat. Scented with pink dragonfruit, matcha tea and creamy oat milk."
    },
    "sweet cinnamon pumpkin": {
        "family": "Warm Fall Gourmand",
        "top": ["Heirloom Pumpkin", "Fresh Ginger"],
        "heart": ["Autumn Cinnamon", "Ground Nutmeg"],
        "base": ["Molasses", "Warm Vanilla", "Spiced Clove"],
        "description": "An iconic, warm fall celebration. Scented with heirloom pumpkin, autumn cinnamon, nutmeg and molasses."
    },
    "caramel vanilla": {
        "family": "Rich Sweet Gourmand",
        "top": ["Salted Caramel", "Butterscotch"],
        "heart": ["Vanilla Bean", "Sweet Cream"],
        "base": ["Warm Amber", "Toasted Sugar"],
        "description": "A rich, gooey, golden sweet indulgence. Scented with salted caramel, vanilla bean and warm amber."
    },
    "bourbon": {
        "family": "Warm Woody Amber",
        "top": ["White Pepper", "Crisp Bergamot"],
        "heart": ["Dark Amber", "Barrel Oak"],
        "base": ["Kentucky Bourbon", "Rich Cedar"],
        "description": "A smooth, warm, barrel-aged blend. Scented with white pepper, dark amber and Kentucky bourbon."
    },
    "santal ridge": {
        "family": "Rich Creamy Sandalwood",
        "top": ["Crisp Bergamot", "Cardamom Spice"],
        "heart": ["Creamy Santal", "Iris Blossom"],
        "base": ["Cedarwood", "Warm Amber"],
        "description": "A rich, creamy, mountain ridge sanctuary. Scented with creamy santal, crisp bergamot and cedarwood."
    },
    "cherry crush": {
        "family": "Fruity Cherry Gourmand",
        "top": ["Bing Cherry", "Black Cherry"],
        "heart": ["Sweet Plum", "Cherry Blossom"],
        "base": ["Sugared Musk", "Vanilla Bean"],
        "description": "A sweet, playful, bold cherry pop. Scented with bing cherry, sweet plum and sugared musk."
    },
    "sandalwood": {
        "family": "Aromatherapy Earthy Wood",
        "top": ["Australian Sandalwood", "Cardamom"],
        "heart": ["Cedar Leaf", "Earthy Vetiver"],
        "base": ["Warm Cedar", "Soft Amber"],
        "description": "A grounding, calming, natural woodsy retreat. Formulated with Australian sandalwood and warm cedar essential oils."
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
    },
    "orange ginger": {
        "family": "Aromatherapy Energy Citrus",
        "top": ["Sweet Orange Oil", "Mandarin Zest"],
        "heart": ["Ginger Root Oil", "Fresh Spice"],
        "base": ["Soft Woods", "Golden Amber"],
        "description": "An energizing, vibrant, mood-boosting citrus blend. Scented with natural orange oil and ginger oil."
    },
    "covered in roses": {
        "family": "Lush Red Floral",
        "top": ["Ruby Red Rose", "Sugared Berries"],
        "heart": ["Damask Rose Petals", "Pink Peony"],
        "base": ["Warm Amber", "Velvet Musk"],
        "description": "A lush, lavish, petal-drenched rose garden. Scented with ruby red rose, sugared berries and warm amber."
    },
    "berry bliss": {
        "family": "Juicy Berry Gourmand",
        "top": ["Wild Blackberry", "Sweet Raspberry"],
        "heart": ["Blackcurrant", "Rose Water"],
        "base": ["Vanilla Bean", "Sugared Musk"],
        "description": "A sweet, joyful, berry-filled celebration. Scented with wild blackberry, sweet raspberry and vanilla bean."
    },
    "sweetest song": {
        "family": "Delicate Sweet Floral",
        "top": ["Pink Peony", "Sweet Raspberry"],
        "heart": ["Apple Blossom", "Lily of the Valley"],
        "base": ["Cashmere Wood", "Soft Musk"],
        "description": "A sweet, melodious, enchanting floral bouquet. Scented with pink peony, sweet raspberry and cashmere wood."
    },
    "champagne apple & honey": {
        "family": "Fruity Autumn Apple",
        "top": ["Pink Lady Apple", "Sparkling Champagne"],
        "heart": ["Jasmine Honey", "Autumn Woods"],
        "base": ["Sugared Amber", "Soft Musk"],
        "description": "A crisp, sweet, autumn orchard gathering. Scented with pink lady apple, sparkling champagne and jasmine honey."
    },
    "white pumpkin & chai": {
        "family": "Warm Spice Gourmand",
        "top": ["White Pumpkin", "Cinnamon Cider"],
        "heart": ["Warm Chai Spices", "Sweet Vanilla"],
        "base": ["Spiced Clove", "Golden Amber"],
        "description": "A cozy, comforting, autumn spice indulgence. Scented with white pumpkin, cinnamon cider and warm chai spices."
    },
    "wild blackberry jam": {
        "family": "Sweet Berry Gourmand",
        "top": ["Wild Blackberry", "Ripe Plum"],
        "heart": ["Blackberry Nectar", "Toasted Sugar"],
        "base": ["Vanilla Bean", "Warm Amber"],
        "description": "A rich, sweet, freshly potted berry preserve. Scented with wild blackberry, ripe plum and toasted sugar."
    },
    "coco shea": {
        "family": "Deep Hydration Cocoa",
        "top": ["Creamy Cocoa Butter", "Coconut Water"],
        "heart": ["Rich Shea Milk", "Almond Blossom"],
        "base": ["Warm Vanilla", "Soft Sandalwood"],
        "description": "Densely nourishing, ultra-moisturizing care. Formulated with cocoa butter and shea butter for deep 24-hour hydration."
    },
    "water": {
        "family": "Hyaluronic Acid Hydration",
        "top": ["Clean Rainwater", "Water Lily"],
        "heart": ["Hyaluronic Molecule", "Sea Kelp"],
        "base": ["Sheer Driftwood", "Clean Musk"],
        "description": "Weightless, continuous, deep surge hydration. Formulated with Hyaluronic Acid for plump, glowing skin."
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

def resolve_moisturizer_volume(product_type: str, title: str) -> (str, str):
    combined = f"{product_type} {title}".lower()
    if "hand cream" in combined:
        return ("1 fl oz / 29 mL", "1 fl oz")
    if "travel" in combined or "mini" in combined:
        return ("2.5 oz / 70 g", "2.5 oz")
    if "butter" in combined:
        return ("6.7 oz / 190 g", "6.7 oz")
    if "cream" in combined or "hydration" in combined:
        return ("8 oz / 226 g", "8 oz")
    if "oil" in combined:
        return ("4 fl oz / 118 mL", "4 fl oz")
    return ("8 fl oz / 236 mL", "8 fl oz")

def resolve_moisturizer_price(product_type: str, title: str, raw_price: Optional[str]) -> (float, float):
    parsed = clean_price(raw_price)
    if parsed and parsed > 0:
        return (parsed, parsed)

    combined = f"{product_type} {title}".lower()
    if "hand cream" in combined:
        return (8.95, 8.95)
    if "travel" in combined or "mini" in combined:
        return (8.95, 8.95)
    if "butter" in combined:
        return (19.95, 19.95)
    if "cream" in combined or "hydration" in combined:
        return (17.95, 17.95)
    if "oil" in combined:
        return (18.95, 18.95)
    return (16.95, 16.95)

def get_scent_profile(scent_name: str, name: str) -> Dict[str, Any]:
    search_key = scent_name.lower().strip()
    if not search_key:
        search_key = name.lower().strip()

    for k, profile in SCENT_DICTIONARY.items():
        if k in search_key or search_key in k:
            return profile

    return {
        "family": "Hydrating Moisture",
        "top": ["Fresh Bergamot", "Dewy Botanicals"],
        "heart": ["Shea Blossom", "Coconut Milk"],
        "base": ["Warm Vanilla", "Silk Musk"],
        "description": f"Infused with shea butter, coconut oil and vitamin E for 24 hours of intense nourishing moisture. Notes of {name}."
    }

def process_moisturizers(input_path: Path, repo_root: Path):
    with open(input_path, "r", encoding="utf-8") as f:
        raw_items = json.load(f)

    print(f"📦 Loaded {len(raw_items)} source items from: {input_path.name}")

    moisturizers_all = []
    lotions_list = []
    creams_butters_list = []

    for i, item in enumerate(raw_items, start=1):
        url = item.get("product_url") or item.get("wick_link_url", "")
        sku_match = re.search(r"(\d{8,10})$", url) or re.search(r"-(\d{8,10})(?:\?|$)", url)
        sku = sku_match.group(1) if sku_match else f"m_{i:04d}"

        scent_name = (item.get("product_name") or "Fragrance").strip()
        product_type = (item.get("product_type") or "Body Lotion").strip()
        full_title = (item.get("product_full_title") or f"{scent_name} {product_type}").strip()

        sale_price, msrp_price = resolve_moisturizer_price(product_type, full_title, item.get("price"))
        rating = extract_rating(item.get("reviews"))

        img_url = (item.get("product_image") or "").replace("sw=1280", "sw=600")
        vol, vol_short = resolve_moisturizer_volume(product_type, full_title)
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
            "tags": ["bath_and_body_works", "body_care", "moisturizers", product_type.lower()],
            "fragranceProfile": {
                "family": profile["family"],
                "topNotes": profile["top"],
                "heartNotes": profile["heart"],
                "baseNotes": profile["base"]
            },
            "cleanStandards": ["Paraben-Free", "Phthalate-Free", "Dermatologist Tested"]
        }

        moisturizers_all.append(base_product)

        # Categorize into lotion vs cream/butter
        if "lotion" in product_type.lower():
            lotions_list.append(base_product)
        else:
            creams_butters_list.append(base_product)

    moisturizers_dir = repo_root / "assets" / "stores" / "bath_and_body_works" / "body_care" / "moisturizers"
    moisturizers_dir.mkdir(parents=True, exist_ok=True)

    out_main = moisturizers_dir / "moisturizers.json"
    out_lotion = moisturizers_dir / "bbw_body_lotion.json"
    out_cream = moisturizers_dir / "bbw_body_cream_butter.json"

    with open(out_main, "w", encoding="utf-8") as f:
        json.dump(moisturizers_all, f, indent=2)

    with open(out_lotion, "w", encoding="utf-8") as f:
        json.dump(lotions_list, f, indent=2)

    with open(out_cream, "w", encoding="utf-8") as f:
        json.dump(creams_butters_list, f, indent=2)

    print(f"🎉 Compiled {len(moisturizers_all)} moisturizers to:")
    print(f"   • {out_main}")
    print(f"   • {out_lotion} ({len(lotions_list)} items)")
    print(f"   • {out_cream} ({len(creams_butters_list)} items)")

if __name__ == "__main__":
    repo_root = Path(__file__).resolve().parent.parent
    downloads_dir = Path.home() / "Downloads"

    input_matches = list(downloads_dir.glob("body-moisturizers--lotion--cream--butter---bath---body-works-*.json"))
    if not input_matches:
        input_matches = list(repo_root.glob("**/body-moisturizers--lotion--cream--butter---bath---body-works-*.json"))

    if not input_matches:
        print("❌ Could not locate input moisturizers JSON file.")
        sys.exit(1)

    process_moisturizers(input_matches[0], repo_root)
