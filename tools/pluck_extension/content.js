// File: tools/pluck_extension/content.js

(function () {
  if (document.getElementById('pluck-hud-root')) return;

  // --- 1. DYNAMIC CATEGORY TITLE & SLUG ENGINE ---
  function getPageCategoryName() {
    const headingEl = document.querySelector(
      'h1[data-dan-display="product-list--heading"], h1.wick-heading, .wick-heading, h1'
    );
    if (headingEl && headingEl.innerText.trim().length > 0) {
      return headingEl.innerText.trim();
    }
    return '';
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

  // --- 2. BULLETPROOF MULTI-TIER FRAGRANCE PARSER ---
  function parseFragranceBlock(doc) {
    let overview = '';
    let notes = [];

    // Target fragrance/scent containers
    const containers = Array.from(doc.querySelectorAll(
      '[id*="fragrance"], [class*="fragrance"], [id*="scent"], [class*="scent"], [data-component*="fragrance"], .pdp-details, .wick-accordion'
    ));

    const textNodes = [];
    containers.forEach(c => {
      c.querySelectorAll('p, div, li, span').forEach(el => {
        const txt = el.textContent.replace(/\s+/g, ' ').trim();
        if (txt.length > 3 && !textNodes.includes(txt)) textNodes.push(txt);
      });
    });

    if (textNodes.length === 0) {
      doc.querySelectorAll('p, li').forEach(el => {
        const txt = el.textContent.replace(/\s+/g, ' ').trim();
        if (txt.length > 3 && !textNodes.includes(txt)) textNodes.push(txt);
      });
    }

    for (const text of textNodes) {
      if (/^(?:fragrance\s+|scent\s+)?notes\s*:/i.test(text) || /what\s+it\s+smells\s+like\s*:/i.test(text)) {
        const cleaned = text
          .replace(/^(?:fragrance\s+|scent\s+)?notes\s*:\s*/i, '')
          .replace(/^what\s+it\s+smells\s+like\s*:\s*/i, '')
          .replace(/\.+$/, '')
          .trim();

        if (cleaned.length > 0) {
          notes = cleaned
            .split(/,\s*|\s*•\s*|\s*and\s+|\s*;\s*/)
            .map((n) => n.replace(/^note:\s*/i, '').replace(/\.+$/, '').trim())
            .filter((n) => n.length > 0 && n.length < 50);
        }
      } else if (!overview && (/^(?:what\s+it\s+does|fragrance\s+description)\s*:/i.test(text) || text.length > 25)) {
        if (!text.toLowerCase().includes('ingredients') && !text.toLowerCase().includes('usage') && !text.toLowerCase().includes('shipping')) {
          overview = text.replace(/^(?:what\s+it\s+does|fragrance\s+description)\s*:\s*/i, '').trim();
        }
      }
    }

    // JSON-LD Fallback (<script type="application/ld+json">)
    if (notes.length === 0) {
      const scripts = doc.querySelectorAll('script[type="application/ld+json"]');
      scripts.forEach(s => {
        try {
          const json = JSON.parse(s.textContent);
          const desc = json.description || json.disambiguatingDescription || '';
          if (desc && /notes\s*:/i.test(desc)) {
            const match = desc.match(/notes\s*:\s*([^.]+)/i);
            if (match) {
              notes = match[1].split(/,\s*/).map(n => n.trim()).filter(n => n.length > 0);
            }
          }
        } catch (_) {}
      });
    }

    return { overview, notes };
  }

  const initialTitle = getPageCategoryName();
  const initialFilename = slugifyToFilename(initialTitle);

  // --- 3. INJECT STREAMLINED HUD ---
  const hud = document.createElement('div');
  hud.id = 'pluck-hud-root';
  hud.innerHTML = `
    <div id="pluck-hud">
      <div id="pluck-hud-header">
        <div class="pluck-title-row">
          <span class="pluck-icon">⚡</span>
          <span class="pluck-title">Pluck 2.4</span>
        </div>
        <button id="pluck-refresh-btn" title="Refresh & Rescan Page">🔄 Rescan</button>
      </div>

      <div class="pluck-field-group">
        <label for="pluck-filename-input" class="pluck-label">Output Filename:</label>
        <input type="text" id="pluck-filename-input" value="${initialFilename}" spellcheck="false" />
      </div>

      <button id="pluck-extract-btn" class="pluck-primary-btn">⚡ Extract & Download JSON</button>
      <button id="pluck-copy-btn" class="pluck-secondary-btn">📋 Copy to Clipboard</button>
      <button id="pluck-enrich-btn" class="pluck-enrich-btn">✨ Enrich Missing Notes from JSON</button>
      <input type="file" id="pluck-file-input" accept=".json" style="display:none;" />
      <div id="pluck-status">Ready to pluck</div>
    </div>
  `;
  document.body.appendChild(hud);

  const filenameInput = document.getElementById('pluck-filename-input');
  const statusEl = document.getElementById('pluck-status');
  const fileInput = document.getElementById('pluck-file-input');

  function rescanPage() {
    const title = getPageCategoryName();
    filenameInput.value = slugifyToFilename(title);

    if (window.location.pathname.includes('/p/')) {
      const parsed = parseFragranceBlock(document);
      statusEl.innerText = parsed.notes.length > 0
        ? `🌸 PDP Ready: ${parsed.notes.length} notes found`
        : `📄 PDP Detected: "${title}"`;
      return;
    }

    const cards = document.querySelectorAll('.product-tile, .product, .grid-tile, [data-component*="product"]');
    const count = Array.from(cards).filter((el) => !el.matches('button, a, input, select')).length;
    statusEl.innerText = `🔄 Detected: "${title || 'Catalog'}" (${count} items)`;
  }

  document.getElementById('pluck-refresh-btn').addEventListener('click', rescanPage);
  window.addEventListener('popstate', rescanPage);

  // --- 4. SINGLE PRODUCT PAGE (PDP) EXTRACTOR ---
  function extractSinglePdp() {
    const title = getPageCategoryName();
    if (!title) return null;

    const urlMatch = window.location.href.match(/-([0-9]{8,10})(?:\.html|\?|$)/);
    const pid = urlMatch ? urlMatch[1] : Date.now().toString();
    const { overview, notes } = parseFragranceBlock(document);

    const bodyText = document.body.innerText;
    const prices = [...bodyText.matchAll(/\$([0-9]+(?:\.[0-9]{2})?)/g)].map((m) => parseFloat(m[1]));
    const salePrice = prices.length > 0 ? Math.min(...prices) : 0.0;
    const regularPrice = prices.length > 1 ? Math.max(...prices) : salePrice;

    const imgEl = document.querySelector('img[src*="/hires/"], img[src*="/dw/image/"]');
    let imageUrl = imgEl ? (imgEl.getAttribute('src') || '') : '';
    if (imageUrl.startsWith('//')) imageUrl = 'https:' + imageUrl;

    return [{
      id: `bbw_${pid}`,
      sku: pid,
      name: title,
      brand: 'Bath & Body Works',
      store: 'Bath & Body Works',
      category: 'Fragrance',
      department: 'All Fragrance',
      productType: 'All Fragrance',
      subCategory: 'All Fragrance',
      price: salePrice,
      regularPrice: regularPrice,
      salePrice: salePrice,
      promoBadge: '',
      hasSpecial: salePrice < regularPrice,
      imageUrl: imageUrl,
      productUrl: window.location.href.split('?')[0],
      unit: 'Standard',
      unitShort: 'Item',
      fragranceNotes: notes,
      fragranceOverview: overview,
      fragranceTiers: { top: [], heart: [], base: [] },
      inStock: true,
      isOnlineExclusive: false,
      rating: 4.8,
      ratingCount: 140
    }];
  }

  // --- 5. CATEGORY GRID EXTRACTOR ---
  function extractProducts() {
    const filename = (filenameInput.value || 'catalog.json').trim();

    if (window.location.pathname.includes('/p/')) {
      const single = extractSinglePdp();
      return { products: single || [], filename: `${slugifyToFilename(getPageCategoryName())}` };
    }

    const products = [];
    const seenIds = new Set();
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
        if (productUrl.startsWith('/')) {
          productUrl = 'https://www.bathandbodyworks.com' + productUrl;
        }

        let pid = card.getAttribute('data-pid') || '';
        if (!pid && productUrl) {
          const match = productUrl.match(/-([0-9]{8,10})(?:\.html|\?|$)/);
          if (match) pid = match[1];
        }
        if (!pid) {
          const btn = card.querySelector('[data-pid]');
          if (btn) pid = btn.getAttribute('data-pid') || '';
        }
        if (!pid || seenIds.has(pid)) return;
        seenIds.add(pid);

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

        products.push({
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
          productUrl: productUrl || `https://www.bathandbodyworks.com/p/${pid}`,
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

    return { products, filename };
  }

  // --- 6. SAME-ORIGIN BATCH NOTE ENRICHER ---
  document.getElementById('pluck-enrich-btn').addEventListener('click', () => {
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

      const parser = new DOMParser();
      let enrichedCount = 0;

      for (let i = 0; i < items.length; i++) {
        const item = items[i];
        const needsNotes = !item.fragranceNotes || item.fragranceNotes.length === 0;
        const needsOverview = !item.fragranceOverview || item.fragranceOverview.trim().length === 0;

        if ((!needsNotes && !needsOverview) || !item.productUrl) continue;

        statusEl.innerText = `✨ Enriching ${i + 1}/${items.length}: ${item.name.slice(0, 22)}...`;

        try {
          const resp = await fetch(item.productUrl, { credentials: 'include' });
          if (resp.ok) {
            const html = await resp.text();
            const doc = parser.parseFromString(html, 'text/html');
            const { overview, notes } = parseFragranceBlock(doc);

            if (overview) item.fragranceOverview = overview;
            if (notes.length > 0) item.fragranceNotes = notes;
            if (overview || notes.length > 0) enrichedCount++;
          }
        } catch (fetchErr) {
          console.warn('PDP enrich skip:', item.productUrl, fetchErr);
        }

        await new Promise((r) => setTimeout(r, 350));
      }

      const blob = new Blob([JSON.stringify(items, null, 2)], { type: 'application/json' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = file.name;
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      URL.revokeObjectURL(url);

      statusEl.innerText = `✅ Enriched ${enrichedCount} items in ${file.name}!`;
    } catch (err) {
      statusEl.innerText = '❌ Failed to parse JSON file';
    }
  });

  // --- DOWNLOAD ACTION ---
  document.getElementById('pluck-extract-btn').addEventListener('click', () => {
    statusEl.innerText = 'Extracting...';
    const { products, filename } = extractProducts();

    if (products.length === 0) {
      statusEl.innerText = '❌ 0 products found. Scroll down first!';
      return;
    }

    const blob = new Blob([JSON.stringify(products, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);

    statusEl.innerText = `✅ Plucked ${products.length} items to ${filename}!`;
  });

  // --- CLIPBOARD ACTION ---
  document.getElementById('pluck-copy-btn').addEventListener('click', async () => {
    statusEl.innerText = 'Copying...';
    const { products, filename } = extractProducts();

    if (products.length === 0) {
      statusEl.innerText = '❌ 0 products found. Scroll down first!';
      return;
    }

    try {
      await navigator.clipboard.writeText(JSON.stringify(products, null, 2));
      statusEl.innerText = `📋 Copied ${products.length} items (${filename})!`;
    } catch (err) {
      statusEl.innerText = '❌ Clipboard copy failed. Use Download instead.';
    }
  });
})();
