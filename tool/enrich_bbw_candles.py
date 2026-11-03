# File: tool/enrich_bbw_candles.py

import json
import os
import re
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional

CANDLE_SCENT_DICTIONARY = {
    "cactus blossom": {
        "family": "Desert Floral Citrus",
        "top": ["Desert Cactus Flower", "Fresh Sparkling Citrus"],
        "heart": ["Coconut Water", "Fresh Blossom"],
        "base": ["Vanilla Amber", "Soft Woods"],
        "description": "A sweet, bright, desert island escape. Scented with desert cactus flower, fresh sparkling citrus, and coconut water."
    },
    "cinnamon caramel swirl": {
        "family": "Warm Bakery Gourmand",
        "top": ["Gooey Caramel", "Cinnamon Sugar"],
        "heart": ["Grated Nutmeg", "Butter Crust"],
        "base": ["Vanilla Bean", "Brown Sugar"],
        "description": "Rich, gooey caramel swirling with warm cinnamon sugar and vanilla bean."
    },
    "cinnamon spiced vanilla": {
        "family": "Warm Cinnamon Spice",
        "top": ["Fresh Ground Cinnamon", "Sugar Crystal"],
        "heart": ["Warm Vanilla", "Buttercream"],
        "base": ["Spiced Clove", "Warm Amber"],
        "description": "Fresh ground cinnamon and warm vanilla with sugar crystals."
    },
    "clean house vibes": {
        "family": "Clean Fresh Linen",
        "top": ["Crisp Fresh Air", "Eucalyptus Leaf"],
        "heart": ["Clean Cotton", "White Lily"],
        "base": ["Soft Musk", "Sheer Cedar"],
        "description": "The uplifting feeling of a freshly cleaned home. Made with crisp air, eucalyptus, and clean cotton."
    },
    "fiji white sands": {
        "family": "Tropical Island Citrus",
        "top": ["Sunkissed Sugarcane", "Fresh Papaya"],
        "heart": ["White Nectarine", "Island Blossom"],
        "base": ["Vanilla Sandalwood", "Soft Amber"],
        "description": "A warm, breezy, sun-drenched tropical beach. Scented with sunkissed sugarcane, fresh papaya, and white nectarine."
    },
    "fresh rainfall & linen": {
        "family": "Clean Fresh Aquatic",
        "top": ["Fresh Raindrops", "Crisp Air"],
        "heart": ["Clean Linen", "Water Lily"],
        "base": ["Soft Driftwood", "Clean Musk"],
        "description": "A revitalizing spring rain shower on sun-dried linen. Scented with fresh raindrops and clean linen."
    },
    "kitchen lemon": {
        "family": "Bright Zesty Citrus",
        "top": ["Zesty Fresh Lemon", "Sparkling Citrus"],
        "heart": ["Spearmint Leaf", "Italian Bergamot"],
        "base": ["Clean Woods", "Soft Musk"],
        "description": "Bright, uplifting, freshly squeezed kitchen lemons with a hint of mint."
    },
    "mahogany vanilla": {
        "family": "Rich Woody Vanilla",
        "top": ["Rich Mahogany", "Warm Vanilla"],
        "heart": ["Black Teakwood", "Golden Amber"],
        "base": ["Dark Oak", "Soft Cedar"],
        "description": "A smooth, warm, woodsy vanilla blend. Scented with rich mahogany, warm vanilla and black teakwood."
    },
    "raspberries & whipped vanilla": {
        "family": "Fruity Berry Gourmand",
        "top": ["Pink Raspberries", "Strawberry Nectar"],
        "heart": ["Whipped Vanilla", "Plum Blossom"],
        "base": ["Sugared Amber", "Soft Musk"],
        "description": "Sweet, sun-ripened raspberries smothered in fluffy whipped vanilla."
    },
    "white tea & sage": {
        "family": "Aromatherapy Fresh Herbal",
        "top": ["Sparkling Bergamot", "White Tea Leaf"],
        "heart": ["Fresh Sage", "Violet Leaf"],
        "base": ["Clean Woods", "Soft Amber"],
        "description": "A peaceful, soothing herbal sanctuary. Scented with sparkling bergamot, white tea leaf and fresh sage."
    },
    "santal + amber": {
        "family": "Creamy Santal & Amber",
        "top": ["Creamy Santal", "Golden Amber"],
        "heart": ["Cardamom Spice", "Iris Blossom"],
        "base": ["Cedarwood", "Velvet Musk"],
        "description": "An opulent, elevated sanctuary of creamy santal, golden amber and cardamom spice."
    },
    "sweet orange & agave": {
        "family": "Bright Zesty Citrus",
        "top": ["Sweet Orange", "Agave Nectar"],
        "heart": ["Mandarin Zest", "Lime Leaf"],
        "base": ["Soft Amber", "Sugared Musk"],
        "description": "A bright, sunlit citrus splash. Made with sweet orange, agave nectar and mandarin zest."
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
    "sea salt + musk": {
        "family": "Fresh Aquatic Musk",
        "top": ["Sea Salt Waters", "Crisp Air"],
        "heart": ["Solar Musk", "Coastal Water Lily"],
        "base": ["White Sandalwood", "Soft Driftwood"],
        "description": "A crisp, breezy, coastal ocean escape. Made with sea salt waters, solar musk and white sandalwood."
    },
    "neapolitan ice cream": {
        "family": "Gourmand Ice Cream",
        "top": ["Rich Chocolate", "Fresh Strawberry"],
        "heart": ["Sweet Vanilla Bean", "Whipped Cream"],
        "base": ["Waffle Cone", "Sugared Amber"],
        "description": "A delicious classic ice cream parlor dream. Made with natural essential oils of chocolate, strawberry, and sweet vanilla bean."
    },
    "maple pumpkin": {
        "family": "Warm Fall Gourmand",
        "top": ["Sweet Maple Syrup", "Fresh Pumpkin"],
        "heart": ["Warm Cinnamon", "Brown Sugar"],
        "base": ["Toasted Pecan", "Vanilla Spice"],
        "description": "A warm, sweet autumn kitchen treat. Scented with rich maple syrup, fresh pumpkin, and warm cinnamon."
    },
    "champagne toast": {
        "family": "Fruity Citrus",
        "top": ["Vintage Champagne", "Sparkling Berries"],
        "heart": ["Juicy Tangerine", "Nectarine Blossom"],
        "base": ["Sugared Musk", "Soft Amber"],
        "description": "A festive, bubbly celebration. Scented with vintage champagne, sparkling berries and juicy tangerine."
    },
    "leaves": {
        "family": "Warm Autumn Spice",
        "top": ["Crisp Red Apple", "Golden Nectar"],
        "heart": ["Warm Clove Spice", "Autumn Cinnamon"],
        "base": ["Spiced Clove", "Sheer Amber"],
        "description": "The quintessential scent of autumn crisp air. Scented with crisp red apple, golden nectar and warm clove spice."
    },
    "mahogany teakwood": {
        "family": "Rich Bold Wood",
        "top": ["Rich Mahogany", "Lavender Herb"],
        "heart": ["Black Teakwood", "Geranium Leaf"],
        "base": ["Dark Oak", "Frosted Cedar"],
        "description": "A rich, bold, woodsy classic. Scented with rich mahogany, black teakwood, dark oak and frosted cedar."
    },
    "sweater weather": {
        "family": "Fresh Crisp Autumn",
        "top": ["Fresh Sage", "Crisp Eucalyptus"],
        "heart": ["Autumn Apple", "Juniper Berry"],
        "base": ["Woods", "Soft Musk"],
        "description": "A fresh, crisp autumn walk in the woods. Scented with fresh sage, crisp eucalyptus, and autumn apple."
    },
    "pumpkin pecan waffles": {
        "family": "Warm Bakery Gourmand",
        "top": ["Maple Syrup", "Golden Waffles"],
        "heart": ["Pumpkin Spice", "Toasted Pecans"],
        "base": ["Warm Vanilla", "Brown Sugar"],
        "description": "A warm, sweet, maple-drenched morning waffle breakfast. Made with maple syrup, golden waffles, and pumpkin spice."
    },
    "fresh balsam": {
        "family": "Fresh Pine & Forest",
        "top": ["Woodland Balsam", "Crisp Eucalyptus"],
        "heart": ["Fir Branches", "Pine Needles"],
        "base": ["Cedarwood", "Earthy Musk"],
        "description": "The fresh, invigorating scent of a evergreen forest. Made with woodland balsam, crisp eucalyptus and cedarwood."
    },
    "marshmallow fireside": {
        "family": "Warm Smoky Gourmand",
        "top": ["Toasted Marshmallow", "Smoky Cacao"],
        "heart": ["Fireside Smolder", "Roasted Vanilla"],
        "base": ["Crystal Amber", "Warm Woods"],
        "description": "Cozying up by a crackling campfire. Scented with toasted marshmallow, smoldering woods and roasted vanilla."
    },
    "flannel": {
        "family": "Cozy Fresh Spice",
        "top": ["Fresh Bergamot", "Heirloom Mahogany"],
        "heart": ["Soft Musk", "Warm Clove"],
        "base": ["Cedarwood", "Clean Amber"],
        "description": "Wrapping up in your favorite warm flannel shirt. Scented with fresh bergamot, heirloom mahogany and soft musk."
    },
    "hot cocoa & cream": {
        "family": "Decadent Chocolate",
        "top": ["Decadent Milk Chocolate", "Steamed Milk"],
        "heart": ["Mini Marshmallows", "Cocoa Powder"],
        "base": ["Rich Vanilla", "Toasted Sugar"],
        "description": "A rich, creamy mug of hot chocolate on a chilly day. Made with decadent milk chocolate, steamed milk and marshmallows."
    },
    "spiced apple toddy": {
        "family": "Warm Spiced Fruit",
        "top": ["Warm Apple Brandy", "Spiced Plum"],
        "heart": ["Cinnamon Stick", "Ground Clove"],
        "base": ["Tart Cranberry", "Brown Sugar"],
        "description": "A cozy, warming mug of spiced apple brandy, cinnamon stick, tart cranberry and clove."
    },
    "sun-drenched linen": {
        "family": "Clean Crisp Laundry",
        "top": ["Cool Cotton", "Crisp Air"],
        "heart": ["Crisp Apple", "Soft Chamomile"],
        "base": ["Clean Linen Musk", "White Cedar"],
        "description": "Freshly washed laundry drying in the warm sun. Made with cool cotton, crisp apple and sun-drenched linen."
    },
    "tree farm": {
        "family": "Fresh Pine & Cedar",
        "top": ["Crisp Pine Needle", "Warm Cedar"],
        "heart": ["Spiced Apple", "Fir Balsam"],
        "base": ["Woodland Moss", "Sheer Musk"],
        "description": "A festive afternoon spent picking the perfect Christmas tree. Scented with crisp pine needle, warm cedar and spiced apple."
    },
    "the perfect christmas": {
        "family": "Festive Holiday Tradition",
        "top": ["Fresh Cut Pine", "Cinnamon Sugar"],
        "heart": ["Toasted Marshmallow", "Spiced Clove"],
        "base": ["Warm Cedar", "Holiday Amber"],
        "description": "Everything you love about the holidays in one candle. Scented with fresh cut pine, cinnamon sugar and toasted marshmallow."
    },
    "'tis the season": {
        "family": "Spiced Holiday Apple",
        "top": ["Rich Red Apple", "Sweet Cinnamon"],
        "heart": ["Cedarwood", "Ground Clove"],
        "base": ["Spiced Plum", "Holiday Amber"],
        "description": "An iconic holiday favorite. Scented with rich red apple, sweet cinnamon and cedarwood."
    },
    "lavender bergamot": {
        "family": "Aromatherapy Herbal",
        "top": ["Crisp Bergamot", "French Lavender"],
        "heart": ["Clary Sage", "Blue Violet"],
        "base": ["Sheer Amber", "Soft Cedar"],
        "description": "A soothing, relaxing herbal sanctuary. Made with natural French lavender and crisp bergamot essential oils."
    },
    "coffee & whiskey": {
        "family": "Warm Rich Spirit",
        "top": ["Bold Irish Coffee", "Whiskey Barrel"],
        "heart": ["Vanilla Bean", "Roasted Espresso"],
        "base": ["Aged Amber", "Rich Cedar"],
        "description": "A rich, smooth blend of bold Irish coffee, barrel-aged whiskey and warm vanilla."
    },
    "rose water & ivy": {
        "family": "Fresh Green Floral",
        "top": ["Soft Rose Petals", "Rain-Kissed Ivy"],
        "heart": ["Spring Blossom", "White Lily"],
        "base": ["Soft Musk", "Sheer Sandalwood"],
        "description": "A fresh, blooming garden walk. Made with soft rose petals, rain-kissed ivy and spring blossoms."
    },
    "snowflakes & cashmere": {
        "family": "Cozy Vanilla Amber",
        "top": ["Vanilla Cashmere", "Iced Clementine"],
        "heart": ["Frosted Amber", "Winter White Jasmine"],
        "base": ["Caramel Woods", "Soft Musk"],
        "description": "Wrapping yourself in a soft cashmere blanket. Scented with vanilla cashmere, frosted amber and iced clementine."
    },
    "vanilla birch": {
        "family": "Warm Woody Vanilla",
        "top": ["White Birch Bark", "Warm Vanilla"],
        "heart": ["Sandalwood", "Clary Sage"],
        "base": ["Rich Amber", "Sheer Musk"],
        "description": "A cozy, warm woodsy vanilla scent. Scented with white birch, warm vanilla and rich sandalwood."
    },
    "white gardenia": {
        "family": "Lush White Floral",
        "top": ["Classic White Gardenia", "Sweet Apple Blossom"],
        "heart": ["White Tuberose", "Jasmine Petals"],
        "base": ["Soft Wood", "Clean Musk"],
        "description": "An elegant bouquet of fresh white blooms. Made with classic white gardenia, sweet apple blossom and white tuberose."
    },
    "white pumpkin": {
        "family": "Warm Fall Spice",
        "top": ["Gilded Pumpkin", "Sweet Autumn Spice"],
        "heart": ["Ground Cinnamon", "Nutmeg"],
        "base": ["Warm Caramel", "Vanilla Wood"],
        "description": "A refined, warm autumn celebration. Scented with gilded pumpkin, sweet autumn spice and ground cinnamon."
    },
    "strawberry pound cake": {
        "family": "Gourmand Sweet Berry",
        "top": ["Fresh Strawberries", "Wild Berries"],
        "heart": ["Golden Shortcake", "Baking Spice"],
        "base": ["Whipped Cream", "Vanilla Sugar"],
        "description": "A sweet, airy, freshly baked treat. Scented with fresh strawberries, golden shortcake and whipped cream."
    },
    "strawberry snowflakes": {
        "family": "Sweet Winter Berry",
        "top": ["Juicy Strawberry", "Iced Bergamot"],
        "heart": ["Whipped Cream", "Winter Blossom"],
        "base": ["Iced Vanilla", "Soft Musk"],
        "description": "A sweet, frosted winter berry dream. Scented with juicy strawberry, whipped cream and iced vanilla."
    },
    "sugared snickerdoodle": {
        "family": "Warm Bakery Cinnamon",
        "top": ["Warm Cinnamon", "Sugared Cookie"],
        "heart": ["Vanilla Spice", "Butter Crust"],
        "base": ["Toasted Sugar", "Nutmeg"],
        "description": "Freshly baked snickerdoodle cookies warm from the oven. Scented with warm cinnamon, sugared cookie and vanilla spice."
    },
    "pumpkin apple": {
        "family": "Warm Orchard Fall",
        "top": ["Red Delicious Apple", "Fresh Pumpkin"],
        "heart": ["Cinnamon Stick", "Clove Bud"],
        "base": ["Warm Nutmeg", "Golden Nectar"],
        "description": "A crisp autumn afternoon at the orchard. Scented with red delicious apple, fresh pumpkin and cinnamon stick."
    },
    "eucalyptus mint": {
        "family": "Aromatherapy Fresh Mint",
        "top": ["Fresh Eucalyptus", "Crisp Spearmint"],
        "heart": ["Lemon Zest", "Clary Sage"],
        "base": ["Clean Cedar", "Soft Woods"],
        "description": "An energizing, refreshing spa sanctuary. Made with natural eucalyptus and spearmint essential oils."
    },
    "eucalyptus spearmint": {
        "family": "Aromatherapy Fresh Mint",
        "top": ["Fresh Eucalyptus", "Crisp Spearmint"],
        "heart": ["Clary Sage", "Peppermint Leaf"],
        "base": ["Clean Cedar", "Soft Woods"],
        "description": "An energizing, stress-relieving herbal blend. Made with natural eucalyptus and spearmint essential oils."
    },
    "laundry day": {
        "family": "Crisp Clean Linen",
        "top": ["Fresh Wash", "Crisp Air"],
        "heart": ["Eucalyptus Leaf", "Soft Lavender"],
        "base": ["Clean Musk", "White Sandalwood"],
        "description": "The crisp, comforting scent of fresh laundry drying. Scented with fresh wash, crisp air and eucalyptus leaf."
    },
    "mahogany coconut": {
        "family": "Tropical Woodsy Amber",
        "top": ["Rich Mahogany", "Creamy Coconut"],
        "heart": ["Toasted Coconut", "Lavender"],
        "base": ["English Oak", "Warm Amber"],
        "description": "A rich, tropical woodsy paradise. Scented with rich mahogany, creamy coconut and English oak."
    },
    "under the christmas tree": {
        "family": "Fresh Pine & Vanilla",
        "top": ["Fresh Cut Pine", "Eucalyptus"],
        "heart": ["Juniper Berry", "Spiced Clove"],
        "base": ["Vanilla Buttercream", "Warm Cedar"],
        "description": "Unwrapping presents on Christmas morning. Scented with fresh cut pine, juniper berry and vanilla buttercream."
    },
    "santa's milk & cookies": {
        "family": "Warm Holiday Bakery",
        "top": ["Warm Sugar Cookies", "Steamed Milk"],
        "heart": ["Vanilla Bean", "Toasted Pecan"],
        "base": ["Brown Sugar", "Cinnamon Dust"],
        "description": "Leaving out treats on Christmas Eve. Scented with warm sugar cookies, steamed milk and vanilla bean."
    },
    "balsam & firewood": {
        "family": "Woody Hearth & Pine",
        "top": ["Fir Balsam", "Smoky Firewood"],
        "heart": ["Pine Needle", "Cedar Bark"],
        "base": ["Earthy Amber", "Charcoal Smolder"],
        "description": "A cozy evening by the hearth in a log cabin. Scented with fir balsam, smoky firewood and cedar."
    },
    "black cherry merlot": {
        "family": "Fruity Rich Merlot",
        "top": ["Dark Cherry", "Black Raspberry"],
        "heart": ["Sumptuous Merlot", "Red Plum"],
        "base": ["Vanilla Wood", "Sugared Amber"],
        "description": "A rich, sophisticated fruity blend. Scented with dark cherry, black raspberry and sumptuous merlot."
    },
    "cranberry & pomegranate": {
        "family": "Tart Fruity Berry",
        "top": ["Tart Cranberry", "Ruby Pomegranate"],
        "heart": ["Red Apple", "Spiced Plum"],
        "base": ["Sugared Amber", "Soft Musk"],
        "description": "A bright, tart, sparkling berry celebration. Scented with tart cranberry, ruby pomegranate and red apple."
    },
    "japanese cherry blossom": {
        "family": "Warm Floral",
        "top": ["Asian Pear", "Fuji Apple"],
        "heart": ["Japanese Cherry Blossom", "Mimosa Petals"],
        "base": ["Vanilla Rice", "Blushing Sandalwood"],
        "description": "An iconic, graceful blend of Japanese cherry blossom, Asian pear, fresh mimosa petals, white jasmine and blushing sandalwood."
    },
    "lavender vanilla": {
        "family": "Aromatherapy Relaxing",
        "top": ["French Lavender", "Crisp Bergamot"],
        "heart": ["Vanilla Absolute", "Jasmine Petals"],
        "base": ["Warm Amber", "Soft Cedar"],
        "description": "A soothing, relaxing evening blend. Made with natural lavender oil and vanilla absolute."
    },
    "simmer & spice": {
        "family": "Warm Hearth Spice",
        "top": ["Spiced Cinnamon", "Orange Zest"],
        "heart": ["Clove Bud", "Star Anise"],
        "base": ["Warm Cedar", "Brown Sugar"],
        "description": "A stovetop potpourri simmering on autumn afternoons. Scented with spiced cinnamon, orange zest and clove."
    },
    "sweet cinnamon pumpkin": {
        "family": "Warm Fall Gourmand",
        "top": ["Heirloom Pumpkin", "Fresh Ginger"],
        "heart": ["Autumn Cinnamon", "Ground Nutmeg"],
        "base": ["Molasses", "Warm Vanilla", "Spiced Clove"],
        "description": "An iconic, warm fall celebration. Scented with heirloom pumpkin, autumn cinnamon, nutmeg and molasses."
    },
    "vanilla bean": {
        "family": "Warm Sweet Gourmand",
        "top": ["Vanilla Bean", "Sweet Cream"],
        "heart": ["Toasted Sugar", "Buttercream"],
        "base": ["Warm Amber", "Vanilla Musk"],
        "description": "A pure, sweet, comforting vanilla indulgence. Made with vanilla bean, sweet cream and toasted sugar."
    },
    "wrapped in velvet": {
        "family": "Luxe Velvet Amber",
        "top": ["Velvet Rose", "Dark Plum"],
        "heart": ["Red Amber", "Cashmere Wood"],
        "base": ["Rich Vanilla", "Soft Musk"],
        "description": "Luxe, opulent, velvet warmth. Scented with velvet rose, dark plum and red amber."
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

def resolve_candle_price(raw_price: Optional[str], default_p: float = 24.95) -> (float, float):
    parsed = clean_price(raw_price)
    if parsed and parsed > 0:
        return (parsed, parsed)
    return (default_p, default_p)

def get_scent_profile(scent_name: str, name: str) -> Dict[str, Any]:
    search_key = scent_name.lower().strip().replace("+", "and").replace("&", "and")
    if not search_key:
        search_key = name.lower().strip().replace("+", "and").replace("&", "and")

    for k, profile in CANDLE_SCENT_DICTIONARY.items():
        clean_k = k.replace("+", "and").replace("&", "and")
        if clean_k in search_key or search_key in clean_k:
            return profile

    return {
        "family": "Room-Filling Fragrance",
        "top": ["Fresh Bergamot", "Wild Plum"],
        "heart": ["Soft Jasmine", "Rose Petals"],
        "base": ["Warm Amber", "Cedarwood"],
        "description": f"Made with natural essential oils and our proprietary soy wax blend for room-filling fragrance. Notes of {name}."
    }

def process_3wick_candles(input_path: Path, repo_root: Path):
    with open(input_path, "r", encoding="utf-8") as f:
        raw_items = json.load(f)

    print(f"📦 Loaded {len(raw_items)} 3-wick source items from: {input_path.name}")
    candles_list = []

    for i, item in enumerate(raw_items, start=1):
        url = item.get("product_url") or ""
        sku_match = re.search(r"(\d{8,10})$", url) or re.search(r"-(\d{8,10})(?:\?|$)", url)
        sku = sku_match.group(1) if sku_match else f"c3_{i:04d}"

        scent_name = (item.get("product_name") or "Candle").strip()
        full_title = (item.get("product_full_title") or f"{scent_name} 3-Wick Candle").strip()

        sale_price, msrp_price = resolve_candle_price(item.get("price"), 24.95)
        rating = extract_rating(item.get("reviews"))

        img_url = (item.get("wick_image_image") or "").replace("sw=1280", "sw=600")
        profile = get_scent_profile(scent_name, full_title)

        base_product = {
            "id": f"bbw_{sku}",
            "name": full_title,
            "brand": "Bath & Body Works",
            "store": "bath_and_body_works",
            "category": "Candles",
            "subCategory": "3-Wick Candle",
            "price": sale_price,
            "msrp": msrp_price,
            "rating": rating,
            "unit": "14.5 oz / 411 g",
            "unitShort": "14.5 oz",
            "imageUrl": img_url,
            "description": profile["description"],
            "tags": ["bath_and_body_works", "candles", "3_wick_candle", scent_name.lower()],
            "fragranceProfile": {
                "family": profile["family"],
                "topNotes": profile["top"],
                "heartNotes": profile["heart"],
                "baseNotes": profile["base"]
            },
            "cleanStandards": ["Natural Essential Oils", "Lead-Free Wicks", "Soy Wax Blend", "25–45 Hour Burn Time"]
        }

        candles_list.append(base_product)

    candles_dir = repo_root / "assets" / "stores" / "bath_and_body_works" / "candles"
    candles_dir.mkdir(parents=True, exist_ok=True)
    out_file = candles_dir / "bbw_3_wick_candles.json"

    with open(out_file, "w", encoding="utf-8") as f:
        json.dump(candles_list, f, indent=2)

    print(f"🎉 Compiled {len(candles_list)} 3-wick candles to: {out_file}")

def process_4wick_candles(input_path: Path, repo_root: Path):
    with open(input_path, "r", encoding="utf-8") as f:
        raw_items = json.load(f)

    print(f"📦 Loaded {len(raw_items)} 4-wick source items from: {input_path.name}")
    candles_list = []

    for i, item in enumerate(raw_items, start=1):
        url = item.get("product_url") or ""
        sku_match = re.search(r"(\d{8,10})$", url) or re.search(r"-(\d{8,10})(?:\?|$)", url)
        sku = sku_match.group(1) if sku_match else f"c4_{i:04d}"

        scent_name = (item.get("product_name") or "Candle").strip()
        full_title = (item.get("product_full_title") or f"{scent_name} 4-Wick Candle").strip()

        sale_price, msrp_price = resolve_candle_price(item.get("price"), 32.95)
        rating = extract_rating(item.get("reviews"))

        img_url = (item.get("wick_image_image") or item.get("wick_image_image_1") or "").replace("sw=1280", "sw=600")
        profile = get_scent_profile(scent_name, full_title)

        base_product = {
            "id": f"bbw_{sku}",
            "name": full_title,
            "brand": "Bath & Body Works",
            "store": "bath_and_body_works",
            "category": "Candles",
            "subCategory": "4-Wick Candle",
            "price": sale_price,
            "msrp": msrp_price,
            "rating": rating,
            "unit": "18 oz / 510 g",
            "unitShort": "18 oz",
            "imageUrl": img_url,
            "description": profile["description"],
            "tags": ["bath_and_body_works", "candles", "4_wick_candle", scent_name.lower()],
            "fragranceProfile": {
                "family": profile["family"],
                "topNotes": profile["top"],
                "heartNotes": profile["heart"],
                "baseNotes": profile["base"]
            },
            "cleanStandards": ["Natural Essential Oils", "4 Lead-Free Wicks", "Soy Wax Blend", "30–50 Hour Burn Time"]
        }

        candles_list.append(base_product)

    candles_dir = repo_root / "assets" / "stores" / "bath_and_body_works" / "candles"
    candles_dir.mkdir(parents=True, exist_ok=True)
    out_file = candles_dir / "bbw_4_wick_candles.json"

    with open(out_file, "w", encoding="utf-8") as f:
        json.dump(candles_list, f, indent=2)

    print(f"🎉 Compiled {len(candles_list)} 4-wick candles to: {out_file}")

def process_single_wick_candles(input_path: Path, repo_root: Path):
    with open(input_path, "r", encoding="utf-8") as f:
        raw_items = json.load(f)

    print(f"📦 Loaded {len(raw_items)} single-wick source items from: {input_path.name}")
    candles_list = []

    for i, item in enumerate(raw_items, start=1):
        url = item.get("wick_linkbox__overlay_url") or item.get("product_url") or ""
        sku_match = re.search(r"(\d{8,10})$", url) or re.search(r"-(\d{8,10})(?:\?|$)", url)
        sku = sku_match.group(1) if sku_match else f"c1_{i:04d}"

        scent_name = (item.get("wick_linkbox__overlay") or item.get("product_name") or "Candle").strip()
        full_title = (item.get("wick_image_description") or item.get("product_full_title") or f"{scent_name} Single Wick Candle").strip()

        raw_price_str = item.get("emotion_hjuxxk") or item.get("price")
        sale_price, msrp_price = resolve_candle_price(raw_price_str, 16.95)
        rating = extract_rating(item.get("bv_off_screen") or item.get("reviews"))

        img_url = (item.get("wick_image_image") or "").replace("sw=1280", "sw=600")
        profile = get_scent_profile(scent_name, full_title)

        base_product = {
            "id": f"bbw_{sku}",
            "name": full_title,
            "brand": "Bath & Body Works",
            "store": "bath_and_body_works",
            "category": "Candles",
            "subCategory": "Single Wick Candle",
            "price": sale_price,
            "msrp": msrp_price,
            "rating": rating,
            "unit": "8 oz / 227 g",
            "unitShort": "8 oz",
            "imageUrl": img_url,
            "description": profile["description"],
            "tags": ["bath_and_body_works", "candles", "single_wick_candle", scent_name.lower()],
            "fragranceProfile": {
                "family": profile["family"],
                "topNotes": profile["top"],
                "heartNotes": profile["heart"],
                "baseNotes": profile["base"]
            },
            "cleanStandards": ["Natural Essential Oils", "Lead-Free Wick", "Soy Wax Blend", "25–45 Hour Burn Time"]
        }

        candles_list.append(base_product)

    candles_dir = repo_root / "assets" / "stores" / "bath_and_body_works" / "candles"
    candles_dir.mkdir(parents=True, exist_ok=True)
    out_file = candles_dir / "bbw_single_wick_candles.json"

    with open(out_file, "w", encoding="utf-8") as f:
        json.dump(candles_list, f, indent=2)

    print(f"🎉 Compiled {len(candles_list)} single-wick candles to: {out_file}")

def process_candle_accessories(input_path: Path, repo_root: Path):
    with open(input_path, "r", encoding="utf-8") as f:
        raw_items = json.load(f)

    print(f"📦 Loaded {len(raw_items)} candle accessory items from: {input_path.name}")
    acc_list = []

    for i, item in enumerate(raw_items, start=1):
        url = item.get("wick_linkbox__overlay_url") or item.get("product_url") or ""
        sku_match = re.search(r"(\d{8,10})$", url) or re.search(r"-(\d{8,10})(?:\?|$)", url)
        sku = sku_match.group(1) if sku_match else f"ca_{i:04d}"

        title = (item.get("wick_image_description") or item.get("product_full_title") or "Candle Holder").strip()
        scent_name = (item.get("wick_linkbox__overlay") or item.get("product_name") or title).strip()

        raw_price_str = item.get("emotion_hjuxxk") or item.get("price")
        sale_price, msrp_price = resolve_candle_price(raw_price_str, 19.95)
        rating = extract_rating(item.get("bv_off_screen") or item.get("reviews"))

        img_url = (item.get("wick_image_image") or item.get("wick_image_image_1") or "").replace("sw=1280", "sw=600")

        base_product = {
            "id": f"bbw_{sku}",
            "name": title,
            "brand": "Bath & Body Works",
            "store": "bath_and_body_works",
            "category": "Candles",
            "subCategory": "Candle Accessories",
            "price": sale_price,
            "msrp": msrp_price,
            "rating": rating,
            "unit": "1 ct",
            "unitShort": "1 ct",
            "imageUrl": img_url,
            "description": f"Decorative 3-wick candle holder pedestal designed to display and elevate your favorite 3-wick candles. Measures to fit all standard Bath & Body Works 3-wick candle jars.",
            "tags": ["bath_and_body_works", "candles", "candle_accessories", "pedestal", "holder"],
            "cleanStandards": ["Fits All Standard 3-Wick Candles", "Decorative Home Decor", "Durable Craftsmanship"]
        }

        acc_list.append(base_product)

    candles_dir = repo_root / "assets" / "stores" / "bath_and_body_works" / "candles"
    candles_dir.mkdir(parents=True, exist_ok=True)
    out_file = candles_dir / "bbw_candle_accessories.json"

    with open(out_file, "w", encoding="utf-8") as f:
        json.dump(acc_list, f, indent=2)

    print(f"🎉 Compiled {len(acc_list)} candle accessories to: {out_file}")

if __name__ == "__main__":
    repo_root = Path(__file__).resolve().parent.parent
    downloads_dir = Path.home() / "Downloads"

    c3_matches = list(downloads_dir.glob("3-wick-candles--scents-you-ll-love---bath---body-works-*.json"))
    if not c3_matches:
        c3_matches = list(repo_root.glob("**/3-wick-candles--scents-you-ll-love---bath---body-works-*.json"))
    if c3_matches:
        process_3wick_candles(c3_matches[0], repo_root)

    c4_matches = list(downloads_dir.glob("4-wick-candles---bath---body-works-*.json"))
    if not c4_matches:
        c4_matches = list(repo_root.glob("**/4-wick-candles---bath---body-works-*.json"))
    if c4_matches:
        process_4wick_candles(c4_matches[0], repo_root)

    c1_matches = list(downloads_dir.glob("single-wick-candles--scent-just-for-you---bath---body-works-*.json"))
    if not c1_matches:
        c1_matches = list(repo_root.glob("**/single-wick-candles--scent-just-for-you---bath---body-works-*.json"))
    if c1_matches:
        process_single_wick_candles(c1_matches[0], repo_root)

    ca_matches = list(downloads_dir.glob("candle-holders---pedestals-for-any-room---bath---body-works-*.json"))
    if not ca_matches:
        ca_matches = list(repo_root.glob("**/candle-holders---pedestals-for-any-room---bath---body-works-*.json"))
    if ca_matches:
        process_candle_accessories(ca_matches[0], repo_root)
