import json
import re

summary_path = 'bbw_extracted_summary.json'
with open(summary_path, 'r', encoding='utf-8') as f:
    items = json.load(f)

print(f"Total items to convert: {len(items)}")

mists_and_sprays = []
perfumes_and_colognes = []

for idx, item in enumerate(items, 1):
    title = item['title'].strip()
    brand = item['fragrance_line'].strip() if item['fragrance_line'] else 'Bath & Body Works'
    
    # Clean price
    raw_price = item['price'].replace('$', '').strip()
    try:
        price = float(raw_price)
    except:
        price = 18.95

    img = item['image_url']
    prod_type = item['product_type'] if item['product_type'] else 'Fragrance'
    frag_notes = item['fragrance_notes'] if item['fragrance_notes'] != 'N/A' else ''
    overview = item['overview'] if item['overview'] != 'N/A' else ''
    benefits = item['benefits'] if item['benefits'] != 'N/A' else ''

    # Build description
    desc_parts = []
    if frag_notes:
        desc_parts.append(f"Fragrance Notes: {frag_notes}")
    if overview:
        desc_parts.append(f"What it smells like: {overview}")
    if benefits:
        desc_parts.append(f"What it does: {benefits}")
    
    if not desc_parts:
        desc_parts.append(f"Indulgent {title} from Bath & Body Works. Lightly scents your skin with a long-lasting, super-layerable fragrance.")

    full_desc = " • ".join(desc_parts)

    p_id = f"bbw_fragrance_{idx}"

    prod_obj = {
        "id": p_id,
        "name": title,
        "brand": f"Bath & Body Works • {brand}" if brand != "Bath & Body Works" else "Bath & Body Works",
        "price": price,
        "unit": f"${price:.2f}",
        "unitShort": "8 fl oz" if "mist" in title.lower() or "spray" in title.lower() else "3.4 fl oz",
        "storeId": "bath_and_body_works",
        "category": "Fragrance",
        "subCategory": prod_type,
        "imageUrl": img,
        "aisle": "Fragrance Counter",
        "description": full_desc,
        "tags": [prod_type, brand]
    }

    if any(k in title.lower() for k in ["cologne", "eau de parfum", "perfume", "rollerball"]):
        perfumes_and_colognes.append(prod_obj)
    else:
        mists_and_sprays.append(prod_obj)

# Save to destination JSON files
mists_file = r'C:\Users\Thomas\VSCodeWorkspaces\RapidRun\assets\stores\bath_and_body_works\body_care\fragrance\bbw_body_sprays_mists.json'
perfumes_file = r'C:\Users\Thomas\VSCodeWorkspaces\RapidRun\assets\stores\bath_and_body_works\body_care\fragrance\bbw_perfume_cologne.json'

with open(mists_file, 'w', encoding='utf-8') as f:
    json.dump(mists_and_sprays, f, indent=2)

with open(perfumes_file, 'w', encoding='utf-8') as f:
    json.dump(perfumes_and_colognes, f, indent=2)

print(f"Successfully populated {len(mists_and_sprays)} mists/sprays in bbw_body_sprays_mists.json")
print(f"Successfully populated {len(perfumes_and_colognes)} perfumes/colognes in bbw_perfume_cologne.json")
