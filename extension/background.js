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
    port = null; panelOpen = false; sourceTabId = null;
    if (err) { console.error('Floatix host:', err.message); badge('ERR'); }
  });
  port = p;
  return p;
}

async function onHostMessage(msg) {
  if (msg.type === 'ready') badge('');
  else if (msg.type === 'error') console.error('Floatix host error:', msg.message);
  else if (msg.type === 'closed') {
    if (sourceTabId !== null) {
      try {
        await chrome.scripting.executeScript({
          target: { tabId: sourceTabId },
          func: (t) => { const v = window.__floatixSource; if (v) { v.currentTime = t; v.play(); } },
          args: [msg.time],
        });
      } catch (e) { console.warn('Floatix resume gagal:', e.message); } // tab mungkin sudah ditutup
    }
    panelOpen = false; sourceTabId = null;
  }
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
