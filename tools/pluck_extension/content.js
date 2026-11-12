// File: tools/pluck_extension/content.js

(function () {
  if (document.getElementById('pluck-hud-root')) return;

  // --- 1. DYNAMIC CATEGORY TITLE & SLUG ENGINE ---
  function getPageCategoryName() {
    // Stable semantic selector from DevTools audit
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

    // Map common subcategories to our primary Boutique rooms if matching
    if (clean.includes('candle')) return 'candles.json';
    if (clean.includes('wallflower') || clean.includes('diffuser')) return 'wallflowers_diffusers.json';
    if (clean.includes('fragrance') && !clean.includes('home')) return 'all_fragrance.json';
    if (clean.includes('soap') || clean.includes('sanitizer')) return 'hand_soaps_sanitizers.json';
    if (clean.includes('men')) return 'mens_shop.json';
    if (clean.includes('home') || clean.includes('laundry')) return 'home_care.json';

    return `${clean}.json`;
  }

  const initialTitle = getPageCategoryName();
  const initialFilename = slugifyToFilename(initialTitle);

  // --- 2. INJECT STREAMLINED HUD ---
  const hud = document.createElement('div');
  hud.id = 'pluck-hud-root';
  hud.innerHTML = `
    <div id="pluck-hud">
      <div id="pluck-hud-header">
        <div class="pluck-title-row">
          <span class="pluck-icon">⚡</span>
          <span class="pluck-title">Pluck Exporter</span>
        </div>
        <button id="pluck-refresh-btn" title="Refresh & Rescan Page">🔄 Rescan</button>
      </div>

      <div class="pluck-field-group">
        <label for="pluck-filename-input" class="pluck-label">Output Filename:</label>
        <input type="text" id="pluck-filename-input" value="${initialFilename}" spellcheck="false" />
      </div>

      <button id="pluck-extract-btn" class="pluck-primary-btn">⚡ Extract & Download JSON</button>
      <button id="pluck-copy-btn" class="pluck-secondary-btn">📋 Copy to Clipboard</button>
      <div id="pluck-status">Ready to pluck</div>
    </div>
  `;
  document.body.appendChild(hud);

  const filenameInput = document.getElementById('pluck-filename-input');
  const statusEl = document.getElementById('pluck-status');

  // --- 3. LIVE RESCAN / REFRESH ---
  function rescanPage() {
    const title = getPageCategoryName();
    const newFilename = slugifyToFilename(title);
    filenameInput.value = newFilename;

    const cards = document.querySelectorAll('.product-tile, .product, .grid-tile, [data-pid]');
    const count = Array.from(cards).filter(el => !el.matches('button, a, input, select')).length;

    statusEl.innerText = `🔄 Detected: "${title || 'Catalog'}" (${count} items)`;
  }

  document.getElementById('pluck-refresh-btn').addEventListener('click', rescanPage);
  window.addEventListener('popstate', rescanPage);

  // --- 4. OLFACTORY REFERENCE VAULT ---
  const SCENT_VAULT = {
    'santal ridge': {
      notes: ['bergamot zest', 'crisp aromatics', 'fresh fig leaf', 'Anjou pear', 'sheer iris', 'blue jasmine', 'ambrette essence', 'wild moss', 'silver amber', 'rich sandalwood', 'Caribbean juniperwood', 'clean skin musks'],
      overview: 'An untamed exploration of citrus, woods and moss with a deeply grounding, adventurous edge.',
      tiers: {
        top: ['bergamot zest', 'crisp aromatics', 'fresh fig leaf', 'Anjou pear'],
        heart: ['sheer iris', 'blue jasmine', 'ambrette essence', 'wild moss'],
        base: ['silver amber', 'rich sandalwood', 'Caribbean juniperwood', 'clean skin musks']
      }
    },
    'ocean': {
      notes: ['bergamot', 'yuzu', 'artemisia', 'elemi', 'watermelon', 'lavandin', 'nutmeg', 'cypress', 'iris', 'cedarwood', 'patchouli', 'vetiver', 'olibanum'],
      overview: 'Refreshing, vital and confident. A blend of watery marine notes and woods inspired by the freedom and energy of the coast.',
      tiers: {
        top: ['bergamot', 'yuzu', 'artemisia', 'elemi', 'watermelon'],
        heart: ['lavandin', 'nutmeg', 'cypress'],
        base: ['iris', 'cedarwood', 'patchouli', 'vetiver', 'olibanum']
      }
    },
    'noir': {
      notes: ['black cardamom', 'smoky vanilla', 'a hint of musk'],
      overview: 'Dark, mysterious and endlessly warm. Bold, toasted spices seamlessly blend with sweet embers and a rich finish.',
      tiers: { top: ['black cardamom'], heart: ['smoky vanilla'], base: ['warm musk'] }
    },
    'bourbon': {
      notes: ['white pepper', 'dark amber', 'Kentucky oak'],
      overview: "Bold, smooth and just so classic, this barrel-aged pour's always a solid choice.",
      tiers: { top: ['white pepper'], heart: ['dark amber'], base: ['Kentucky oak'] }
    },
    'graphite': {
      notes: ['sage', 'bergamot spice', 'leather woods'],
      overview: 'Fresh earthy greens meet warm citrus pepper and a rugged timber finish. Bold, grounded and undeniably refined.',
      tiers: { top: ['bergamot spice'], heart: ['sage'], base: ['leather woods'] }
    },
    'after dark': {
      notes: ['spiced bergamot', 'amber', 'smooth tonka'],
      overview: 'Bright, bold and effortlessly smooth with warm notes that linger into the night.',
      tiers: { top: ['spiced bergamot'], heart: ['amber'], base: ['smooth tonka'] }
    },
    'into orbit': {
      notes: ['warm musk', 'vetiver', 'night florals'],
      overview: 'An inviting blend of masculine warmth, earthy depth and intriguing florals.',
      tiers: { top: ['night florals'], heart: ['vetiver'], base: ['warm musk'] }
    },
    'lasting legacy': {
      notes: ['fresh citrus', 'amber', 'smooth vanilla'],
      overview: 'Effortless. Intriguing. Enduring. Lively citrus and down-to-earth amber with a creamy sweet finish.',
      tiers: { top: ['fresh citrus'], heart: ['amber'], base: ['smooth tonka'] }
    },
    'crafted cognac': {
      notes: ['orange bitters', 'cherry brandy', 'warm tonka'],
      overview: 'Handcrafted with a twist of orange, a shot of cherry brandy and a dash of warm tonka.',
      tiers: { top: ['orange bitters'], heart: ['cherry brandy'], base: ['warm tonka'] }
    },
    'freshwater': {
      notes: ['Italian bergamot', 'mountain spring water', 'oak moss'],
      overview: "Bright, refreshing, earthy. Dive right in, the water's great.",
      tiers: { top: ['Italian bergamot'], heart: ['mountain spring water'], base: ['oak moss'] }
    },
    'into the night': {
      notes: ['pink pomelo', 'dewberry', 'black raspberry sugar', 'Turkish rose petals', 'jasmine sambac', 'patchouli', 'vanilla bean', 'mocha', 'amber', 'musk'],
      overview: 'Glamorous with a modern, feminine signature. A woody amber chypre with a sensual blend of dark berries, sweeping florals and rich woods.',
      tiers: {
        top: ['pink pomelo', 'dewberry', 'black raspberry sugar'],
        heart: ['Turkish rose petals', 'jasmine sambac'],
        base: ['patchouli', 'vanilla bean', 'mocha', 'amber', 'musk']
      }
    },
    'in the stars': {
      notes: ['sugared tangelo', 'pink currant', 'starflower', 'apricot blossom', 'jasmine absolute', 'sandalwood', 'white musk', 'white agarwood', 'amber', 'moss'],
      overview: 'A fusion of sparkling highs and sophisticated depths, this uniquely brings its woody notes to the foreground.',
      tiers: {
        top: ['sugared tangelo', 'pink currant'],
        heart: ['starflower', 'apricot blossom', 'jasmine absolute'],
        base: ['sandalwood', 'white musk', 'white agarwood', 'amber', 'moss']
      }
    },
    'japanese cherry blossom': {
      notes: ['crisp pear', 'apple', 'ume plum', 'Japanese cherry blossom', 'white jasmine', 'butterfly lily', 'Kyoto rose', 'mimosa petals', 'rice milk', 'amber', 'silk musk', 'creamy sandalwood'],
      overview: 'Feminine, floral, elegant and timelessly appealing. Soft cherry blossoms with crisp pear and dewy white jasmine buds.',
      tiers: {
        top: ['crisp pear', 'apple', 'ume plum'],
        heart: ['Japanese cherry blossom', 'white jasmine', 'butterfly lily', 'Kyoto rose', 'mimosa petals'],
        base: ['rice milk', 'amber', 'silk musk', 'creamy sandalwood']
      }
    },
    'a thousand wishes': {
      notes: ['pink prosecco', 'starfruit', 'golden quince', 'crystal peonies', 'purple freesia', 'gilded amber', 'amaretto crème', 'sugared sandalwood', 'velvet musk', 'patchouli'],
      overview: 'Enter a world of endless possibilities. Shimmering prosecco, swirling fruit, florals and creamy amaretto.',
      tiers: {
        top: ['pink prosecco', 'starfruit', 'golden quince'],
        heart: ['crystal peonies', 'purple freesia'],
        base: ['gilded amber', 'amaretto crème', 'sugared sandalwood', 'velvet musk', 'patchouli']
      }
    },
    'champagne toast': {
      notes: ['Kir royale', 'vintage Champagne', 'sparkling tangerine', 'juicy passionfruit', 'dark plum', 'white nectarine', 'black currant', 'warm woods', 'sugared musk', 'vanilla extract'],
      overview: 'With the effervescence of Champagne, ripe berries and sweet tangerine, it is the feeling of being exactly where you are meant to be.',
      tiers: {
        top: ['Kir royale', 'vintage Champagne', 'sparkling tangerine', 'juicy passionfruit'],
        heart: ['dark plum', 'white nectarine', 'black currant'],
        base: ['warm woods', 'sugared musk', 'vanilla extract']
      }
    },
    'warm vanilla sugar': {
      notes: ['sheer muguet', 'coconut milk', 'white orchid', 'jasmine', 'vanilla absolute', 'warm musk', 'sugar crystals', 'sandalwood'],
      overview: 'Addictive by nature. Refined by design. A balance of gourmand comfort and all-day wearable elegance.',
      tiers: {
        top: ['sheer muguet'],
        heart: ['coconut milk', 'white orchid', 'jasmine'],
        base: ['vanilla absolute', 'warm musk', 'sugar crystals', 'sandalwood']
      }
    },
    'mahogany teakwood': {
      notes: ['juniper berry', 'bergamot', 'crisp wind accord', 'marine accord', 'red berries', 'cypress leaves', 'clary sage', 'fresh lavender', 'frosted twigs accord', 'creamy sandalwood', 'driftwood', 'rich mahogany wood accord', 'black teakwood accord'],
      overview: 'Warm, distinctive and enduring. Deep mahogany and solid black teakwood with a dash of lavender.',
      tiers: {
        top: ['juniper berry', 'bergamot', 'crisp wind accord', 'marine accord'],
        heart: ['red berries', 'cypress leaves', 'clary sage', 'fresh lavender', 'frosted twigs accord'],
        base: ['creamy sandalwood', 'driftwood', 'rich mahogany wood accord', 'black teakwood accord']
      }
    },
    'fresh balsam': {
      notes: ['woodland balsam', 'crisp eucalyptus', 'fir branches', 'cedarwood'],
      overview: 'As cool, fresh and rejuvenating as an early November walk through the woods.',
      tiers: { top: ['crisp eucalyptus'], heart: ['fir branches'], base: ['woodland balsam', 'cedarwood'] }
    },
    'vanilla bean noel': {
      notes: ['vanilla', 'sweet buttery accord', 'caramel', 'benzoin', 'hint of chocolate', 'soft musk', 'sugar cookie'],
      overview: 'Sweet, creamy and every bit as irresistible as you remember. A beloved holiday cookie-inspired fragrance.',
      tiers: {
        top: ['vanilla', 'sweet buttery accord'],
        heart: ['caramel', 'benzoin', 'hint of chocolate'],
        base: ['soft musk', 'sugar cookie']
      }
    },
    'twisted peppermint': {
      notes: ['sweet peppermint', 'raspberry', 'sheer jasmine', 'candy floss', 'mint', 'musk'],
      overview: 'A peppermint-striped holiday treat wrapped in frosty freshness and tucked among twinkling lights.',
      tiers: {
        top: ['sweet peppermint'],
        heart: ['peppermint', 'raspberry', 'sheer jasmine'],
        base: ['candy floss', 'mint', 'musk']
      }
    },
    'winter candy apple': {
      notes: ['juicy Granny Smith apple', 'sweet orange', 'candied red berries', 'delicate lily of the valley', 'sugared cinnamon bark', 'soft iris', 'golden cedarwood', 'frosted musk', 'oakmoss'],
      overview: 'Cheerful, fruity and as bright as the season itself, a Christmas classic for a reason.',
      tiers: {
        top: ['juicy Granny Smith apple', 'sweet orange', 'candied red berries'],
        heart: ['delicate lily of the valley', 'sugared cinnamon bark', 'soft iris'],
        base: ['golden cedarwood', 'frosted musk', 'oakmoss']
      }
    },
    'snowflakes & cashmere': {
      notes: ['vanilla cashmere cream', 'caramel woods', 'frosted clementine'],
      overview: 'Creamy, warm vanilla blends with refreshing citrus notes for an oh-so-snuggly scent.',
      tiers: { top: ['frosted clementine'], heart: ['vanilla cashmere cream'], base: ['caramel woods'] }
    },
    'strawberry pound cake': {
      notes: ['fresh strawberries', 'golden shortcake', 'whipped cream'],
      overview: 'Sweet, light and creamy, it is that classic dessert you just cannot get enough of.',
      tiers: { top: ['fresh strawberries'], heart: ['golden shortcake'], base: ['whipped cream'] }
    }
  };

  // --- 5. EXTRACTION CORE ---
  function extractProducts() {
    const filename = (filenameInput.value || 'catalog.json').trim();
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
      candidateCards = Array.from(document.querySelectorAll('[data-pid]')).filter((el) => {
        return !el.matches('button, a, input, select');
      });
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
        if (!pid) return;

        if (seenIds.has(pid)) return;
        seenIds.add(pid);

        // Name Extraction
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
        const nameLower = name.toLowerCase();

        // Image URL
        let imageUrl = '';
        if (imgEl) {
          imageUrl = imgEl.getAttribute('data-src') || imgEl.getAttribute('src') || '';
          if (imageUrl.startsWith('//')) imageUrl = 'https:' + imageUrl;
        }

        // Pricing
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

        // Promo Badges
        let promoBadge = '';
        const lines = cardText.split('\n').map((l) => l.trim()).filter((l) => l.length > 0);
        for (const line of lines) {
          const lineUpper = line.toUpperCase();
          if (
            lineUpper.includes('MIX & MATCH') ||
            lineUpper.includes('BUY 3, GET 3') ||
            lineUpper.includes('BUY 2, GET 1') ||
            lineUpper.includes('BUY 3, GET 1') ||
            lineUpper.includes('FREE') ||
            /\b\d+\/\$\d+\b/.test(lineUpper)
          ) {
            promoBadge = line.replace(/\s+/g, ' ');
            break;
          }
        }
        const hasSpecial = promoBadge.length > 0 || salePrice < regularPrice;

        // Unit Deduction
        let unit = '';
        let unitShort = '';
        const unitMatch = name.match(/([0-9.]+\s*(?:fl\s*oz|oz|mL|g|sheets|wicks?))/i);
        if (unitMatch) {
          unit = unitMatch[1].trim();
          unitShort = unit.replace(/fl\s*/i, '').trim();
        } else if (nameLower.includes('travel size') || nameLower.includes('mini')) {
          unit = '2.5 fl oz / 75 ml';
          unitShort = '2.5 oz';
        } else if (nameLower.includes('hand cream')) {
          unit = '1 fl oz / 29 ml';
          unitShort = '1 oz';
        } else if (nameLower.includes('hand mask')) {
          unit = '1 Pair';
          unitShort = '1 Pair';
        } else if (nameLower.includes('3-wick')) {
          unit = '14.5 oz / 411 g';
          unitShort = '14.5 oz';
        } else if (nameLower.includes('single wick')) {
          unit = '8 oz / 227 g';
          unitShort = '8 oz';
        } else if (nameLower.includes('fine fragrance mist') || nameLower.includes('perfume mist')) {
          unit = '8 fl oz / 236 ml';
          unitShort = '8 oz';
        } else if (nameLower.includes('deodorizing body spray')) {
          unit = '3.7 oz / 104 g';
          unitShort = '3.7 oz';
        } else if (nameLower.includes('foaming hand soap')) {
          unit = '8.75 fl oz / 259 ml';
          unitShort = '8.75 oz';
        } else if (nameLower.includes('pocketbac')) {
          unit = '1 fl oz / 29 ml';
          unitShort = '1 oz';
        } else if (nameLower.includes('3-in-1') || nameLower.includes('body wash')) {
          unit = '10 fl oz / 295 ml';
          unitShort = '10 oz';
        } else if (nameLower.includes('body cream') || nameLower.includes('body lotion')) {
          unit = '8 oz / 226 g';
          unitShort = '8 oz';
        } else if (nameLower.includes('wallflowers fragrance refill')) {
          unit = '0.8 fl oz / 24 ml';
          unitShort = '0.8 oz';
        } else {
          unit = 'Standard';
          unitShort = 'Item';
        }

        // Fragrance Notes & Vault
        let fragranceNotes = [];
        let fragranceOverview = '';
        let fragranceTiers = { top: [], heart: [], base: [] };

        const notesEl = card.querySelector('.fragrance-notes, .scent-notes, [class*="fragrance"]');
        if (notesEl) {
          fragranceNotes = notesEl.innerText
            .split(/[,•\n]+/)
            .map((n) => n.replace(/^note:\s*/i, '').trim())
            .filter((n) => n.length > 0);
        }

        for (const [key, profile] of Object.entries(SCENT_VAULT)) {
          if (nameLower.includes(key)) {
            if (fragranceNotes.length === 0) fragranceNotes = [...profile.notes];
            if (!fragranceOverview) fragranceOverview = profile.overview;
            if (fragranceTiers.top.length === 0) fragranceTiers = profile.tiers;
            break;
          }
        }

        if (fragranceNotes.length === 0) {
          ['vanilla', 'eucalyptus', 'peppermint', 'balsam', 'mahogany', 'lavender', 'apple', 'peach', 'rose', 'spearmint', 'amber', 'sandalwood', 'citrus'].forEach((k) => {
            if (nameLower.includes(k)) fragranceNotes.push(k);
          });
        }

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
          unit: unit,
          unitShort: unitShort,
          fragranceNotes: fragranceNotes,
          fragranceOverview: fragranceOverview,
          fragranceTiers: fragranceTiers,
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
    } catch (e) {
      statusEl.innerText = '❌ Clipboard copy failed. Use Download instead.';
    }
  });
})();
