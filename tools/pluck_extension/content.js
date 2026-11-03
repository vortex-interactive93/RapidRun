// File: tools/pluck_extension/content.js

function harvestLiveProducts() {
  const isBBW = window.location.hostname.includes('bathandbodyworks');
  const isAldi = window.location.hostname.includes('aldi');
  const items = [];

  if (isBBW) {
    // 1. Target the exact container identified in the video: .product-grid > div
    let cards = document.querySelectorAll(
      '.product-grid > div, [class*="product-grid"] > div, div[data-pid], [class*="product-cell"]'
    );

    // Fallback: collect any tile that contains an image and a link to a product page (/p/)
    if (cards.length === 0) {
      const allProductLinks = document.querySelectorAll('a[href*="/p/"]');
      const cardSet = new Set();
      allProductLinks.forEach(link => {
        const potentialCard = link.closest('div[class*="grid"], div[class*="tile"], article') || link.parentElement;
        if (potentialCard) cardSet.add(potentialCard);
      });
      cards = Array.from(cardSet);
    }

    console.log(`[Pluck] Found ${cards.length} product candidate cards on page.`);

    cards.forEach((card, index) => {
      try {
        // Image & Master CDN URL
        const img = card.querySelector('img');
        if (!img) return; // Must have an image to be a catalog item

        let imageUrl = img.getAttribute('data-src') ||
                       img.getAttribute('srcset')?.split(' ')[0] ||
                       img.src || '';
        if (imageUrl.startsWith('//')) imageUrl = 'https:' + imageUrl;

        // Name: Extract from image alt attribute OR product anchor tag
        const altText = img.getAttribute('alt')?.trim() || '';
        const linkNode = card.querySelector('a[href*="/p/"]');
        const linkText = linkNode ? linkNode.innerText.trim() : '';

        let name = altText || linkText;
        if (!name) {
          const heading = card.querySelector('h2, h3, div[class*="title"], div[class*="name"]');
          name = heading ? heading.innerText.trim() : '';
        }

        // Clean up promotional badge noise (e.g., "in 13,354 bags", "New")
        name = name.replace(/in\s+[0-9,]+\s+bags/gi, '')
                   .replace(/NEW!?/gi, '')
                   .replace(/\s+/g, ' ')
                   .trim();

        // Price: Search entire card text for dollar amounts via regex ($5.95, $18.95)
        const fullCardText = card.innerText || '';
        const priceMatches = fullCardText.match(/\$([0-9]+\.[0-9]{2})/g);

        let price = 0.0;
        if (priceMatches && priceMatches.length > 0) {
          // If multiple prices exist ($5.95 sale vs $18.95 reg), pick the lowest / sale price
          const numericPrices = priceMatches.map(p => parseFloat(p.replace('$', '')));
          price = Math.min(...numericPrices);
        }

        // Subcategory / Product Type (e.g. Fine Fragrance Mist, Body Wash, Candle)
        let subCategory = 'Fine Fragrance';
        const typeKeywords = ['Fine Fragrance Mist', 'Body Wash', 'Body Cream', 'Body Lotion', 'Eau de Parfum', 'Cologne', 'Wallflowers', 'Hand Soap', 'Single Wick Candle', '3-Wick Candle'];
        for (const kw of typeKeywords) {
          if (fullCardText.toLowerCase().includes(kw.toLowerCase())) {
            subCategory = kw;
            break;
          }
        }

        if (name.length > 2 && price > 0) {
          items.push({
            id: `bbw_${Date.now()}_${index}`,
            name: name,
            brand: 'Bath & Body Works',
            store: 'Bath & Body Works',
            category: 'Fragrance',
            subCategory: subCategory,
            price: price,
            unit: '8 fl oz',
            unitShort: '8 oz',
            imageUrl: imageUrl,
            inStock: true,
            rating: 4.8,
            ratingCount: 140
          });
        }
      } catch (err) {
        console.warn('[Pluck] Error extracting card:', err);
      }
    });

  } else if (isAldi) {
    const cards = document.querySelectorAll('.product-tile, [data-qa="product-card"], .base-card');
    cards.forEach((card, index) => {
      try {
        const img = card.querySelector('img');
        const nameNode = card.querySelector('[data-qa="product-name"], h3, .title');
        const name = nameNode ? nameNode.innerText.trim() : (img?.getAttribute('alt') || '');
        const match = (card.innerText || '').match(/\$([0-9]+\.[0-9]{2})/);
        const price = match ? parseFloat(match[1]) : 0.0;
        const imageUrl = img ? img.src : '';

        if (name && price > 0) {
          items.push({
            id: `aldi_${Date.now()}_${index}`,
            name: name,
            brand: 'ALDI',
            store: 'ALDI Grocery & Fresh',
            category: 'Pantry',
            subCategory: 'Grocery',
            price: price,
            unit: '1 ct',
            unitShort: '1 ct',
            imageUrl: imageUrl,
            inStock: true,
            rating: 4.9,
            ratingCount: 85
          });
        }
      } catch (err) {
        console.warn('[Pluck] Error extracting ALDI card:', err);
      }
    });
  }

  console.log(`[Pluck] Successfully harvested ${items.length} clean products!`);
  return items;
}

// Runtime message listener
chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
  if (request.action === 'PLUCK_PAGE') {
    const data = harvestLiveProducts();
    sendResponse({ success: true, count: data.length, data: data });
  }
});
