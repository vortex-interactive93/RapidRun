# File: tool/enrich_bbw_fragrance.py

import json
import os
import re
import sys
import time
from pathlib import Path
from typing import Any, Dict, List, Optional
from bs4 import BeautifulSoup
import httpx

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
        "(KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36"
    ),
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8",
    "Accept-Language": "en-US,en;q=0.9",
    "Referer": "https://www.bathandbodyworks.com/c/body-care/body-fragrance",
}

SCENT_DICTIONARY = {
    "a thousand wishes": {
        "family": "Fruity Floral & Amber",
        "top": ["Pink Prosecco", "Starfruit", "Golden Quince"],
        "heart": ["Crystal Peonies", "Purple Freesia"],
        "base": ["Amaretto Crème", "Warm Amber", "Sugared Musk"],
        "description": "Warm, sparkling, sweet fragrance. A festive blend of pink prosecco, sparkling quince, crystal peonies, gilded amber and amaretto crème."
    },
    "japanese cherry blossom": {
        "family": "Warm Floral",
        "top": ["Asian Pear", "Fuji Apple", "Ume Plum"],
        "heart": ["Japanese Cherry Blossom", "Butterfly Lily", "Kyoto Rose", "Mimosa Petals"],
        "base": ["Vanilla Rice", "Imperial Amber", "Silk Musk", "Cinnamon Incense", "Himalayan Cedarwood"],
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
        "base": ["Warm Vanilla", "White Sandalwood", "Brown Sugar", "Amber"],
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
        "description": "A dark, seductive, intoxicating fragrance. Formulated with high fragrance concentration of black plum, midnight orchid and sheer amber."
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
    "ghoul friend": {
        "family": "Fruity Spooky Sweet",
        "top": ["Dark Strawberries", "Chilled Citrus"],
        "heart": ["Ghostly Peony", "Night Jasmine"],
        "base": ["Sugared Wood", "Berry Musk"],
        "description": "A fun, bright, spooky sweet treat. Scented with dark strawberries, ghostly peony and chilled citrus."
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
    "coconut": {
        "family": "Tropical Sweet Coconut",
        "top": ["Toasted Coconut", "Coconut Water"],
        "heart": ["Coconut Cream", "Solar Floral"],
        "base": ["Vanilla Bean", "Sunkissed Woods"],
        "description": "A breezy, tropical island escape. Scented with toasted coconut, coconut water and vanilla bean."
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
    "rain": {
        "family": "Clean Fresh Aquatic",
        "top": ["Fresh Raindrops", "Crisp Dew"],
        "heart": ["Clear Water Lily", "Lotus Blossom"],
        "base": ["Soft Driftwood", "Sheer Amber"],
        "description": "A clean, revitalizing spring rain shower. Scented with fresh raindrops, clear water lily and soft driftwood."
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
    "vanilla noir": {
        "family": "Smoky Vanilla Wood",
        "top": ["Bourbon Vanilla", "Bergamot Zest"],
        "heart": ["Dark Cacao", "Night Orchid"],
        "base": ["Smoky Vanilla", "Black Amber"],
        "description": "A dark, smoky, decadent vanilla scent. Formulated with bourbon vanilla, dark cacao and smoky amber."
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
    "football season": {
        "family": "Fresh Woody Leather",
        "top": ["Crisp Fall Air", "Zesty Citrus"],
        "heart": ["Fresh Turf", "Green Leaf"],
        "base": ["Warm Leather", "Rich Cedarwood"],
        "description": "An energetic, game-day autumn spirit. Scented with crisp fall air, fresh turf and warm leather."
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
    "whiskey reserve": {
        "family": "Warm Rich Spirit",
        "top": ["Crisp Apple", "Bergamot Zest"],
        "heart": ["Single Malt Whiskey", "Spiced Clove"],
        "base": ["White Oak", "Golden Amber"],
        "description": "A rich, refined, single-malt spirit scent. Scented with crisp apple, single malt whiskey and white oak."
    },
    "black chamomile": {
        "family": "Aromatherapy Night Chamomile",
        "top": ["Black Chamomile Oil", "Crisp Apple"],
        "heart": ["Bergamot Oil", "Night Jasmine"],
        "base": ["Sheer Cedar", "Soft Vanilla"],
        "description": "A peaceful, sleep-inducing evening blend. Formulated with black chamomile and bergamot essential oils."
    },
    "stress relief": {
        "family": "Aromatherapy Eucalyptus Tea",
        "top": ["Eucalyptus Oil", "Crisp Spearmint"],
        "heart": ["Spearmint Oil", "Tea Leaf Extract"],
        "base": ["Soft Woods", "Clean Musk"],
        "description": "A clearing, uplifting, stress-relieving sanctuary. Scented with eucalyptus oil and spearmint oil."
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
    "plum please": {
        "family": "Sweet Fruity Gourmand",
        "top": ["Juicy Plum", "Black Cherry"],
        "heart": ["Sugar Plum", "Orchid Petals"],
        "base": ["Velvet Amber", "Vanilla Musk"],
        "description": "A juicy, decadent, sugar-dusted plum scent. Scented with juicy plum, sugar plum and velvet amber."
    },
    "watermelon whirl": {
        "family": "Juicy Fresh Watermelon",
        "top": ["Fresh Watermelon", "Sugared Lemon"],
        "heart": ["Cucumber Water", "Pink Poppy"],
        "base": ["Soft Musk", "Sugared Vanilla"],
        "description": "A crisp, refreshing, sun-drenched summer treat. Scented with fresh watermelon, sugared lemon and soft musk."
    },
    "crafted cognac": {
        "family": "Rich Aged Gourmand",
        "top": ["Aged Cognac", "Crisp Apple"],
        "heart": ["Warm Amber", "Cinnamon Bark"],
        "base": ["Dark Oak", "Smoky Vanilla"],
        "description": "A rich, sophisticated, barrel-crafted spirit scent. Scented with aged cognac, warm amber and dark oak."
    },
    "vetiver": {
        "family": "Aromatherapy Woody Earth",
        "top": ["Crisp Bergamot", "Haitian Vetiver"],
        "heart": ["Vetiver Root", "Cedar Leaf"],
        "base": ["Smoky Wood", "Earthy Musk"],
        "description": "An earthy, grounding, natural root blend. Formulated with Haitian vetiver and crisp bergamot."
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
    "tangerine twirl": {
        "family": "Sparkling Citrus Floral",
        "top": ["Juicy Tangerine", "Citrus Zest"],
        "heart": ["Orange Blossom", "Peach Nectar"],
        "base": ["Soft Amber", "Sugared Musk"],
        "description": "A bright, dancing, sunlit citrus scent. Scented with juicy tangerine, citrus zest and soft amber."
    },
    "sweetest song": {
        "family": "Delicate Sweet Floral",
        "top": ["Pink Peony", "Sweet Raspberry"],
        "heart": ["Apple Blossom", "Lily of the Valley"],
        "base": ["Cashmere Wood", "Soft Musk"],
        "description": "A sweet, melodious, enchanting floral bouquet. Scented with pink peony, sweet raspberry and cashmere wood."
    },
    "lasting legacy": {
        "family": "Bold Elegant Wood",
        "top": ["Fresh Bergamot", "Spiced Cardamom"],
        "heart": ["Bourbon Vetiver", "Cedarwood"],
        "base": ["Rich Amber", "Dark Leather"],
        "description": "A timeless, honorable, distinguished fragrance. Scented with fresh bergamot, bourbon vetiver and dark leather."
    },
    "into orbit": {
        "family": "Cosmic Fresh Ozone",
        "top": ["Cosmic Bergamot", "Ozone Water"],
        "heart": ["Silver Mint", "Blue Lavender"],
        "base": ["Deep Space Musk", "Clean Cedar"],
        "description": "A futuristic, exhilarating, crisp space exploration scent. Scented with cosmic bergamot, ozone water and clean cedar."
    },
    "after dark": {
        "family": "Seductive Night Wood",
        "top": ["Spiced Bergamot", "Black Plum"],
        "heart": ["Midnight Amber", "Smoky Lavender"],
        "base": ["Rich Leather", "Dark Tonka"],
        "description": "A sleek, captivating, midnight scent. Scented with spiced bergamot, midnight amber and dark tonka."
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

def resolve_fallback_volume(sub_category: str, name: str) -> str:
    combined = f"{sub_category} {name}".lower()
    if "rollerball" in combined:
        return "0.23 fl oz / 7 mL"
    if "mini" in combined or "travel" in combined:
        return "2.5 fl oz / 75 mL"
    if "cologne" in combined or "eau de parfum" in combined or "perfume" in combined:
        return "3.4 fl oz / 100 mL"
    if "deodorant" in combined or "antiperspirant" in combined or "stick" in combined:
        return "2.7 oz / 76 g"
    return "8 fl oz / 236 mL"

def get_scent_profile(scent_name: str, name: str) -> Dict[str, Any]:
    search_key = scent_name.lower().strip()
    if not search_key:
        search_key = name.lower().strip()

    for k, profile in SCENT_DICTIONARY.items():
        if k in search_key or search_key in k:
            return profile

    # Fallback default if unmapped
    return {
        "family": "Fragrance & Amber",
        "top": ["Fresh Bergamot", "Wild Plum"],
        "heart": ["Soft Jasmine", "Rose Petals"],
        "base": ["Warm Amber", "Silk Musk"],
        "description": f"An enchanting, radiant fragrance. Scented with high fragrance concentration notes of {name}."
    }

def process_catalog(input_path: Path, output_path: Path):
    with open(input_path, "r", encoding="utf-8") as f:
        raw_items = json.load(f)

    print(f"📦 Loaded {len(raw_items)} source items from: {input_path.name}")
    enriched_catalog = []

    for i, item in enumerate(raw_items, start=1):
        url = item.get("wick_linkbox__overlay_url") or item.get("url", "")
        sku_match = re.search(r"(\d{8,10})$", url) or re.search(r"-(\d{8,10})(?:\?|$)", url)
        sku = sku_match.group(1) if sku_match else f"{i:04d}"

        title = (
            item.get("wick_image_description")
            or item.get("wick_linkbox__overlay")
            or item.get("title")
            or "Fragrance"
        ).strip()
        scent_line = (item.get("wick_linkbox__overlay") or item.get("fragrance_line") or title).strip()
        sub_cat = item.get("description") or item.get("product_type", "Fine Fragrance Mist")
        sale_price = clean_price(item.get("emotion_1rkvoei")) or clean_price(item.get("price"))
        msrp_price = clean_price(item.get("emotion_bxysmo"))
        reg_price = clean_price(item.get("emotion_hjuxxk"))
        final_price = sale_price or reg_price or msrp_price or 18.95

        img_url = (item.get("wick_image_image") or item.get("image_url") or "").replace("sw=1280", "sw=600")
        is_shipping = not ("unavailable" in str(item.get("span", "")).lower())

        vol_fallback = resolve_fallback_volume(sub_cat, title)
        profile = get_scent_profile(scent_line, title)

        base_product = {
            "id": f"bbw_{sku}",
            "name": title,
            "brand": "Bath & Body Works",
            "store": "bath_and_body_works",
            "category": "Body Care",
            "subCategory": sub_cat,
            "price": final_price,
            "msrp": msrp_price,
            "rating": extract_rating(item.get("bv_off_screen") or item.get("rating_info")),
            "unit": vol_fallback,
            "unitShort": vol_fallback.split("/")[0].strip(),
            "imageUrl": img_url,
            "description": profile["description"],
            "tags": ["bath_and_body_works", "body_care", "fragrance", sub_cat.lower()],
            "fragranceProfile": {
                "family": profile["family"],
                "topNotes": profile["top"],
                "heartNotes": profile["heart"],
                "baseNotes": profile["base"]
            },
            "cleanStandards": ["Paraben-Free", "Phthalate-Free"]
        }

        enriched_catalog.append(base_product)

    output_path.parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(enriched_catalog, f, indent=2)

    print(f"\n🎉 Successfully compiled enriched catalog ({len(enriched_catalog)} items) to: {output_path}")

if __name__ == "__main__":
    repo_root = Path(__file__).resolve().parent.parent
    downloads_dir = Path.home() / "Downloads"

    # Locate raw scrape input file
    input_matches = list(downloads_dir.glob("body-fragrance--mists--perfume---cologne---bath---body-works-*.json"))
    if not input_matches:
        input_matches = list(repo_root.glob("**/body-fragrance--mists--perfume---cologne---bath---body-works-*.json"))
    if not input_matches:
        input_matches = list(repo_root.glob("**/bbw_extracted_summary.json"))

    if not input_matches:
        print("❌ Could not locate input JSON scrape.")
        sys.exit(1)

    target_input = input_matches[0]
    target_output = repo_root / "assets" / "stores" / "bath_and_body_works" / "body_care" / "fragrance" / "fragrance.json"

    process_catalog(target_input, target_output)
