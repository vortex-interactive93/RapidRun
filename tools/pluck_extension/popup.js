// File: tools/pluck_extension/popup.js

const storeSelect = document.getElementById('storeSelect');
const filenameInput = document.getElementById('filenameInput');
const pluckAutoScrollBtn = document.getElementById('pluckAutoScrollBtn');
const pluckQuickBtn = document.getElementById('pluckQuickBtn');
const copyJsonBtn = document.getElementById('copyJsonBtn');
const downloadJsonBtn = document.getElementById('downloadJsonBtn');
const enrichNotesBtn = document.getElementById('enrichNotesBtn');
const fileInput = document.getElementById('fileInput');
const statusBox = document.getElementById('status');

async function getActiveTab() {
  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
  return tab;
}

function updateUiForStoreMode(mode) {
  if (enrichNotesBtn) {
    enrichNotesBtn.style.display = 'flex';
    if (mode === 'aldi') {
      enrichNotesBtn.innerText = '✨ ENRICH DETAILS';
    } else {
      enrichNotesBtn.innerText = '✨ ENRICH NOTES';
    }
  }
}

async function refreshPageInfo() {
  try {
    const tab = await getActiveTab();
    if (!tab || !tab.id) return;

    const selectedMode = storeSelect ? storeSelect.value : 'auto';
    const res = await chrome.tabs.sendMessage(tab.id, {
      action: 'GET_PAGE_INFO',
      storeMode: selectedMode
    });

    if (res && res.filename) {
      filenameInput.value = res.filename;
      updateUiForStoreMode(res.activeStoreMode || selectedMode);
      statusBox.innerText = `Detected (${(res.activeStoreMode || selectedMode).toUpperCase()}): "${res.categoryName || 'Catalog'}" (${res.count || 0} items)`;
    }
  } catch (_) {
    statusBox.innerText = 'Navigate to store page to pluck';
  }
}

// Auto-detect page category title & filename on open
refreshPageInfo();

if (storeSelect) {
  storeSelect.addEventListener('change', refreshPageInfo);
}

// 1. Auto-Scroll & Pluck All
pluckAutoScrollBtn.addEventListener('click', async () => {
  const tab = await getActiveTab();
  if (!tab || !tab.id) return;

  statusBox.innerText = '🧲 Auto-scrolling and collecting all products...';
  try {
    const res = await chrome.tabs.sendMessage(tab.id, {
      action: 'PLUCK_AUTOSCROLL',
      filename: filenameInput.value.trim(),
      storeMode: storeSelect ? storeSelect.value : 'auto'
    });
    if (res && res.success) {
      statusBox.innerText = `✅ Captured all ${res.count} products to ${res.filename}!`;
    } else {
      statusBox.innerText = res?.message || '❌ Auto-scroll sweep finished.';
    }
  } catch (e) {
    statusBox.innerText = '❌ Error during auto-scroll sweep.';
  }
});

// 2. Quick Pluck (Visible)
pluckQuickBtn.addEventListener('click', async () => {
  const tab = await getActiveTab();
  if (!tab || !tab.id) return;

  statusBox.innerText = '⚡ Extracting visible cards...';
  try {
    const res = await chrome.tabs.sendMessage(tab.id, {
      action: 'PLUCK_QUICK',
      filename: filenameInput.value.trim(),
      storeMode: storeSelect ? storeSelect.value : 'auto'
    });
    if (res && res.success) {
      statusBox.innerText = `✅ Plucked ${res.count} items to ${res.filename}!`;
    } else {
      statusBox.innerText = res?.message || '❌ No products found.';
    }
  } catch (e) {
    statusBox.innerText = '❌ Error extracting visible items.';
  }
});

// 3. Copy to Clipboard
copyJsonBtn.addEventListener('click', async () => {
  const tab = await getActiveTab();
  if (!tab || !tab.id) return;

  statusBox.innerText = '📋 Copying JSON to clipboard...';
  try {
    const res = await chrome.tabs.sendMessage(tab.id, {
      action: 'COPY_JSON',
      filename: filenameInput.value.trim(),
      storeMode: storeSelect ? storeSelect.value : 'auto'
    });
    if (res && res.success) {
      statusBox.innerText = `📋 Copied ${res.count} items to Clipboard!`;
    } else {
      statusBox.innerText = res?.message || '❌ Copy failed.';
    }
  } catch (e) {
    statusBox.innerText = '❌ Copy error.';
  }
});

// 4. Download JSON
downloadJsonBtn.addEventListener('click', async () => {
  const tab = await getActiveTab();
  if (!tab || !tab.id) return;

  statusBox.innerText = '📄 Downloading JSON...';
  try {
    const res = await chrome.tabs.sendMessage(tab.id, {
      action: 'DOWNLOAD_JSON',
      filename: filenameInput.value.trim(),
      storeMode: storeSelect ? storeSelect.value : 'auto'
    });
    if (res && res.success) {
      statusBox.innerText = `📄 Downloaded ${res.count} items as ${res.filename}!`;
    } else {
      statusBox.innerText = res?.message || '❌ Download failed.';
    }
  } catch (e) {
    statusBox.innerText = '❌ Download error.';
  }
});

// 5. Enrich Notes / Details
if (enrichNotesBtn) {
  enrichNotesBtn.addEventListener('click', () => {
    fileInput.value = '';
    fileInput.click();
  });
}

fileInput.addEventListener('change', async (e) => {
  const file = e.target.files[0];
  if (!file) return;

  try {
    const rawText = await file.text();
    const items = JSON.parse(rawText);
    if (!Array.isArray(items)) {
      statusBox.innerText = '❌ Invalid JSON array file';
      return;
    }

    const tab = await getActiveTab();
    if (!tab || !tab.id) {
      statusBox.innerText = '❌ Open store tab first';
      return;
    }

    const selectedMode = storeSelect ? storeSelect.value : 'auto';
    statusBox.innerText = `✨ Enriching ${items.length} items starting...`;
    chrome.tabs.sendMessage(tab.id, {
      action: 'ENRICH_NOTES',
      items: items,
      fileName: file.name,
      storeMode: selectedMode
    });
  } catch (err) {
    statusBox.innerText = '❌ Failed to parse JSON file';
  }
});

// Listen for status updates from content script during enrichment or auto-scroll
chrome.runtime.onMessage.addListener((msg) => {
  if (msg.type === 'STATUS_UPDATE' && msg.text) {
    statusBox.innerText = msg.text;
  }
});
