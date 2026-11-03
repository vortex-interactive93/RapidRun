import urllib.request
import ssl
import re
import json

url = "https://www.bathandbodyworks.com/p/a-thousand-wishes-fine-fragrance-mist-028005120"
headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept-Language': 'en-US,en;q=0.9',
}

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

try:
    req = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(req, context=ctx, timeout=12) as response:
        html = response.read().decode('utf-8', errors='ignore')
        print(f"Successfully fetched HTML! Length: {len(html)}")

        # Search for Schema.org JSON-LD scripts
        scripts = re.findall(r'<script type="application/ld\+json">(.*?)</script>', html, re.S)
        print(f"Found {len(scripts)} JSON-LD script blocks.")
        for s in scripts:
            if 'Product' in s:
                print("\n=== SCHEMA.ORG PRODUCT JSON-LD ===")
                print(s[:1000])

        # Clean HTML tags to inspect raw text sections
        clean_text = re.sub(r'<[^>]+>', ' ', html)
        clean_text = re.sub(r'\s+', ' ', clean_text)

        print("\n=== RAW PAGE TEXT SNIPPETS ===")
        # Look for "Fragrance notes", "What it smells like", "What it does"
        matches = re.findall(r'(?i)(Fragrance\s+notes[^.]{1,200}|What\s+it\s+smells\s+like[^.]{1,200}|What\s+it\s+does[^.]{1,200}|Pink\s+Prosecco[^.]{1,200})', clean_text)
        for m in matches[:10]:
            print(f"• {m.strip()}")

except Exception as e:
    print(f"Error fetching URL: {e}")
