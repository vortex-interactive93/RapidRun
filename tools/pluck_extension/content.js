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

  function splitNotesString(rawNotes) {
    return rawNotes
      .replace(/^(?:fragrance\s+)?notes\s*:\s*/i, '')
      .replace(/\.+$/, '')
      .split(/,\s*|\s*•\s*/)
      .map((n) => n.replace(/^note:\s*/i, '').replace(/\.+$/, '').trim())
      .filter((n) => n.length > 1 && n.length < 60);
  }

  // --- 2. 3-LAYER FRAGRANCE EXTRACTOR (DOM + SIBLING SCAN + RAW NEXT.JS HTML) ---
  function extractFragranceFromPdp(doc, rawHtml = '') {
    let overview = '';
    let notes = [];

    // LAYER 1: Semantic Fragrance Accordion & DevTools Emotion Container
    const accordionContainer =
      doc.querySelector('[id*="content:fragrance"] .emotion-16zqzjt') ||
      doc.querySelector('[id*="content:fragrance"]') ||
      doc.querySelector('[id*="item:fragrance"]') ||
      doc.querySelector('.emotion-16zqzjt');

    if (accordionContainer) {
      const paragraphs = Array.from(accordionContainer.querySelectorAll('p'))
        .map((p) => p.textContent.replace(/\s+/g, ' ').trim())
        .filter((t) => t.length > 0);

      for (const text of paragraphs) {
        if (/^(?:fragrance\s+)?notes\s*:/i.test(text)) {
          notes = splitNotesString(text);
        } else if (!overview && text.length > 10 && !/^(what it smells like|why you'll love it)/i.test(text)) {
          overview = text;
        }
      }
    }

    // LAYER 2: Full-Document Paragraph Scan (Immune to Accordion ID / Emotion Class Changes)
    if (notes.length === 0) {
      const allParagraphs = Array.from(doc.querySelectorAll('p, div, li'));
      for (const el of allParagraphs) {
        if (el.children.length > 2) continue;
        const text = el.textContent.replace(/\s+/g, ' ').trim();
        if (/^(?:fragrance\s+)?notes\s*:\s*.+/i.test(text) && text.length < 350) {
          notes = splitNotesString(text);

          if (!overview && el.previousElementSibling) {
            const prevText = el.previousElementSibling.textContent.replace(/\s+/g, ' ').trim();
            if (prevText.length > 12 && prevText.length < 500) {
              overview = prevText;
            }
          }
          if (notes.length > 0) break;
        }
      }
    }

    // LAYER 3: Raw HTML / Next.js RSC Flight Payload Fallback
    if (notes.length === 0 && rawHtml) {
      const normalizedHtml = rawHtml
        .replace(/\\"/g, '"')
        .replace(/\\u0026/g, '&')
        .replace(/'/g, "'")
        .replace(/"/g, '"');

      const notesMatch = normalizedHtml.match(/(?:Fragrance\s+)?Notes\s*:\s*([^<>"\\]{4,280})/i);
      if (notesMatch && notesMatch[1]) {
        notes = splitNotesString(notesMatch[1]);
      }

      if (!overview && notesMatch && notesMatch.index > 30) {
        const precedingChunk = normalizedHtml.slice(Math.max(0, notesMatch.index - 450), notesMatch.index);
        const pMatches = [...precedingChunk.matchAll(/>([^<>]{18,380})</g)];
        if (pMatches.length > 0) {
          const candidate = pMatches[pMatches.length - 1][1].replace(/\s+/g, ' ').trim();
          if (!/^(fragrance|benefits|ingredients|how to use)/i.test(candidate)) {
            overview = candidate;
          }
        }
      }
    }

    return { overview, notes };
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
          <span class="pluck-title">Pluck 2.5</span>
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
      const parsed = extractFragranceFromPdp(document, document.documentElement.innerHTML);
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
    const { overview, notes } = extractFragranceFromPdp(document, document.documentElement.innerHTML);

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
      return { products: single || [], filename: slugifyToFilename(getPageCategoryName()) };
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
          productUrl = window.location.origin + productUrl;
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

    return { products, filename };
  }

  // --- 6. SAME-ORIGIN BATCH NOTE ENRICHER WITH RETRY & DIAGNOSTICS ---
  document.getElementById('pluck-enrich-btn').addEventListener('click', () => {
    fileInput.value = '';
    fileInput.click();
  });

  async function fetchPdpWithRetry(rawUrl) {
    const parsedUrl = new URL(rawUrl, window.location.origin);
    const sameOriginUrl = window.location.origin + parsedUrl.pathname + parsedUrl.search;

    for (let attempt = 1; attempt <= 2; attempt++) {
      try {
        const resp = await fetch(sameOriginUrl, {
          credentials: 'include',
          headers: { Accept: 'text/html,application/xhtml+xml' }
        });
        if (resp.ok) {
          return await resp.text();
        }
        console.warn(`[Pluck] HTTP ${resp.status} for ${sameOriginUrl} (attempt ${attempt})`);
      } catch (err) {
        console.warn(`[Pluck] Fetch error for ${sameOriginUrl} (attempt ${attempt}):`, err);
      }
      await new Promise((r) => setTimeout(r, 900 * attempt));
    }
    return null;
  }

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
      let skippedHardware = 0;
      const stillMissing = [];

      for (let i = 0; i < items.length; i++) {
        const item = items[i];
        if (isUnscentedHardware(item.name)) {
          skippedHardware++;
          continue;
        }

        const needsOverview = !item.fragranceOverview || item.fragranceOverview.trim().length === 0;
        const needsNotes = !item.fragranceNotes || item.fragranceNotes.length <= 1;

        if ((!needsOverview && !needsNotes) || !item.productUrl) continue;

        statusEl.innerText = `✨ (${i + 1}/${items.length}) ${item.name.slice(0, 22)}...`;

        const html = await fetchPdpWithRetry(item.productUrl);
        if (html) {
          const doc = parser.parseFromString(html, 'text/html');
          const { overview, notes } = extractFragranceFromPdp(doc, html);

          if (overview) item.fragranceOverview = overview;
          if (notes.length > 0) item.fragranceNotes = notes;

          if (overview || notes.length > 0) {
            enrichedCount++;
          } else {
            stillMissing.push(item.name);
          }
        } else {
          stillMissing.push(`${item.name} (fetch failed)`);
        }

        await new Promise((r) => setTimeout(r, 550));
      }

      if (stillMissing.length > 0) {
        console.log('⚠️ [Pluck] Items without fragrance block on PDP:', stillMissing);
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

      statusEl.innerText = `✅ Enriched ${enrichedCount} items! (${skippedHardware} holders skipped)`;
    } catch (err) {
      statusEl.innerText = '❌ Failed to parse JSON file';
    }
  });

  // --- DOWNLOAD & CLIPBOARD ACTIONS ---
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
