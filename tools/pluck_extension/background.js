// File: tools/pluck_extension/background.js

chrome.sidePanel
  .setPanelBehavior({ openPanelOnActionClick: true })
  .catch((error) => console.error(error));

chrome.runtime.onMessage.addListener((msg, sender, sendResponse) => {
  if (msg.type !== 'HYDRATE_PDP' || !msg.url) return false;

  (async () => {
    let tabId = null;
    try {
      const tab = await chrome.tabs.create({ url: msg.url, active: false });
      tabId = tab.id;

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

      await new Promise((r) => setTimeout(r, 1400));

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

  return true;
});
