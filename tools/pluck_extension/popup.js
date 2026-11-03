// File: tools/pluck_extension/popup.js

let pluckedGridItems = [];
let deepHarvestedItems = [];
let skippedExclusiveCount = 0;
let detectedAisleSlug = 'catalog_items';

const pluckAisleBtn = document.getElementById('pluckAisleBtn');
const deepCrawlBtn = document.getElementById('deepCrawlBtn');
const exportBtn = document.getElementById('exportBtn');
const statusBox = document.getElementById('status');
const progressBox = document.getElementById('progressBox');
const progressFill = document.getElementById('progressFill');
const progressText = document.getElementById('progressText');
const progressPercent = document.getElementById('progressPercent');
const inspectorDeck = document.getElementById('inspectorDeck');
const inspectorList = document.getElementById('inspectorList');
const inspectorCount = document.getElementById('inspectorCount');

function scrapeAisleWithZeroStatic() {
  const headingNode = document.querySelector(
    'h1[data-dan-display="product-list--heading"], h1.page-title, h1.section-title, h1'
  );
  const rawHeading = (headingNode?.innerText || '').trim();

  const rawBreadcrumbs = Array.from(document.querySelectorAll('.breadcrumb-item, .breadcrumbs a, ol.breadcrumb li'))
      .map(el => el.innerText.trim())
      .filter(t => t.length > 0 && !t.toLowerCase().includes('home'));

  const path = window.location.pathname.toLowerCase();
  const lowerHeading = rawHeading.toLowerCase();

  let detectedCategory = 'Body Care';
  let detectedDepartment = rawHeading.length > 0 ? rawHeading : (rawBreadcrumbs[rawBreadcrumbs.length - 1] || 'All Products');

  if (/laundry|detergent|booster|dryer sheet/i.test(lowerHeading) || path.includes('laundry')) {
    detectedCategory = 'Laundry Care';
  } else if (/soap|sanitizer|pocketbac/i.test(lowerHeading) || path.includes('soap') || path.includes('sanitizer')) {
    detectedCategory = 'Hand Soaps & Sanitizers';
  } else if (/candle/i.test(lowerHeading) || path.includes('candle')) {
    detectedCategory = 'Candles';
  } else if (/wallflower|diffuser|room spray|room mist/i.test(lowerHeading) || path.includes('wallflower') || path.includes('room-spray')) {
    detectedCategory = 'Wallflowers & Diffusers';
  } else if (/perfume|cologne|fragrance/i.test(lowerHeading) || path.includes('perfume') || path.includes('cologne')) {
    detectedCategory = 'Fragrance';
  } else if (/body wash|shower gel|body lotion|body cream|scrub|lip/i.test(lowerHeading) || path.includes('body-care')) {
    detectedCategory = 'Body Care';
  }

  const aisleSlug = detectedDepartment
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, '_')
      .replace(/^_+|_+$/g, '');

  const tiles = document.querySelectorAll('[data-component="product-tile"], .product-tile, div[data-pid]');
  const results = [];
  let onlineExclusivesCount = 0;

  tiles.forEach((tile, index) => {
    try {
      const fullTileText = (tile.innerText || '').trim();

      const isOnlineExclusive = /online\s*exclusive/i.test(fullTileText) ||
                                tile.querySelector('[class*="online-exclusive"], [data-badge*="online"]') !== null;
      if (isOnlineExclusive) {
        onlineExclusivesCount++;
        return;
      }

      const dataPid = tile.getAttribute('data-pid');
      const anchorNode = tile.querySelector('a[href*="/p/"]') || tile.closest('a');
      let productUrl = anchorNode ? anchorNode.href : '';
      if (productUrl.startsWith('/')) productUrl = `${window.location.origin}${productUrl}`;

      const urlSkuMatch = productUrl.match(/-([0-9]{7,10})(?:\.html)?$/);
      const sku = dataPid || (urlSkuMatch ? urlSkuMatch[1] : `${Date.now()}_${index}`);

      const dataName = tile.getAttribute('data-item-name');
      const nameNode = tile.querySelector('.product-name, .pdp-link a, [class*="product-name"]');
      const imgNode = tile.querySelector('img');
      const name = (dataName || nameNode?.innerText || imgNode?.getAttribute('alt') || '').trim();
      if (!name || name.length < 2) return;

      const descriptorNode = tile.querySelector(
        '.product-descriptor, .product-subtitle, [class*="descriptor"], .text-secondary:not(.rating-count)'
      );
      let productType = (descriptorNode?.innerText || '').trim();
      const lowerName = name.toLowerCase();

      const isHolderOrAccessory = /holder|pedestal|sleeve|magnet|stand|accessory/i.test(lowerName) ||
                                  /holder|accessory/i.test(productType);

      if (isHolderOrAccessory) {
        productType = 'Candle Holders & Accessories';
      } else if (!productType || productType.length < 2) {
        if (/4-wick/i.test(lowerName)) productType = '4-Wick Candle';
        else if (/single wick/i.test(lowerName)) productType = 'Single Wick Candle';
        else if (/candle/i.test(lowerName)) productType = '3-Wick Candle';
        else if (/booster/i.test(lowerName)) productType = 'Fragrance Booster';
        else if (/detergent/i.test(lowerName)) productType = 'Laundry Detergent';
        else if (/dryer sheet/i.test(lowerName)) productType = 'Dryer Sheets';
        else if (/eau de parfum|perfume/i.test(lowerName)) productType = 'Eau de Parfum';
        else if (/cologne/i.test(lowerName)) productType = 'Cologne';
        else productType = detectedDepartment;
      }

      const priceMatches = fullTileText.match(/\$([0-9]+\.[0-9]{2})/g) || [];
      const allPrices = priceMatches.map(p => parseFloat(p.replace('$', '')));

      let currentPrice = 0.0;
      let regularPrice = 0.0;
      let hasMarkdown = false;

      if (allPrices.length >= 2) {
        currentPrice = Math.min(...allPrices);
        regularPrice = Math.max(...allPrices);
        hasMarkdown = (regularPrice - currentPrice) > 0.05;
      } else if (allPrices.length === 1) {
        currentPrice = allPrices[0];
        regularPrice = allPrices[0];
      }

      let promoBadge = '';
      const promoWrapper = tile.querySelector(
        '.promotional-message, .promotion, [class*="promotional"], .callout-msg, [class*="promo"]'
      );
      if (promoWrapper) {
        const rawPromo = (promoWrapper.innerText || '').replace(/\s+/g, ' ').trim();
        if (rawPromo.length > 2 && !rawPromo.toLowerCase().includes('in-store event')) {
          promoBadge = rawPromo;
        }
      }

      if (!promoBadge) {
        const promoRegex = fullTileText.match(/(?:Mix\s*&\s*Match:?\s*)?(?:\d+\/\$\d+|\bBuy\s*\d+,\s*Get\s*\d+(?:\s*or\s*Buy\s*\d+,\s*Get\s*\d+)*\s*FREE\b)/i);
        if (promoRegex) {
          promoBadge = promoRegex[0].trim();
        }
      }

      let imageUrl = '';
      if (imgNode) {
        imageUrl = imgNode.getAttribute('data-src') || imgNode.getAttribute('srcset')?.split(' ')[0] || imgNode.src || '';
        if (imageUrl.startsWith('//')) imageUrl = 'https:' + imageUrl;
        if (imageUrl.includes('master-catalog')) {
          imageUrl = imageUrl.replace(/sw=[0-9]+/, 'sw=480').replace(/q=[0-9]+/, 'q=75');
        }
      }

      results.push({
        sku: sku,
        id: `bbw_${sku}`,
        name: name,
        brand: 'Bath & Body Works',
        store: 'Bath & Body Works',
        category: detectedCategory,
        department: detectedDepartment,
        subCategory: productType,
        productType: productType,
        regularPrice: regularPrice,
        salePrice: currentPrice,
        price: currentPrice,
        hasSpecial: hasMarkdown || promoBadge.length > 0,
        promoBadge: promoBadge,
        isOnlineExclusive: false,
        unit: '',
        unitShort: '',
        imageUrl: imageUrl,
        productUrl: productUrl,
        fragranceNotes: [],
        fragranceTiers: { top: [], heart: [], base: [] },
        fragranceOverview: '',
        inStock: true,
        rating: 4.8,
        ratingCount: 140
      });
    } catch (e) {
      console.warn('[Pluck Parse Error]:', e);
    }
  });

  return {
    items: results,
    skippedExclusives: onlineExclusivesCount,
    category: detectedCategory,
    department: detectedDepartment,
    aisleSlug: aisleSlug || 'catalog_items'
  };
}

pluckAisleBtn.addEventListener('click', async () => {
  statusBox.className = 'status-box';
  statusBox.innerText = 'Analyzing active department heading & harvesting grid...';
  pluckAisleBtn.disabled = true;

  try {
    const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
    const results = await chrome.scripting.executeScript({
      target: { tabId: tab.id },
      func: scrapeAisleWithZeroStatic
    });

    pluckAisleBtn.disabled = false;
    const payload = results[0]?.result || { items: [], skippedExclusives: 0, aisleSlug: 'catalog_items' };
    pluckedGridItems = payload.items;
    skippedExclusiveCount = payload.skippedExclusives;
    detectedAisleSlug = payload.aisleSlug;

    if (pluckedGridItems.length > 0) {
      statusBox.className = 'status-box success';
      statusBox.innerText = `Ingested ${pluckedGridItems.length} SKUs for "${payload.department}" (${payload.category}) 🛡️`;
      deepCrawlBtn.style.display = 'block';
      deepCrawlBtn.innerText = `💎 DEEP HARVEST ALL (${pluckedGridItems.length})`;
      renderInspectorDeck(pluckedGridItems, false, skippedExclusiveCount);
    } else {
      statusBox.className = 'status-box error';
      statusBox.innerText = 'No in-store products detected.';
    }
  } catch (e) {
    pluckAisleBtn.disabled = false;
    statusBox.className = 'status-box error';
    statusBox.innerText = `Pluck failed: ${e.message}`;
  }
});

deepCrawlBtn.addEventListener('click', async () => {
  if (pluckedGridItems.length === 0) return;

  deepCrawlBtn.disabled = true;
  pluckAisleBtn.disabled = true;
  progressBox.style.display = 'block';
  statusBox.className = 'status-box';
  statusBox.innerText = 'Extracting olfactory pyramid tiers, state tokens & net weights...';

  deepHarvestedItems = [];
  const total = pluckedGridItems.length;
  let completed = 0;

  const poolLimit = 4;
  const queue = [...pluckedGridItems];

  async function crawlWorker() {
    while (queue.length > 0) {
      const item = queue.shift();
      try {
        const response = await fetch(item.productUrl, {
          method: 'GET',
          headers: { 'Accept': 'text/html,application/xhtml+xml' }
        });

        if (response.ok) {
          const html = await response.text();
          const parser = new DOMParser();
          const doc = parser.parseFromString(html, 'text/html');

          // 1. EXTRACT TRUE NET WEIGHT
          const weightNode = doc.querySelector('[data-dan-component="product-size"], [itemprop="weight"], .product-volume');
          if (weightNode) {
            const rawWeight = weightNode.textContent.trim();
            if (rawWeight.length > 1) {
              item.unit = rawWeight;
              if (/sheet/i.test(rawWeight)) {
                item.unitShort = rawWeight;
              } else {
                const shortMatch = rawWeight.match(/([0-9.]+\s*(?:fl\s*oz|oz|sheets|g|mL))/i);
                item.unitShort = shortMatch ? shortMatch[1].replace(/fl\s*/i, '').trim() : rawWeight;
              }
            }
          }

          // 2. EXTRACT PRODUCT DESCRIPTOR
          const typeNode = doc.querySelector('.product-descriptor, .product-subtitle, .emotion-1kyp760');
          if (typeNode && typeNode.textContent.trim().length > 2) {
            const cleanType = typeNode.textContent.trim();
            item.productType = cleanType;
            item.subCategory = cleanType;
          }

          let overview = '';
          const tiers = { top: [], heart: [], base: [] };
          const flatNotes = [];

          // Robust token parser that splits on ' and ' or ' & ' as well as commas
          function addTokensToTier(targetArray, rawString) {
            const cleaned = rawString
              // Remove full note headers
              .replace(/(?:fragrance notes:|notes:)/gi, '')
              // Remove tier labels with or without colon/spaces (e.g. "Top  ", "Top:", "Heart  ", "Base:")
              .replace(/^\s*(?:top|heart|base|mid|dry)\s*[:\-–]?\s*/gi, '')
              .replace(/\b(?:top|heart|base|mid|dry)\s*[:\-–]?\s*/gi, '')
              // Replace ' and ' or ' & ' with ',' so tokens like 'sugar crystals and whipped musk' split cleanly
              .replace(/\s+\band\b\s+/gi, ', ')
              .replace(/\s+&\s+/g, ', ');

            const parts = cleaned
              .split(/,|·|•/)
              .map(s => s.trim()
                .replace(/^[-*"\\]+\s*/, '')
                .replace(/\.$/, '')
                .replace(/^\s*(?:top|heart|base|mid|dry)\s*[:\-–]?\s*/gi, '')
                .trim()
              )
              .filter(s => s.length > 1 && s.length < 40 && !s.toLowerCase().includes('what it smells like'));

            for (const p of parts) {
              if (p && !targetArray.includes(p)) targetArray.push(p);
              if (p && !flatNotes.includes(p)) flatNotes.push(p);
            }
          }

          function parseFragranceBlock(rawText) {
            const lines = rawText.split(/\n+/).map(l => l.trim()).filter(l => l.length > 0);
            for (const line of lines) {
              const lower = line.toLowerCase();
              if (lower.startsWith('top') || lower.includes('top notes:')) {
                addTokensToTier(tiers.top, line);
              } else if (lower.startsWith('heart') || lower.startsWith('mid') || lower.includes('heart notes:')) {
                addTokensToTier(tiers.heart, line);
              } else if (lower.startsWith('base') || lower.startsWith('dry') || lower.includes('base notes:')) {
                addTokensToTier(tiers.base, line);
              } else if (/(?:fragrance notes:|notes:)/i.test(line)) {
                addTokensToTier(flatNotes, line);
              } else if (!overview) {
                const cleanOverview = line
                  .replace(/^what it smells like:\s*/gi, '')
                  .replace(/^fragrance:\s*/gi, '')
                  .trim();
                if (cleanOverview.length > 5 && !cleanOverview.toLowerCase().startsWith('fragrance notes')) {
                  overview = cleanOverview;
                }
              }
            }
          }

          // 3. TARGET EMBEDDED STATE TOKEN (c_fragranceDescription)
          const descMatch = html.match(/"(?:c_)?fragranceDescription"\s*:\s*"([^"]+)"/);
          if (descMatch && descMatch[1]) {
            const unescapedHtml = descMatch[1]
              .replace(/\\u003C/gi, '<')
              .replace(/\\u003E/gi, '>')
              .replace(/\\u002F/gi, '/')
              .replace(/\\n/gi, '\n')
              .replace(/\\"/gi, '"')
              .replace(/<br\s*\/?>/gi, '\n');

            const tempDoc = parser.parseFromString(unescapedHtml, 'text/html');
            const paragraphs = Array.from(tempDoc.querySelectorAll('p, div'))
              .map(p => p.textContent.trim())
              .filter(t => t.length > 0);

            for (const p of paragraphs) {
              parseFragranceBlock(p);
            }
          }

          // 4. FALLBACK: LIVE ACCORDION CONTENT DRAWER
          if (flatNotes.length === 0 || !overview) {
            const fragDrawer = doc.querySelector('#accordion-drawer-fragrance-content, [id*="fragrance-content"], .accordion-drawer__content');
            if (fragDrawer) {
              const blocks = Array.from(fragDrawer.querySelectorAll('p, div'))
                .map(el => {
                  const clone = el.cloneNode(true);
                  clone.querySelectorAll('br').forEach(br => br.replaceWith('\n'));
                  return clone.textContent.trim();
                })
                .filter(t => t.length > 0);

              for (const b of blocks) {
                parseFragranceBlock(b);
              }
            }
          }

          // 5. FALLBACK: STORYTELLING CARDS & FOOTER TAGS
          if (!overview) {
            const headlineNode = doc.querySelector('.card__headline, [class*="card__headline"], [class*="storytelling-headline"]');
            if (headlineNode) overview = headlineNode.textContent.replace(/^"|"$/g, '').trim();
          }

          if (flatNotes.length === 0) {
            const noteNodes = Array.from(doc.querySelectorAll('.card__footer-member li, .card__footer li, span.emotion-vkob47'));
            for (const n of noteNodes) {
              const text = (n.querySelector('span span') || n.querySelector('span') || n).textContent.trim();
              if (text.length > 1 && !text.toLowerCase().includes('what it smells like') && !flatNotes.includes(text)) {
                flatNotes.push(text);
              }
            }
          }

          item.fragranceOverview = overview;

          const lowerOverview = (item.fragranceOverview || '').toLowerCase();
          item.fragranceNotes = Array.from(new Set(flatNotes))
            .map(n => n.replace(/\([^)]*\)/g, '').trim())
            .filter(n => n.length > 0 && n.toLowerCase() !== lowerOverview);

          item.fragranceTiers = {
            top: tiers.top.filter(n => n.toLowerCase() !== lowerOverview),
            heart: tiers.heart.filter(n => n.toLowerCase() !== lowerOverview),
            base: tiers.base.filter(n => n.toLowerCase() !== lowerOverview)
          };

          // Also construct fragranceProfile for hybrid model compatibility
          if (item.fragranceTiers.top.length > 0 || item.fragranceTiers.heart.length > 0 || item.fragranceTiers.base.length > 0) {
            item.fragranceProfile = {
              family: item.category || 'Fragrance',
              topNotes: item.fragranceTiers.top,
              heartNotes: item.fragranceTiers.heart,
              baseNotes: item.fragranceTiers.base
            };
          }

          // 6. HARDWARE & ACCESSORIES
          if (/holder|pedestal|accessory|plug/i.test(item.productType) || /holder|pedestal|plug/i.test(item.name)) {
            const benefitsText = doc.querySelector('.emotion-1f9p720, [class*="benefits"], [class*="description"]')?.textContent || '';
            const dimMatch = benefitsText.match(/Measures\s*([0-9."\sLWHDx]+)/i);
            if (dimMatch) {
              item.unit = dimMatch[0].trim();
              item.unitShort = item.productType.includes('Plug') ? 'Plug' : 'Pedestal';
            } else if (!item.unit || item.unit.length === 0) {
              item.unit = '1 pc';
              item.unitShort = item.productType.includes('Plug') ? 'Plug' : 'Accessory';
            }
            if (!item.fragranceOverview || item.fragranceOverview.length === 0) {
              item.fragranceOverview = item.productType.includes('Plug')
                  ? "Compatible with Bath & Body Works Wallflowers fragrance refills (sold separately)."
                  : "Compatible with Bath & Body Works 3-wick candles (sold separately).";
            }
            item.fragranceNotes = [];
            item.fragranceTiers = { top: [], heart: [], base: [] };
            delete item.fragranceProfile;
          }
        }
      } catch (err) {
        console.warn(`[Pluck Crawler Error]:`, err);
      } finally {
        completed++;
        deepHarvestedItems.push(item);

        const pct = Math.round((completed / total) * 100);
        progressFill.style.width = `${pct}%`;
        progressPercent.innerText = `${pct}%`;
        progressText.innerText = `Harvested ${completed} / ${total} products...`;

        await new Promise(r => setTimeout(r, 100));
      }
    }
  }

  const workers = Array.from({ length: poolLimit }, () => crawlWorker());
  await Promise.all(workers);

  progressBox.style.display = 'none';
  deepCrawlBtn.disabled = false;
  pluckAisleBtn.disabled = false;
  statusBox.className = 'status-box success';
  statusBox.innerText = `Deep Harvester complete! Clean scent pyramid tiers & specs indexed.`;

  renderInspectorDeck(deepHarvestedItems, true, skippedExclusiveCount);
});

// Dynamic Export Button: Readable Formatted JSON (null, 2)
exportBtn.addEventListener('click', () => {
  const exportData = deepHarvestedItems.length > 0 ? deepHarvestedItems : pluckedGridItems;
  if (exportData.length === 0) return;

  const formattedPayload = JSON.stringify(exportData, null, 2);
  const blob = new Blob([formattedPayload], { type: 'application/json' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = `${detectedAisleSlug}.json`;
  a.click();
  URL.revokeObjectURL(url);
});

function renderInspectorDeck(items, isDeep, skipped) {
  inspectorDeck.style.display = 'block';
  inspectorCount.innerText = `${items.length} IN-STORE SKUS`;
  inspectorList.innerHTML = '';

  items.forEach(item => {
    const row = document.createElement('div');
    row.className = 'item-row';

    let notesHtml = '';
    const hasTiers = item.fragranceTiers && (item.fragranceTiers.top.length > 0 || item.fragranceTiers.heart.length > 0 || item.fragranceTiers.base.length > 0);

    if (hasTiers) {
      notesHtml = `<div class="notes-preview">
        ${item.fragranceTiers.top.map(n => `<span class="note-chip gold">▲ Top: ${n}</span>`).join('')}
        ${item.fragranceTiers.heart.map(n => `<span class="note-chip amber">◆ Heart: ${n}</span>`).join('')}
        ${item.fragranceTiers.base.map(n => `<span class="note-chip bronze">▼ Base: ${n}</span>`).join('')}
      </div>`;
    } else if (item.fragranceNotes && item.fragranceNotes.length > 0) {
      notesHtml = `<div class="notes-preview">
        ${item.fragranceNotes.map(n => `<span class="note-chip">✨ ${n}</span>`).join('')}
      </div>`;
    }

    row.innerHTML = `
      <div class="item-row-top">
        <img class="item-thumb" src="${item.imageUrl}" alt="" />
        <div class="item-details">
          <div class="item-title">${item.name}</div>
          <div class="item-pricing">
            <span class="sale-price">$${item.salePrice.toFixed(2)}</span>
            ${item.regularPrice > item.salePrice ? `<span class="reg-price">$${item.regularPrice.toFixed(2)}</span>` : ''}
            <span style="color:#E5A93C; font-size:9.5px; font-weight:800; margin-left:auto;">${item.productType} • ${item.unitShort}</span>
          </div>
        </div>
      </div>
      ${notesHtml}
    `;

    row.addEventListener('click', () => {
      chrome.tabs.create({ url: item.productUrl, active: false });
    });

    inspectorList.appendChild(row);
  });

  exportBtn.innerText = `📄 DOWNLOAD ${detectedAisleSlug.toUpperCase()}.JSON`;
  exportBtn.style.display = 'block';
}
