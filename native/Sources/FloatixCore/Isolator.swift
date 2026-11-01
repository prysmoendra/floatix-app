import Foundation

private let template = #"""
(() => {
  const start = %START%;
  const pick = () => [...document.querySelectorAll('video')]
    .sort((a, b) => b.clientWidth * b.clientHeight - a.clientWidth * a.clientHeight)[0];
  const apply = () => {
    const v = pick(); if (!v) return false;
    const s = document.createElement('style');
    s.textContent = 'html,body{background:#000!important;overflow:hidden!important}' +
      'body *{visibility:hidden!important}' +
      'video.__floatix{visibility:visible!important;position:fixed!important;inset:0!important;' +
      'width:100vw!important;height:100vh!important;z-index:2147483647!important;object-fit:contain!important;background:#000}';
    document.documentElement.appendChild(s);
    v.classList.add('__floatix');
    const go = () => { if (start > 0) v.currentTime = start; v.play().catch(() => {}); };
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
