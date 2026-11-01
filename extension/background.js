const HOST = 'com.dakode.floatix';
let port = null;
let panelOpen = false;
let sourceTabId = null;

const badge = (text) => chrome.action.setBadgeText({ text });

function getPort() {
  if (port) return port;
  const p = chrome.runtime.connectNative(HOST);
  p.onMessage.addListener(onHostMessage);
  p.onDisconnect.addListener(() => {
    const err = chrome.runtime.lastError;
    const tabId = sourceTabId;
    port = null; panelOpen = false; sourceTabId = null;
    resumeTab(tabId, null); // host mati: jangan biarkan video di tab tertahan
    if (err) { console.error('Floatix host:', err.message); badge('ERR'); }
  });
  port = p;
  return p;
}

async function onHostMessage(msg) {
  if (msg.type === 'ready') badge('');
  else if (msg.type === 'error') console.error('Floatix host error:', msg.message);
  else if (msg.type === 'closed') {
    const tabId = sourceTabId;
    panelOpen = false; sourceTabId = null;
    await resumeTab(tabId, msg.time);
  }
}

// Lepas tahanan pause di tab sumber; lanjutkan dari detik t bila ada.
async function resumeTab(tabId, t) {
  if (tabId === null) return;
  try {
    await chrome.scripting.executeScript({
      target: { tabId },
      func: (t) => {
        window.__floatixHold = false;
        const v = window.__floatixSource; if (!v) return;
        if (Number.isFinite(t)) v.currentTime = t;
        v.play().catch(() => {});
      },
      args: [Number.isFinite(t) ? t : null],
    });
  } catch (e) { console.warn('Floatix resume gagal:', e.message); } // tab mungkin sudah ditutup
}

function flash() {
  badge('!');
  setTimeout(() => badge(''), 2000);
}

chrome.action.onClicked.addListener(async (tab) => {
  if (panelOpen) { getPort().postMessage({ type: 'close' }); return; } // tunggu 'closed', jangan putus port
  let msg;
  try {
    const results = await chrome.scripting.executeScript({ target: { tabId: tab.id }, files: ['lib/video.js', 'content.js'] });
    msg = results[0] && results[0].result;
  } catch (e) { flash(); return; }
  if (!msg) { flash(); return; }
  panelOpen = true; sourceTabId = tab.id;
  getPort().postMessage(msg);
});
