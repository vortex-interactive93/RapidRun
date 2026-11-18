// File: tools/pluck_extension/content.js

(function () {
  // =========================================================================
  // 1. BATH & BODY WORKS PDP HYDRATION ENGINE (LOCKED & UNTOUCHED)
  // =========================================================================
  function splitNotesString(rawNotes) {
    return rawNotes
      .replace(/^(?:fragrance\s+)?notes\s*:\s*/i, '')
      .replace(/\.+$/, '')
      .split(/,\s*|\s*•\s*/)
      .map((n) => n.replace(/^note:\s*/i, '').replace(/\.+$/, '').trim())
      .filter((n) => n.length > 1 && n.length < 60);
  }

  function findFragranceButton() {
    const buttons = Array.from(document.querySelectorAll('button, [role="button"]'));
    return (
      buttons.find((b) => b.textContent.trim().toLowerCase() === 'fragrance') ||
      document.querySelector('[id*="trigger:fragrance"]')
    );
  }

  function findFragranceRegion() {
    const direct = document.querySelector(
      '[role="region"][aria-label*="fragrance" i], [id*="content:fragrance"]'
    );
    if (direct) return direct;

    const fragBtn = findFragranceButton();
    if (fragBtn) {
      const controlsId = fragBtn.getAttribute('aria-controls');
      if (controlsId) {
        const controlled = document.getElementById(controlsId);
        if (controlled) return controlled;
      }
      if (fragBtn.parentElement) return fragBtn.parentElement;
    }
    return null;
  }

  function extractFromWhatItSmellsLike() {
    const headings = Array.from(document.querySelectorAll('h1, h2, h3, h4, [role="heading"]'));
    const smellHeading = headings.find(
      (h) => h.textContent.trim().toLowerCase() === 'what it smells like'
    );
    if (!smellHeading) return { overview: '', notes: [] };

    const section =
      smellHeading.parentElement?.parentElement ||
      smellHeading.closest('section, div[class*="layout"]') ||
      smellHeading.parentElement;
    if (!section) return { overview: '', notes: [] };

    const leafTexts = Array.from(section.querySelectorAll('p, span, div'))
      .filter((el) => el.children.length === 0)
      .map((el) => el.textContent.replace(/\s+/g, ' ').trim())
      .filter(
        (t) =>
          t.length > 1 &&
          t.toLowerCase() !== 'what it smells like' &&
          !/^shop collection/i.test(t)
      );

    const uniqueLines = [...new Set(leafTexts)];
    if (uniqueLines.length === 0) return { overview: '', notes: [] };

    const longParagraphs = uniqueLines.filter((l) => l.length > 35 || l.endsWith('.'));
    const overview = longParagraphs.length > 0 ? longParagraphs[longParagraphs.length - 1] : '';
    const notes = uniqueLines
      .filter((l) => !longParagraphs.includes(l) && l.length >= 2 && l.length <= 42)
      .slice(0, 6);

    return { overview, notes };
  }

  function readLivePdpPromo() {
    const dealEl = document.querySelector('[data-component="product-deals"]');
    if (!dealEl) return { hasDealBlock: false, promoBadge: '' };

    const raw = dealEl.textContent.replace(/\bdetails\b/gi, '').replace(/\s+/g, ' ').trim();
    if (!raw || /^limited time only$/i.test(raw)) {
      return { hasDealBlock: true, promoBadge: '' };
    }
    return { hasDealBlock: true, promoBadge: raw };
  }

  function readRenderedFragranceDom() {
    let overview = '';
    let notes = [];
    const tiers = { top: [], heart: [], base: [] };

    const container = findFragranceRegion();
    if (container) {
      const paragraphs = Array.from(container.querySelectorAll('p'))
        .map((p) => p.textContent.replace(/\s+/g, ' ').trim())
        .filter((t) => t.length > 0);

      for (const text of paragraphs) {
        if (/^(?:fragrance\s+)?notes\s*:/i.test(text)) {
          notes = splitNotesString(text);
        } else if (/^top(?:\s+notes)?\s*:/i.test(text)) {
          tiers.top = splitNotesString(text.replace(/^top(?:\s+notes)?\s*:\s*/i, ''));
        } else if (/^heart(?:\s+notes)?\s*:/i.test(text)) {
          tiers.heart = splitNotesString(text.replace(/^heart(?:\s+notes)?\s*:\s*/i, ''));
        } else if (/^base(?:\s+notes)?\s*:/i.test(text)) {
          tiers.base = splitNotesString(text.replace(/^base(?:\s+notes)?\s*:\s*/i, ''));
        } else if (
          !overview &&
          text.length > 10 &&
          !/^(what it smells like|why you'll love it|fragrance)/i.test(text)
        ) {
          overview = text;
        }
      }
    }

    if (notes.length === 0 && (tiers.top.length > 0 || tiers.heart.length > 0 || tiers.base.length > 0)) {
      notes = [...tiers.top, ...tiers.heart, ...tiers.base];
    }

    if (notes.length === 0 || !overview) {
      const fallback = extractFromWhatItSmellsLike();
      if (!overview && fallback.overview) overview = fallback.overview;
      if (notes.length === 0 && fallback.notes.length > 0) notes = fallback.notes;
    }

    const promoInfo = readLivePdpPromo();
    return { overview, notes, tiers, promoInfo };
  }

  async function waitForHydratedFragrance() {
    for (let attempt = 0; attempt < 20; attempt++) {
      const fragBtn = findFragranceButton();
      if (fragBtn && fragBtn.getAttribute('aria-expanded') === 'false') {
        fragBtn.click();
      }
      const data = readRenderedFragranceDom();
      if (data.notes.length > 0 && data.overview.length > 0) return data;
      if ((data.notes.length > 0 || data.overview.length > 0) && attempt >= 8) return data;
      await new Promise((r) => setTimeout(r, 250));
    }
    return readRenderedFragranceDom();
  }

  // =========================================================================
  // 2. ALDI PDP HYDRATION ENGINE ([id$="-Details"], [id$="-Ingredients"], Size)
  // =========================================================================
  function readRenderedAldiPdp() {
    const detailsEl = document.querySelector('[id$="-Details"]');
    let description = '';
    if (detailsEl) {
      const paras = Array.from(detailsEl.querySelectorAll('p'))
        .map((p) => p.textContent.replace(/\s+/g, ' ').trim())
        .filter((t) => t.length > 0);
      description = paras.join(' ');
    }

    const ingEl = document.querySelector('[id$="-Ingredients"]');
    let ingredients = '';
    if (ingEl) {
      const paras = Array.from(ingEl.querySelectorAll('p'))
        .map((p) => p.textContent.replace(/\s+/g, ' ').trim())
        .filter(
          (t) =>
            t.length > 0 &&
            !/please refer to the physical product label/i.test(t) &&
            !/product weight may vary/i.test(t)
        );
      ingredients = paras.join(' ');
    }

    let unit = '';
    const h1 = document.querySelector('h1');
    const headerScope = h1 ? h1.parentElement?.parentElement || document.body : document.body;
    const headerText = headerScope.textContent.replace(/\s+/g, ' ');
    const unitMatch = headerText.match(
      /\b(About\s+\d+(?:\.\d+)?\s*(?:lb|lbs|oz)\s*\/\s*package|\d+(?:\.\d+)?\s*(?:fl\s*oz|oz|lb|lbs|gal|qt|pt|ml|l|g|kg|ct|pk|pack)|per\s+lb)\b/i
    );
    if (unitMatch) {
      unit = unitMatch[1].trim();
    }

    return { description, ingredients, unit };
  }

  async function waitForHydratedAldiPdp() {
    for (let attempt = 0; attempt < 18; attempt++) {
      const data = readRenderedAldiPdp();
      if (data.description.length > 0 || data.ingredients.length > 0 || data.unit.length > 0) {
        if (data.description.length > 0) return data;
      }
      await new Promise((r) => setTimeout(r, 250));
    }
    return readRenderedAldiPdp();
  }

  // =========================================================================
  // 3. STORE MODE & CATEGORY TITLE ENGINE
  // =========================================================================
  function detectStoreKey() {
    const host = window.location.hostname.toLowerCase();
    if (host.includes('aldi.us')) return 'aldi';
    return 'bbw';
  }

  function getActiveStoreMode(overrideMode) {
    if (overrideMode && overrideMode !== 'auto') {
      return overrideMode;
    }
    return detectStoreKey();
  }

  function getPageCategoryName() {
    const headingEl = document.querySelector(
      'h1[data-dan-display="product-list--heading"], h1.wick-heading, [data-testid="category-title"], main h1, h1'
    );
    return headingEl ? headingEl.innerText.trim() : '';
  }

  function slugifyToFilename(rawTitle, storeMode) {
    const mode = getActiveStoreMode(storeMode);
    const prefix = mode === 'aldi' ? 'aldi_' : '';
    if (!rawTitle) return `${prefix}catalog.json`;

    const clean = rawTitle
      .toLowerCase()
      .replace(/&/g, 'and')
      .replace(/['"]/g, '')
      .replace(/[^a-z0-9]+/g, '_')
      .replace(/^_+|_+$/g, '');

    if (mode === 'aldi') return `aldi_${clean}.json`;

    if (clean.includes('candle')) return 'candles.json';
    if (clean.includes('wallflower') || clean.includes('diffuser')) return 'wallflowers_diffusers.json';
    if (clean.includes('fragrance') && !clean.includes('home')) return 'all_fragrance.json';
    if (clean.includes('soap') || clean.includes('sanitizer')) return 'hand_soaps_sanitizers.json';
    if (clean.includes('men')) return 'mens_shop.json';
    if (clean.includes('home') || clean.includes('laundry')) return 'home_care.json';
    if (clean.includes('body')) return 'body_care.json';
    return `${clean}.json`;
  }

  // =========================================================================
  // 4. ALDI (INSTACART STOREFRONT PRO) CARD HARVESTER & IMAGE REPAIR
  // =========================================================================
  const ALDI_KNOWN_BRANDS = [
    'Appleton Farms',
    'Simply Nature',
    'Never Any!',
    'Fremont Fish Market',
    'Earth Grown',
    "Cattlemen's Ranch",
    'Specially Selected',
    'Breakfast Best',
    'Pueblo Lindo',
    'Holmes Smokehouse',
    'Plainville Farms',
    'Kirkwood',
    'Parkview',
    'Simms',
    'Tyson',
    'Perdue',
    'Smithfield',
    "Nathan's",
    'Eckrich',
    'Friendly Farms',
    'Happy Farms',
    'Millville',
    'Clancy’s',
    "Clancy's",
    'Bake Shop',
    "L'oven Fresh",
    'Season’s Choice',
    "Season's Choice",
    'Burman’s',
    "Burman's",
    'Stonemill',
    'Priano',
    'Casa Mamita',
    'Chef’s Cupboard',
    "Chef's Cupboard",
    'elevation',
    'PurAqua',
    'Barissimo',
    'Benton’s',
    "Benton's",
    'Choceur',
    'Moser Roth',
    'Southern Grove',
  ];

  function extractAldiBrand(productName) {
    const lower = productName.toLowerCase();
    for (const brand of ALDI_KNOWN_BRANDS) {
      if (lower.startsWith(brand.toLowerCase())) {
        return brand;
      }
    }
    return 'ALDI';
  }

  function cleanAldiImageUrl(imgEl) {
    if (!imgEl) return '';
    let raw = imgEl.currentSrc || imgEl.getAttribute('src') || imgEl.getAttribute('data-src') || '';
    if (!raw || raw.startsWith('data:')) {
      const srcset = imgEl.getAttribute('srcset') || '';
      if (srcset) {
        const candidates = srcset
          .split(/,\s+(?=https?:)/i)
          .map((s) => s.trim().split(/\s+/)[0])
          .filter(Boolean);
        raw = candidates[candidates.length - 1] || '';
      }
    }
    const cloudfrontMatch = raw.match(/(d2lnr5mha7bycj\.cloudfront\.net\/[^\s"'?]+)/i);
    if (cloudfrontMatch) {
      return `https://${cloudfrontMatch[1]}`;
    }
    if (raw.startsWith('//')) return 'https:' + raw;
    return raw;
  }

  function buildDeterministicAldiId(imgUrl, name, unit) {
    const uuidMatch = imgUrl ? imgUrl.match(/large_([a-z0-9-]{8,40})\./i) : null;
    if (uuidMatch && uuidMatch[1]) {
      return uuidMatch[1];
    }
    return `${name}_${unit}`
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, '_')
      .replace(/^_+|_+$/g, '');
  }

  function harvestAldiCards(productMap) {
    const categoryName = getPageCategoryName() || 'Groceries';
    let candidateCards = Array.from(document.querySelectorAll('[data-item-card-button="true"]'));

    if (candidateCards.length === 0) {
      candidateCards = Array.from(document.querySelectorAll('li [role="button"]')).filter((btn) =>
        btn.querySelector('h2, h3, [role="heading"]')
      );
    }

    candidateCards.forEach((btnCard) => {
      try {
        const card = btnCard.closest('li, [role="group"]') || btnCard;

        const headingEl = card.querySelector('h2, h3, [role="heading"]');
        const name = headingEl ? headingEl.textContent.replace(/\s+/g, ' ').trim() : '';
        if (!name || name.length < 2) return;

        const imgEl = card.querySelector('img');
        const imageUrl = cleanAldiImageUrl(imgEl);

        const linkEl = card.querySelector('a[href*="/products/"]');
        let productUrl = linkEl ? linkEl.getAttribute('href') || '' : '';
        if (productUrl.startsWith('/')) {
          productUrl = window.location.origin + productUrl;
        }
        if (!productUrl) {
          productUrl = window.location.href.split('?')[0];
        }

        const fullText = btnCard.textContent.replace(/\s+/g, ' ');
        const currentMatch = fullText.match(/Current price:\s*\$([0-9]+(?:\.[0-9]{2})?)/i);
        const originalMatch = fullText.match(/Original price:\s*\$([0-9]+(?:\.[0-9]{2})?)/i);

        let salePrice = 0.0;
        let regularPrice = 0.0;

        if (currentMatch) {
          salePrice = parseFloat(currentMatch[1]);
          regularPrice = originalMatch ? parseFloat(originalMatch[1]) : salePrice;
        } else {
          const textWithoutPerLb = fullText.replace(/\$[0-9]+(?:\.[0-9]{2})?\s*\/\s*(?:lb|oz|ct|ea)/gi, '');
          const pricesFound = [...textWithoutPerLb.matchAll(/\$([0-9]+(?:\.[0-9]{2})?)/g)].map((m) =>
            parseFloat(m[1])
          );
          if (pricesFound.length === 1) {
            salePrice = pricesFound[0];
            regularPrice = pricesFound[0];
          } else if (pricesFound.length >= 2) {
            salePrice = Math.min(...pricesFound);
            regularPrice = Math.max(...pricesFound);
          }
        }

        const unitMatch = fullText.match(
          /\b(About\s+\d+(?:\.\d+)?\s*(?:lb|lbs|oz)\s*\/\s*package|\d+(?:\.\d+)?\s*(?:fl\s*oz|oz|lb|lbs|gal|qt|pt|ml|l|g|kg|ct|pk|pack)|per\s+lb)\b/i
        );
        const unit = unitMatch ? unitMatch[1].trim() : 'Each';

        const leafTexts = Array.from(btnCard.querySelectorAll('span, div, p'))
          .filter((el) => el.children.length === 0)
          .map((el) => el.textContent.replace(/\s+/g, ' ').trim())
          .filter(
            (t) =>
              t.length > 2 &&
              t !== name &&
              t !== unit &&
              !t.startsWith('$') &&
              !/current price|original price|per package|many in stock|low stock|out of stock|add/i.test(t)
          );
        const aisleLocation = leafTexts.length > 0 ? leafTexts[leafTexts.length - 1] : categoryName;

        const inStock = !/out of stock|sold out/i.test(fullText);
        let promoBadge = '';
        if (salePrice < regularPrice) promoBadge = 'Price Drop';
        else if (/aldi finds/i.test(fullText)) promoBadge = 'ALDI Finds';
        else if (/weekly special/i.test(fullText)) promoBadge = 'Weekly Special';

        const rawId = buildDeterministicAldiId(imageUrl, name, unit);
        const brand = extractAldiBrand(name);

        productMap.set(rawId, {
          id: `aldi_${rawId}`,
          sku: rawId,
          name: name,
          brand: brand,
          store: 'ALDI',
          category: categoryName,
          department: categoryName,
          productType: categoryName,
          subCategory: aisleLocation,
          aisle: aisleLocation,
          price: salePrice,
          regularPrice: regularPrice,
          salePrice: salePrice,
          promoBadge: promoBadge,
          hasSpecial: promoBadge.length > 0 || salePrice < regularPrice,
          imageUrl: imageUrl,
          productUrl: productUrl.split('?')[0],
          unit: unit,
          unitShort: unit,
          description: '',
          ingredients: '',
          inStock: inStock,
          isOnlineExclusive: false,
          rating: 4.7,
          ratingCount: 85,
        });
      } catch (err) {
        console.warn('ALDI card parse skipped:', err);
      }
    });
  }

  // =========================================================================
  // 5. BATH & BODY WORKS CARD HARVESTER
  // =========================================================================
  function harvestBbwCards(productMap) {
    const cardSelectors = [
      '[data-component="product-card"]',
      '.product-tile',
      '.grid-tile',
      'article[data-pid]',
    ];
    let candidateCards = [];

    for (const sel of cardSelectors) {
      const found = document.querySelectorAll(sel);
      if (found.length > 0) {
        candidateCards = Array.from(found);
        break;
      }
    }

    if (candidateCards.length === 0) {
      candidateCards = Array.from(document.querySelectorAll('[data-pid]')).filter(
        (el) => !el.matches('button, a, input, select') && el.querySelector('a[href*="/p/"]')
      );
    }

    candidateCards.forEach((card) => {
      try {
        const linkEl = card.querySelector('a[href*="/p/"]');
        const imgEl = card.querySelector('img[src*="/hires/"], img[data-src*="/hires/"], img[src*="/dw/image/"], img');
        if (!linkEl || !imgEl) return;

        let productUrl = linkEl.href;
        if (productUrl.startsWith('/')) productUrl = window.location.origin + productUrl;

        let pid = card.getAttribute('data-pid') || '';
        if (!pid && productUrl) {
          const match = productUrl.match(/-([0-9]{8,10})(?:\.html|\?|$)/);
          if (match) pid = match[1];
        }
        if (!pid) return;

        let name = '';
        const alt = (imgEl.getAttribute('alt') || imgEl.getAttribute('title') || '').trim();
        if (alt.length > 3 && !alt.toLowerCase().includes('swatch') && !alt.toLowerCase().includes('icon')) {
          name = alt;
        }
        if (!name) {
          const titleEl = card.querySelector('[data-component="product-title"], [class*="title"], [class*="name"], h2, h3');
          if (titleEl) name = titleEl.innerText.trim();
        }
        if (!name) return;

        let imageUrl = imgEl.getAttribute('data-src') || imgEl.getAttribute('src') || '';
        if (imageUrl.startsWith('//')) imageUrl = 'https:' + imageUrl;

        let salePrice = 0.0;
        let regularPrice = 0.0;
        const priceContainer = card.querySelector('[data-component="product-price"]') || card;
        const pricesFound = [...priceContainer.innerText.matchAll(/\$([0-9]+(?:\.[0-9]{2})?)/g)].map((m) =>
          parseFloat(m[1])
        );

        if (pricesFound.length === 1) {
          salePrice = pricesFound[0];
          regularPrice = pricesFound[0];
        } else if (pricesFound.length >= 2) {
          salePrice = Math.min(...pricesFound);
          regularPrice = Math.max(...pricesFound);
        }

        let promoBadge = '';
        const dealEl = card.querySelector('[data-component="product-deals"], [class*="promo"], [class*="deal"]');
        if (dealEl) {
          const dealText = dealEl.innerText.replace(/\s+/g, ' ').trim();
          if (dealText && !/^limited time only$/i.test(dealText)) {
            promoBadge = dealText;
          }
        }
        const hasSpecial = promoBadge.length > 0 || salePrice < regularPrice;

        productMap.set(pid, {
          id: pid.startsWith('bbw_') ? pid : 'bbw_' + pid,
          sku: pid.replace(/[^0-9]/g, '') || pid,
          name: name,
          brand: 'Bath & Body Works',
          store: 'Bath & Body Works',
          category: 'Fragrance',
          department: 'All Fragrance',
          productType: 'All Fragrance',
          subCategory: 'All Fragrance',
          price: salePrice,
          regularPrice: regularPrice,
          salePrice: salePrice,
          promoBadge: promoBadge,
          hasSpecial: hasSpecial,
          imageUrl: imageUrl,
          productUrl: productUrl.split('?')[0],
          unit: 'Standard',
          unitShort: 'Item',
          fragranceNotes: [],
          fragranceOverview: '',
          fragranceTiers: { top: [], heart: [], base: [] },
          inStock: true,
          isOnlineExclusive: false,
          rating: 4.8,
          ratingCount: 140,
        });
      } catch (err) {
        console.warn('BBW card parse skipped:', err);
      }
    });
  }

  function harvestVisibleCards(productMap, overrideMode) {
    const mode = getActiveStoreMode(overrideMode);
    if (mode === 'aldi') {
      harvestAldiCards(productMap);
    } else {
      harvestBbwCards(productMap);
    }
  }

  function downloadJsonFile(products, filename) {
    const blob = new Blob([JSON.stringify(products, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  }

  function isUnscentedHardware(name) {
    const lower = (name || '').toLowerCase();
    return (
      lower.includes('holder') ||
      lower.includes('pedestal') ||
      lower.includes('fragrance plug') ||
      lower.includes('duo plug') ||
      lower.includes('reed vessel') ||
      lower.includes('wristlet') ||
      lower.includes('lanyard') ||
      lower.includes('snapcase')
    );
  }

  // =========================================================================
  // 6. RUNTIME MESSAGE LISTENERS (Communicates with popup.js & background.js)
  // =========================================================================
  chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
    if (!request) return false;

    if (request.type === 'READ_LIVE_PDP_NOTES') {
      waitForHydratedFragrance()
        .then((data) => sendResponse(data))
        .catch(() =>
          sendResponse({
            overview: '',
            notes: [],
            tiers: { top: [], heart: [], base: [] },
            promoInfo: { hasDealBlock: false, promoBadge: '' },
          })
        );
      return true;
    }

    if (request.type === 'READ_LIVE_ALDI_PDP') {
      waitForHydratedAldiPdp()
        .then((data) => sendResponse(data))
        .catch(() => sendResponse({ description: '', ingredients: '', unit: '' }));
      return true;
    }

    if (request.action === 'GET_PAGE_INFO') {
      const mode = getActiveStoreMode(request.storeMode);
      const cat = getPageCategoryName();
      const filename = slugifyToFilename(cat, mode);
      const tempMap = new Map();
      harvestVisibleCards(tempMap, mode);
      sendResponse({ categoryName: cat, filename: filename, count: tempMap.size, activeStoreMode: mode });
      return true;
    }

    if (request.action === 'PLUCK_QUICK') {
      const mode = getActiveStoreMode(request.storeMode);
      const filename = request.filename || slugifyToFilename(getPageCategoryName(), mode);
      const collected = new Map();
      harvestVisibleCards(collected, mode);
      const products = Array.from(collected.values());

      if (products.length > 0) {
        downloadJsonFile(products, filename);
        sendResponse({ success: true, count: products.length, filename: filename });
      } else {
        sendResponse({ success: false, message: 'No visible products found.' });
      }
      return true;
    }

    if (request.action === 'PLUCK_AUTOSCROLL') {
      (async () => {
        const mode = getActiveStoreMode(request.storeMode);
        const filename = request.filename || slugifyToFilename(getPageCategoryName(), mode);
        const collected = new Map();

        window.scrollTo({ top: 0, behavior: 'instant' });
        await new Promise((r) => setTimeout(r, 400));
        harvestVisibleCards(collected, mode);

        let unchangedCycles = 0;
        let isAutoScrolling = true;

        while (isAutoScrolling && unchangedCycles < 4) {
          const prevSize = collected.size;

          const loadMoreBtn = Array.from(document.querySelectorAll('button, a')).find((el) =>
            /^(load more|show more|view more)/i.test(el.innerText.trim())
          );
          if (loadMoreBtn) {
            loadMoreBtn.click();
            await new Promise((r) => setTimeout(r, 1100));
          }

          window.scrollBy({ top: Math.floor(window.innerHeight * 0.75), behavior: 'smooth' });
          await new Promise((r) => setTimeout(r, 550));
          harvestVisibleCards(collected, mode);

          chrome.runtime.sendMessage({
            type: 'STATUS_UPDATE',
            text: `🧲 Sweeping... ${collected.size} unique products captured`
          });

          const atBottom = window.innerHeight + window.scrollY >= document.body.scrollHeight - 40;
          if (collected.size === prevSize && atBottom) {
            unchangedCycles++;
          } else {
            unchangedCycles = 0;
          }
        }

        const allProducts = Array.from(collected.values());
        if (allProducts.length > 0) {
          downloadJsonFile(allProducts, filename);
          sendResponse({ success: true, count: allProducts.length, filename: filename });
        } else {
          sendResponse({ success: false, message: 'No products captured.' });
        }
      })();
      return true;
    }

    if (request.action === 'COPY_JSON') {
      const mode = getActiveStoreMode(request.storeMode);
      const collected = new Map();
      harvestVisibleCards(collected, mode);
      const products = Array.from(collected.values());

      if (products.length > 0) {
        navigator.clipboard.writeText(JSON.stringify(products, null, 2))
          .then(() => sendResponse({ success: true, count: products.length }))
          .catch(() => sendResponse({ success: false, message: 'Clipboard error' }));
      } else {
        sendResponse({ success: false, message: 'No products found.' });
      }
      return true;
    }

    if (request.action === 'DOWNLOAD_JSON') {
      const mode = getActiveStoreMode(request.storeMode);
      const filename = request.filename || slugifyToFilename(getPageCategoryName(), mode);
      const collected = new Map();
      harvestVisibleCards(collected, mode);
      const products = Array.from(collected.values());

      if (products.length > 0) {
        downloadJsonFile(products, filename);
        sendResponse({ success: true, count: products.length, filename: filename });
      } else {
        sendResponse({ success: false, message: 'No products found.' });
      }
      return true;
    }

    if (request.action === 'ENRICH_NOTES') {
      (async () => {
        const items = request.items || [];
        const mode = getActiveStoreMode(request.storeMode);
        let enrichedCount = 0;
        let skippedHardware = 0;

        // --- ALDI ENRICHMENT WORKFLOW ---
        if (mode === 'aldi') {
          for (let i = 0; i < items.length; i++) {
            const item = items[i];

            // Repair Cloudfront image URLs
            if (item.imageUrl && item.imageUrl.includes('d2lnr5mha7bycj.cloudfront.net')) {
              const m = item.imageUrl.match(/(d2lnr5mha7bycj\.cloudfront\.net\/[^\s"'?]+)/i);
              if (m) item.imageUrl = `https://${m[1]}`;
            }

            // Extract true ALDI brand
            if (!item.brand || item.brand === 'ALDI') {
              item.brand = extractAldiBrand(item.name);
            }

            const needsDetails = !item.description || item.description.trim().length === 0;
            const needsUnit = !item.unit || item.unit === 'Each';
            if (!needsDetails && !needsUnit) continue;

            chrome.runtime.sendMessage({
              type: 'STATUS_UPDATE',
              text: `✨ ALDI (${i + 1}/${items.length}) ${item.name.slice(0, 18)}...`
            });

            if (item.productUrl && item.productUrl.includes('/products/')) {
              const res = await chrome.runtime.sendMessage({
                type: 'HYDRATE_ALDI_PDP',
                url: item.productUrl,
              });
              if (res) {
                if (res.description) item.description = res.description;
                if (res.ingredients) item.ingredients = res.ingredients;
                if (res.unit && (item.unit === 'Each' || !item.unit)) {
                  item.unit = res.unit;
                  item.unitShort = res.unit;
                }
                if (res.description || res.ingredients || res.unit) enrichedCount++;
              }
            } else {
              const matchingBtn = Array.from(document.querySelectorAll('[data-item-card-button="true"]')).find(
                (btn) => {
                  const h = btn.querySelector('h2, h3, [role="heading"]');
                  return h && h.textContent.replace(/\s+/g, ' ').trim() === item.name;
                }
              );

              if (matchingBtn) {
                matchingBtn.click();
                const res = await waitForHydratedAldiPdp();

                if (window.location.pathname.includes('/products/')) {
                  item.productUrl = window.location.href.split('?')[0];
                }

                if (res.description) item.description = res.description;
                if (res.ingredients) item.ingredients = res.ingredients;
                if (res.unit && (item.unit === 'Each' || !item.unit)) {
                  item.unit = res.unit;
                  item.unitShort = res.unit;
                }
                if (res.description || res.ingredients || res.unit) enrichedCount++;

                const closeBtn = document.querySelector(
                  '[role="dialog"] button[aria-label*="close" i], [role="dialog"] button[aria-label*="back" i]'
                );
                if (closeBtn) {
                  closeBtn.click();
                } else {
                  document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', bubbles: true }));
                }
                await new Promise((r) => setTimeout(r, 350));
              }
            }
          }

          downloadJsonFile(items, request.fileName || 'aldi_enriched_catalog.json');
          chrome.runtime.sendMessage({
            type: 'STATUS_UPDATE',
            text: `✅ Enriched ${enrichedCount} ALDI items & fixed image URLs!`
          });
          return;
        }

        // --- BBW ENRICHMENT WORKFLOW ---
        for (let i = 0; i < items.length; i++) {
          const item = items[i];
          if (isUnscentedHardware(item.name)) {
            skippedHardware++;
            continue;
          }

          const needsOverview = !item.fragranceOverview || item.fragranceOverview.trim().length === 0;
          const needsNotes = !item.fragranceNotes || item.fragranceNotes.length <= 1;
          const hasSuspiciousPromo =
            item.salePrice < item.regularPrice &&
            item.promoBadge &&
            /buy 3/i.test(item.promoBadge);

          if ((!needsOverview && !needsNotes && !hasSuspiciousPromo) || !item.productUrl) continue;

          chrome.runtime.sendMessage({
            type: 'STATUS_UPDATE',
            text: `✨ Hydrating (${i + 1}/${items.length}) ${item.name.slice(0, 18)}...`
          });

          const res = await chrome.runtime.sendMessage({
            type: 'HYDRATE_PDP',
            url: item.productUrl
          });

          if (res) {
            if (res.overview) item.fragranceOverview = res.overview;
            if (res.notes && res.notes.length > 0) item.fragranceNotes = res.notes;
            if (res.tiers && (res.tiers.top?.length || res.tiers.heart?.length || res.tiers.base?.length)) {
              item.fragranceTiers = res.tiers;
            }
            if (res.promoInfo && res.promoInfo.hasDealBlock) {
              item.promoBadge = res.promoInfo.promoBadge;
              item.hasSpecial = item.promoBadge.length > 0 || item.salePrice < item.regularPrice;
            }
            if (res.overview || (res.notes && res.notes.length > 0)) {
              enrichedCount++;
            }
          }
        }

        downloadJsonFile(items, request.fileName || 'enriched_catalog.json');
        chrome.runtime.sendMessage({
          type: 'STATUS_UPDATE',
          text: `✅ Enriched ${enrichedCount} items & verified promos! (${skippedHardware} holders skipped)`
        });
      })();
      return true;
    }
  });
})();
