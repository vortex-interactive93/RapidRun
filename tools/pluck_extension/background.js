// File: tools/pluck_extension/background.js

chrome.runtime.onMessage.addListener((msg, sender, sendResponse) => {
  if (msg.type !== 'HYDRATE_PDP' || !msg.url) return false;

  (async () => {
    let tabId = null;
    try {
      // Open an inactive background tab so your active window never loses focus
      const tab = await chrome.tabs.create({ url: msg.url, active: false });
      tabId = tab.id;

      // Wait for initial page load
      await new Promise((resolve) => {
        const listener = (updatedId, info) => {
          if (updatedId === tabId && info.status === 'complete') {
            chrome.tabs.onUpdated.removeListener(listener);
            resolve();
          }
        };
        chrome.tabs.onUpdated.addListener(listener);
        setTimeout(() => {
          chrome.tabs.onUpdated.removeListener(listener);
          resolve();
        }, 7000);
      });

      // Give React 1.4s to replace wick-skeleton with [id*="content:fragrance"]
      await new Promise((r) => setTimeout(r, 1400));

      // Ask the content script inside that hydrated tab to read the live DOM
      const result = await chrome.tabs.sendMessage(tabId, { type: 'READ_LIVE_PDP_NOTES' });
      sendResponse(result || { overview: '', notes: [] });
    } catch (err) {
      sendResponse({ overview: '', notes: [], error: String(err) });
    } finally {
      if (tabId !== null) {
        try {
          await chrome.tabs.remove(tabId);
        } catch (_) {}
      }
    }
  })();

  return true; // Keep message channel open for async response
});
