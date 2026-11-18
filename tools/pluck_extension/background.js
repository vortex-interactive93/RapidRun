// File: tools/pluck_extension/background.js

chrome.sidePanel
  .setPanelBehavior({ openPanelOnActionClick: true })
  .catch((error) => console.error(error));

chrome.runtime.onMessage.addListener((msg, sender, sendResponse) => {
  if (!msg || (msg.type !== 'HYDRATE_PDP' && msg.type !== 'HYDRATE_ALDI_PDP') || !msg.url) {
    return false;
  }

  const targetCommand =
    msg.type === 'HYDRATE_ALDI_PDP' ? 'READ_LIVE_ALDI_PDP' : 'READ_LIVE_PDP_NOTES';

  let responded = false;
  const safeRespond = (payload) => {
    if (!responded) {
      responded = true;
      try {
        sendResponse(payload);
      } catch (_) {}
    }
  };

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
        }, 8000);
      });

      const result = await chrome.tabs.sendMessage(tabId, { type: targetCommand });
      safeRespond(result || {});
    } catch (err) {
      safeRespond({ error: String(err) });
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
