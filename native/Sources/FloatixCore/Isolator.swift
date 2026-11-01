import Foundation

private let template = #"""
(() => {
  const start = %START%;
  const pick = () => [...document.querySelectorAll('video')]
    .sort((a, b) => b.clientWidth * b.clientHeight - a.clientWidth * a.clientHeight)[0];
  // Induk dengan transform/filter/contain membuat position:fixed relatif ke induk itu, bukan jendela.
  // WebKit juga tetap memotong video fixed dengan overflow:hidden induknya (player YouTube mulai di y=56).
  const flatten = (v) => {
    for (let e = v.parentElement; e && e !== document.documentElement; e = e.parentElement) {
      for (const [k, val] of [['transform', 'none'], ['filter', 'none'], ['contain', 'none'], ['will-change', 'auto'], ['perspective', 'none'],
                              ['overflow', 'visible'], ['clip-path', 'none'], ['clip', 'auto']])
        e.style.setProperty(k, val, 'important');
    }
  };
  const apply = () => {
    const v = pick(); if (!v) return false;
    const s = document.createElement('style');
    s.textContent = 'html,body{background:#000!important;overflow:hidden!important;margin:0!important;padding:0!important}' +
      'body *{visibility:hidden!important}' +
      'video.__floatix{visibility:visible!important;position:fixed!important;inset:0!important;top:0!important;left:0!important;' +
      'margin:0!important;transform:none!important;' +
      'width:100vw!important;height:100vh!important;z-index:2147483647!important;object-fit:contain!important;background:#000}';
    document.documentElement.appendChild(s);
    v.classList.add('__floatix');
    flatten(v);
    // YouTube bisa mengganti/memindah elemen video; terapkan ulang tiap detik.
    setInterval(() => {
      const cur = pick(); if (!cur) return;
      if (cur !== window.__floatixVideo) {
        document.querySelectorAll('video.__floatix').forEach(x => x.classList.remove('__floatix'));
        cur.classList.add('__floatix'); window.__floatixVideo = cur;
      }
      flatten(cur);
    }, 1000);
    // Selama iklan YouTube (.ad-showing) jangan seek: elemen video sedang memutar iklan.
    const go = () => {
      if (start > 0 && !document.querySelector('.ad-showing') && Math.abs(v.currentTime - start) > 2) v.currentTime = start;
      v.play().catch(() => {});
    };
    v.readyState >= 1 ? go() : v.addEventListener('loadedmetadata', go, { once: true });
    window.__floatixVideo = v;
    return true;
  };
  if (!apply()) { const t = setInterval(() => apply() && clearInterval(t), 500); setTimeout(() => clearInterval(t), 15000); }
})();
"""#

public func isolatorScript(startTime: Double) -> String {
    let t = startTime.isFinite && startTime > 0 ? startTime : 0
    return template.replacingOccurrences(of: "%START%", with: "\(t)")
}
