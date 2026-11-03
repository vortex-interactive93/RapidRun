// File: tools/pluck_extension/background.js

// Enables the side panel to open on action toolbar click
chrome.sidePanel
  .setPanelBehavior({ openPanelOnActionClick: true })
  .catch((error) => console.error('[Pluck Background] Error setting side panel behavior:', error));

// Keep service worker active during long crawls
chrome.runtime.onInstalled.addListener(() => {
  console.log('⚡ Pluck Catalog Engine 2.0 (Side Panel Edition) Installed.');
});
