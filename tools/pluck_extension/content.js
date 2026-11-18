// File: tools/pluck_extension/content.js

(function () {
  function splitNotesString(rawNotes) {
    return rawNotes
      .replace(/^(?:fragrance\s+)?notes\s*:\s*/i, '')
      .replace(/\.+$/, '')
      .split(/,\s*|\s*•\s*/)
      .map((n) => n.replace(/^note:\s*/i, '').replace(/\.+$/, '').trim())
      .filter((n) => n.length > 1 && n.length < 60);
  }

  function findFragranceRegion() {
    const direct = document.querySelector(
      '[role="region"][aria-label*="fragrance" i], [id*="content:fragrance"], [id*="item:fragrance"]'
    );
    if (direct) return direct;

    const buttons = Array.from(document.querySelectorAll('button, [role="button"]'));
    const fragBtn = buttons.find((b) => b.innerText.trim().toLowerCase() === 'fragrance');
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

  function readRenderedFragranceDom() {
    let overview = '';
    let notes = [];
    const tiers = { top: [], heart: [], base: [] };

    const container = findFragranceRegion() || document.querySelector('.emotion-16zqzjt');

    if (container) {
      const paragraphs = Array.from(container.querySelectorAll('p'))
        .map((p) => p.innerText.replace(/\s+/g, ' ').trim())
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
      const allElements = Array.from(document.querySelectorAll('h2, h3, h4, p, div'));
      for (const el of allElements) {
        const txt = el.innerText.trim();
        if (/^what it smells like/i.test(txt)) {
          if (!overview && el.nextElementSibling) {
            overview = el.nextElementSibling.innerText.trim();
          }
        } else if (notes.length === 0 && /^(?:fragrance\s+)?notes\s*:\s*.+/i.test(txt)) {
          notes = splitNotesString(txt);
          if (!overview && el.previousElementSibling) {
            const prev = el.previousElementSibling.innerText.replace(/\s+/g, ' ').trim();
            if (prev.length > 12) overview = prev;
          }
        }
      }
    }

    return { overview, notes, tiers };
  }

  function getPageCategoryName() {
    const headingEl = document.querySelector(
      'h1[data-dan-display="product-list--heading"], h1.wick-heading, .wick-heading, h1'
    );
    return headingEl ? headingEl.innerText.trim() : '';
  }

  function slugifyToFilename(rawTitle) {
    if (!rawTitle) return 'bbw_catalog.json';
    const clean = rawTitle
      .toLowerCase()
      .replace(/&/g, 'and')
      .replace(/['"]/g, '')
      .replace(/[^a-z0-9]+/g, '_')
      .replace(/^_+|_+$/g, '');

    if (clean.includes('candle')) return 'candles.json';
    if (clean.includes('wallflower') || clean.includes('diffuser')) return 'wallflowers_diffusers.json';
    if (clean.includes('fragrance') && !clean.includes('home')) return 'all_fragrance.json';
    if (clean.includes('soap') || clean.includes('sanitizer')) return 'hand_soaps_sanitizers.json';
    if (clean.includes('men')) return 'mens_shop.json';
    if (clean.includes('home') || clean.includes('laundry')) return 'home_care.json';
    if (clean.includes('body')) return 'body_care.json';
    return `${clean}.json`;
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

  function harvestVisibleCards(productMap) {
    const cardSelectors = ['.product-tile', '.product', '.grid-tile', '[data-component*="product"]', 'article'];
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
        (el) => !el.matches('button, a, input, select')
      );
    }

    candidateCards.forEach((card) => {
      try {
        const linkEl = card.querySelector('a[href*="/p/"]') || card.querySelector('a.link, a[class*="name"]');
        const imgEl = card.querySelector('img[src*="/hires/"], img[data-src*="/hires/"], img[src*="/dw/image/"], img');
        if (!linkEl && !imgEl) return;

        let productUrl = linkEl ? linkEl.href : '';
        if (productUrl.startsWith('/')) productUrl = window.location.origin + productUrl;

        let pid = card.getAttribute('data-pid') || '';
        if (!pid && productUrl) {
          const match = productUrl.match(/-([0-9]{8,10})(?:\.html|\?|$)/);
          if (match) pid = match[1];
        }
        if (!pid) {
          const btn = card.querySelector('[data-pid]');
          if (btn) pid = btn.getAttribute('data-pid') || '';
        }
        if (!pid) return;

        let name = '';
        if (imgEl) {
          const alt = (imgEl.getAttribute('alt') || imgEl.getAttribute('title') || '').trim();
          if (alt.length > 3 && !alt.toLowerCase().includes('swatch') && !alt.toLowerCase().includes('icon')) {
            name = alt;
          }
        }
        if (!name && linkEl) {
          const linkText = linkEl.innerText.trim();
          if (linkText.length > 3) name = linkText;
        }
        if (!name) {
          const titleEl = card.querySelector('[class*="title"], [class*="name"], h2, h3');
          if (titleEl) name = titleEl.innerText.trim();
        }
        if (!name) return;

        let imageUrl = '';
        if (imgEl) {
          imageUrl = imgEl.getAttribute('data-src') || imgEl.getAttribute('src') || '';
          if (imageUrl.startsWith('//')) imageUrl = 'https:' + imageUrl;
        }

        let salePrice = 0.0;
        let regularPrice = 0.0;
        const cardText = card.innerText;
        const pricesFound = [...cardText.matchAll(/\$([0-9]+(?:\.[0-9]{2})?)/g)].map((m) => parseFloat(m[1]));

        if (pricesFound.length === 1) {
          salePrice = pricesFound[0];
          regularPrice = pricesFound[0];
        } else if (pricesFound.length >= 2) {
          salePrice = Math.min(...pricesFound);
          regularPrice = Math.max(...pricesFound);
        }

        let promoBadge = '';
        const lines = cardText.split('\n').map((l) => l.trim()).filter((l) => l.length > 0);
        for (const line of lines) {
          const lineUpper = line.toUpperCase();
          if (
            lineUpper.includes('MIX & MATCH') ||
            lineUpper.includes('BUY 3, GET 3') ||
            lineUpper.includes('BUY 2, GET 1') ||
            lineUpper.includes('BUY 3, GET 1') ||
            lineUpper.includes('BUY 1, GET 1') ||
            lineUpper.includes('FREE') ||
            /\b\d+\/\$\d+\b/.test(lineUpper)
          ) {
            promoBadge = line.replace(/\s+/g, ' ');
            break;
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
          productUrl: productUrl || `${window.location.origin}/p/${pid}`,
          unit: 'Standard',
          unitShort: 'Item',
          fragranceNotes: [],
          fragranceOverview: '',
          fragranceTiers: { top: [], heart: [], base: [] },
          inStock: true,
          isOnlineExclusive: false,
          rating: 4.8,
          ratingCount: 140
        });
      } catch (err) {
        console.warn('Card parse skipped:', err);
      }
    });
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

  // --- RUNTIME MESSAGE LISTENERS (Communicates with popup.js & background.js) ---
  chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
    if (!request) return false;

    if (request.type === 'READ_LIVE_PDP_NOTES') {
      try {
        sendResponse(readRenderedFragranceDom());
      } catch (_) {
        sendResponse({ overview: '', notes: [], tiers: { top: [], heart: [], base: [] } });
      }
      return false; // Synchronous response — closes channel cleanly with zero dangling promises
    }

    if (request.action === 'GET_PAGE_INFO') {
      const cat = getPageCategoryName();
      const filename = slugifyToFilename(cat);
      const tempMap = new Map();
      harvestVisibleCards(tempMap);
      sendResponse({ categoryName: cat, filename: filename, count: tempMap.size });
      return true;
    }

    if (request.action === 'PLUCK_QUICK') {
      const filename = request.filename || slugifyToFilename(getPageCategoryName());
      const collected = new Map();
      harvestVisibleCards(collected);
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
        const filename = request.filename || slugifyToFilename(getPageCategoryName());
        const collected = new Map();

        window.scrollTo({ top: 0, behavior: 'instant' });
        await new Promise((r) => setTimeout(r, 400));
        harvestVisibleCards(collected);

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
          harvestVisibleCards(collected);

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
      const collected = new Map();
      harvestVisibleCards(collected);
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
      const filename = request.filename || slugifyToFilename(getPageCategoryName());
      const collected = new Map();
      harvestVisibleCards(collected);
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
        let enrichedCount = 0;
        let skippedHardware = 0;

        for (let i = 0; i < items.length; i++) {
          const item = items[i];
          if (isUnscentedHardware(item.name)) {
            skippedHardware++;
            continue;
          }

          const needsOverview = !item.fragranceOverview || item.fragranceOverview.trim().length === 0;
          const needsNotes = !item.fragranceNotes || item.fragranceNotes.length <= 1;
          if ((!needsOverview && !needsNotes) || !item.productUrl) continue;

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
            if (res.overview || (res.notes && res.notes.length > 0)) {
              enrichedCount++;
            }
          }
        }

        downloadJsonFile(items, request.fileName || 'enriched_catalog.json');
        chrome.runtime.sendMessage({
          type: 'STATUS_UPDATE',
          text: `✅ Enriched ${enrichedCount} items! (${skippedHardware} holders skipped)`
        });
      })();
      return true;
    }
  });
})();
