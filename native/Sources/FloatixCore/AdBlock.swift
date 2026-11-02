import Foundation

/// Scriptlet ala Brave Shields/uBlock ("json-prune") untuk YouTube, disuntik di awal halaman.
/// Iklan video YouTube datang dari server YouTube sendiri, jadi tidak bisa diblokir per alamat.
/// Yang dibuang adalah jadwal iklan di respons player, supaya player tidak pernah meminta iklan.
/// shortcut: daftar kunci mengikuti struktur YouTube sekarang; perbarui bila iklan muncul lagi.
public let adBlockScript = #"""
(() => {
  const KEYS = ['adPlacements', 'playerAds', 'adSlots', 'adBreakHeartbeatParams'];
  const strip = (o) => {
    if (!o || typeof o !== 'object') return o;
    for (const k of KEYS) if (k in o) delete o[k];
    if (o.playerResponse && typeof o.playerResponse === 'object') strip(o.playerResponse);
    return o;
  };
  const parse = JSON.parse;
  JSON.parse = function (...a) { return strip(parse.apply(this, a)); };
  const rjson = Response.prototype.json;
  Response.prototype.json = function (...a) { return rjson.apply(this, a).then(strip); };
  // Respons awal ditulis inline: `var ytInitialPlayerResponse = {...}` memakai setter ini.
  let ipr;
  try {
    Object.defineProperty(window, 'ytInitialPlayerResponse', {
      configurable: true, get: () => ipr, set: (v) => { ipr = strip(v); },
    });
  } catch (e) {}
})();
"""#

/// Daftar blokir jaringan untuk WKContentRuleList: server iklan dan pelacak iklan YouTube.
public let adBlockRules = #"""
[
  {"trigger": {"url-filter": "^https?://([^/]+\\.)?doubleclick\\.net/"}, "action": {"type": "block"}},
  {"trigger": {"url-filter": "^https?://([^/]+\\.)?googlesyndication\\.com/"}, "action": {"type": "block"}},
  {"trigger": {"url-filter": "^https?://([^/]+\\.)?googleadservices\\.com/"}, "action": {"type": "block"}},
  {"trigger": {"url-filter": "^https?://([^/]+\\.)?youtube\\.com/pagead/"}, "action": {"type": "block"}},
  {"trigger": {"url-filter": "^https?://([^/]+\\.)?youtube\\.com/api/stats/ads"}, "action": {"type": "block"}},
  {"trigger": {"url-filter": "^https?://([^/]+\\.)?youtube\\.com/(ptracking|get_midroll_)"}, "action": {"type": "block"}}
]
"""#

/// JS untuk mengatur volume 0..100: pakai API player YouTube, atau elemen video bila tidak ada.
public func volumeScript(_ volume: Int) -> String {
    let v = min(max(volume, 0), 100)
    return """
    (() => { const p = document.getElementById('movie_player');
      if (p && p.setVolume) { p.setVolume(\(v)); \(v) > 0 ? p.unMute() : p.mute(); return true; }
      const x = window.__floatixVideo; if (x) { x.volume = \(v) / 100; x.muted = \(v) === 0; return true; }
      return false; })()
    """
}
