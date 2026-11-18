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

  chrome.runtime.onMessage.addListener((msg, sender, sendResponse) => {
    if (!msg || msg.type !== 'READ_LIVE_PDP_NOTES') return false;
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
  });

  if (document.getElementById('pluck-hud-root')) return;

  // =========================================================================
  // 2. STORE MODE & CATEGORY TITLE ENGINE
  // =========================================================================
  function detectStoreKey() {
    const host = window.location.hostname.toLowerCase();
    if (host.includes('aldi.us')) return 'aldi';
    return 'bbw';
  }

  function getActiveStoreMode() {
    const selectEl = document.getElementById('pluck-store-select');
    if (selectEl && selectEl.value !== 'auto') {
      return selectEl.value;
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
    const mode = storeMode || getActiveStoreMode();
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
  // 3. ALDI (INSTACART STOREFRONT PRO) CARD HARVESTER
  // =========================================================================
  function harvestAldiCards(productMap) {
    const categoryName = getPageCategoryName() || 'Groceries';

    let candidateCards = Array.from(document.querySelectorAll('[data-item-card-holder="true"]'));

    if (candidateCards.length === 0) {
      const links = Array.from(document.querySelectorAll('a[href*="/products/"]'));
      const tiles = new Set();
      links.forEach((a) => {
        const container = a.closest('li, [data-item-card-holder], article') || a.parentElement;
        if (container) tiles.add(container);
      });
      candidateCards = Array.from(tiles);
    }

    candidateCards.forEach((card) => {
      try {
        const linkEl = card.querySelector('a[href*="/products/"]');
        if (!linkEl) return;

        let productUrl = linkEl.getAttribute('href') || '';
        if (productUrl.startsWith('/')) {
          productUrl = window.location.origin + productUrl;
        }

        const idMatch = productUrl.match(/\/products\/([0-9]{4,12})(?:\/|\?|$)/);
        const rawId = idMatch ? idMatch[1] : '';
        if (!rawId) return;

        const headingEl = card.querySelector('h2, h3, [role="heading"]');
        let name = headingEl ? headingEl.textContent.replace(/\s+/g, ' ').trim() : '';
        if (!name) {
          name = (linkEl.getAttribute('aria-label') || '').replace(/\s+/g, ' ').trim();
        }
        if (!name || name.length < 2) return;

        const imgEl = card.querySelector('img');
        let imageUrl = '';
        if (imgEl) {
          const srcset = imgEl.getAttribute('srcset') || '';
          if (srcset) {
            const parts = srcset.split(',').map((s) => s.trim().split(' ')[0]).filter(Boolean);
            imageUrl = parts[parts.length - 1] || '';
          }
          if (!imageUrl) {
            imageUrl = imgEl.getAttribute('src') || imgEl.getAttribute('data-src') || '';
          }
          if (imageUrl.startsWith('//')) imageUrl = 'https:' + imageUrl;
        }

        const fullText = card.textContent.replace(/\s+/g, ' ');
        const currentMatch = fullText.match(/Current price:\s*\$([0-9]+(?:\.[0-9]{2})?)/i);
        const originalMatch = fullText.match(/Original price:\s*\$([0-9]+(?:\.[0-9]{2})?)/i);

        let salePrice = 0.0;
        let regularPrice = 0.0;

        if (currentMatch) {
          salePrice = parseFloat(currentMatch[1]);
          regularPrice = originalMatch ? parseFloat(originalMatch[1]) : salePrice;
        } else {
          const pricesFound = [...fullText.matchAll(/\$([0-9]+(?:\.[0-9]{2})?)/g)].map((m) =>
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
          /\b(\d+(?:\.\d+)?\s*(?:fl\s*oz|oz|lb|lbs|gal|qt|pt|ml|l|g|kg|ct|pk|pack)|per\s+lb)\b/i
        );
        const unit = unitMatch ? unitMatch[1] : 'Each';

        const inStock = !/out of stock|sold out/i.test(fullText);
        let promoBadge = '';
        if (salePrice < regularPrice) promoBadge = 'Price Drop';
        else if (/aldi finds/i.test(fullText)) promoBadge = 'ALDI Finds';
        else if (/weekly special/i.test(fullText)) promoBadge = 'Weekly Special';

        productMap.set(rawId, {
          id: `aldi_${rawId}`,
          sku: rawId,
          name: name,
          brand: 'ALDI',
          store: 'ALDI',
          category: categoryName,
          department: categoryName,
          productType: categoryName,
          subCategory: categoryName,
          price: salePrice,
          regularPrice: regularPrice,
          salePrice: salePrice,
          promoBadge: promoBadge,
          hasSpecial: promoBadge.length > 0 || salePrice < regularPrice,
          imageUrl: imageUrl,
          productUrl: productUrl.split('?')[0],
          unit: unit,
          unitShort: unit,
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
  // 4. BATH & BODY WORKS CARD HARVESTER
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

  function harvestVisibleCards(productMap) {
    if (getActiveStoreMode() === 'aldi') {
      harvestAldiCards(productMap);
    } else {
      harvestBbwCards(productMap);
    }
  }

  // =========================================================================
  // 5. HUD WITH STORE SELECTOR & ACTIONS
  // =========================================================================
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

  const detectedStore = detectStoreKey();
  const initialTitle = getPageCategoryName();
  const hud = document.createElement('div');
  hud.id = 'pluck-hud-root';
  hud.innerHTML = `
    <div id="pluck-hud">
      <div id="pluck-hud-header">
        <div class="pluck-title-row">
          <span class="pluck-icon">⚡</span>
          <span class="pluck-title">Pluck 4.1</span>
        </div>
        <button id="pluck-refresh-btn" title="Refresh & Rescan Page">🔄 Rescan</button>
      </div>

      <div class="pluck-field-group">
        <label for="pluck-store-select" class="pluck-label">Target Store Adapter:</label>
        <select id="pluck-store-select" style="background:#161922;border:1px solid rgba(255,255,255,0.18);color:#fff;font-size:12px;font-weight:700;padding:7px 10px;border-radius:8px;outline:none;">
          <option value="auto" selected>Auto-Detect (${detectedStore.toUpperCase()})</option>
          <option value="bbw">Bath & Body Works</option>
          <option value="aldi">ALDI (Instacart Storefront)</option>
        </select>
      </div>

      <div class="pluck-field-group">
        <label for="pluck-filename-input" class="pluck-label">Output Filename:</label>
        <input type="text" id="pluck-filename-input" value="${slugifyToFilename(initialTitle, detectedStore)}" spellcheck="false" />
      </div>

      <button id="pluck-autoscroll-btn" class="pluck-primary-btn">🧲 Auto-Scroll & Pluck All</button>
      <button id="pluck-extract-btn" class="pluck-secondary-btn">⚡ Pluck Current View Only</button>
      <button id="pluck-enrich-btn" class="pluck-enrich-btn" style="display:${detectedStore === 'bbw' ? 'block' : 'none'};">✨ Enrich Notes & Fix Promos</button>
      <input type="file" id="pluck-file-input" accept=".json" style="display:none;" />
      <div id="pluck-status">Ready (${detectedStore.toUpperCase()} mode)</div>
    </div>
  `;
  document.body.appendChild(hud);

  const storeSelect = document.getElementById('pluck-store-select');
  const filenameInput = document.getElementById('pluck-filename-input');
  const statusEl = document.getElementById('pluck-status');
  const enrichBtn = document.getElementById('pluck-enrich-btn');
  const fileInput = document.getElementById('pluck-file-input');
  let isAutoScrolling = false;

  function rescanPage() {
    const mode = getActiveStoreMode();
    const title = getPageCategoryName();
    filenameInput.value = slugifyToFilename(title, mode);
    if (enrichBtn) enrichBtn.style.display = mode === 'bbw' ? 'block' : 'none';

    const probeMap = new Map();
    harvestVisibleCards(probeMap);
    statusEl.innerText = `🔄 ${mode.toUpperCase()}: "${title || 'Catalog'}" (${probeMap.size} visible)`;
  }

  storeSelect.addEventListener('change', rescanPage);
  document.getElementById('pluck-refresh-btn').addEventListener('click', rescanPage);
  window.addEventListener('popstate', rescanPage);

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

  document.getElementById('pluck-autoscroll-btn').addEventListener('click', async () => {
    if (isAutoScrolling) {
      isAutoScrolling = false;
      return;
    }

    isAutoScrolling = true;
    const btn = document.getElementById('pluck-autoscroll-btn');
    btn.innerText = '🛑 Stop & Save Collected';

    const filename = (filenameInput.value || 'catalog.json').trim();
    const collected = new Map();

    window.scrollTo({ top: 0, behavior: 'instant' });
    await new Promise((r) => setTimeout(r, 400));
    harvestVisibleCards(collected);

    let unchangedCycles = 0;
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

      statusEl.innerText = `🧲 Sweeping... ${collected.size} unique products captured`;

      const atBottom = window.innerHeight + window.scrollY >= document.body.scrollHeight - 40;
      if (collected.size === prevSize && atBottom) {
        unchangedCycles++;
      } else {
        unchangedCycles = 0;
      }
    }

    isAutoScrolling = false;
    btn.innerText = '🧲 Auto-Scroll & Pluck All';

    const allProducts = Array.from(collected.values());
    if (allProducts.length === 0) {
      statusEl.innerText = '❌ 0 products found.';
      return;
    }

    downloadJsonFile(allProducts, filename);
    statusEl.innerText = `✅ Captured all ${allProducts.length} products to ${filename}!`;
  });

  document.getElementById('pluck-extract-btn').addEventListener('click', () => {
    const filename = (filenameInput.value || 'catalog.json').trim();
    const collected = new Map();
    harvestVisibleCards(collected);
    const products = Array.from(collected.values());

    if (products.length === 0) {
      statusEl.innerText = '❌ 0 products found.';
      return;
    }
    downloadJsonFile(products, filename);
    statusEl.innerText = `✅ Plucked ${products.length} visible items to ${filename}!`;
  });

  if (enrichBtn && fileInput) {
    enrichBtn.addEventListener('click', () => {
      fileInput.value = '';
      fileInput.click();
    });

    fileInput.addEventListener('change', async (e) => {
      const file = e.target.files[0];
      if (!file) return;

      try {
        const rawText = await file.text();
        const items = JSON.parse(rawText);
        if (!Array.isArray(items)) {
          statusEl.innerText = '❌ Invalid JSON array file';
          return;
        }

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
          const hasSuspiciousPromo =
            item.salePrice < item.regularPrice &&
            item.promoBadge &&
            /buy 3/i.test(item.promoBadge);

          if ((!needsOverview && !needsNotes && !hasSuspiciousPromo) || !item.productUrl) continue;

          statusEl.innerText = `✨ Hydrating (${i + 1}/${items.length}) ${item.name.slice(0, 20)}...`;

          const res = await chrome.runtime.sendMessage({
            type: 'HYDRATE_PDP',
            url: item.productUrl,
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

        downloadJsonFile(items, file.name);
        statusEl.innerText = `✅ Enriched ${enrichedCount} items & verified promos! (${skippedHardware} holders skipped)`;
      } catch (err) {
        statusEl.innerText = '❌ Failed to parse JSON file';
      }
    });
  }
})();
