import json
import urllib.request
import re
import time

json_path = r'C:\Users\Thomas\Downloads\body-fragrance--mists--perfume---cologne---bath---body-works-2026-10-11T19-07-03-270Z.json'

with open(json_path, 'r', encoding='utf-8') as f:
    items = json.load(f)

print(f"Total items in file: {len(items)}\n")

extracted_products = []

headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept-Language': 'en-US,en;q=0.9',
}

for idx, item in enumerate(items, 1):
    title = item.get('wick_image_description') or item.get('wick_linkbox__overlay') or 'BBW Item'
    price = item.get('emotion_bxysmo') or '$18.95'
    image_url = item.get('wick_image_image') or ''
    url = item.get('wick_linkbox__overlay_url') or ''
    fragrance_line = item.get('wick_linkbox__overlay') or ''
    product_type = item.get('description') or ''
    rating_info = item.get('bv_off_screen') or ''

    details = {
        'index': idx,
        'title': title,
        'fragrance_line': fragrance_line,
        'product_type': product_type,
        'price': price,
        'image_url': image_url,
        'url': url,
        'rating_info': rating_info,
        'fragrance_notes': 'N/A',
        'overview': 'N/A',
        'benefits': 'N/A',
        'ingredients': 'N/A',
        'how_to_use': 'N/A',
        'additional_images': [],
    }

    if url:
        try:
            req = urllib.request.Request(url, headers=headers)
            with urllib.request.urlopen(req, timeout=12) as response:
                html = response.read().decode('utf-8', errors='ignore')

                # Extract Fragrance Notes
                frag_match = re.search(r'Fragrance\s+notes?:?\s*</[^>]+>\s*<[^>]+>([^<]+)', html, re.I) or re.search(r'Fragrance\s+notes?:?\s*([^<\n]+)', html, re.I)
                if frag_match:
                    details['fragrance_notes'] = frag_match.group(1).strip()

                # Extract Overview / What it smells like
                smell_match = re.search(r'What\s+it\s+smells\s+like:?\s*</[^>]+>\s*<[^>]+>([^<]+)', html, re.I) or re.search(r'What\s+it\s+smells\s+like:?\s*([^<\n]+)', html, re.I)
                if smell_match:
                    details['overview'] = smell_match.group(1).strip()

                # Extract What it does
                does_match = re.search(r'What\s+it\s+does:?\s*</[^>]+>\s*<[^>]+>([^<]+)', html, re.I) or re.search(r'What\s+it\s+does:?\s*([^<\n]+)', html, re.I)
                if does_match:
                    details['benefits'] = does_match.group(1).strip()

                # Extract Additional Image URLs
                imgs = re.findall(r'https://www\.bathandbodyworks\.com/dw/image/v2/BBDL_PRD/[^\s"]+\.jpg', html)
                if imgs:
                    details['additional_images'] = list(set(imgs))[:4]

        except Exception as e:
            pass

    extracted_products.append(details)
    print(f"[{idx}/89] Processed: {title}")

# Save full details to JSON summary
with open('bbw_extracted_summary.json', 'w', encoding='utf-8') as out:
    json.dump(extracted_products, out, indent=2)

print("\n=== COMPLETE EXTRACTED DATA SUMMARY SAVED TO bbw_extracted_summary.json ===")
