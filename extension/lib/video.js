(function () {
  // Diputar dulu, lalu luas terbesar; luas <= 0 diabaikan.
  function pickVideo(list) {
    let best = -1, bestPlaying = false, bestArea = 0;
    list.forEach((v, i) => {
      const area = v.width * v.height;
      if (!(area > 0)) return;
      const playing = !v.paused;
      if (best === -1 || (playing && !bestPlaying) || (playing === bestPlaying && area > bestArea)) {
        best = i; bestPlaying = playing; bestArea = area;
      }
    });
    return best;
  }
  function buildOpenMessage(pageUrl, v) {
    return { type: 'open', url: pageUrl, time: v.currentTime, aspect: v.height ? v.width / v.height : 16 / 9 };
  }
  const api = { pickVideo, buildOpenMessage };
  globalThis.FloatixVideo = api;
  if (typeof module !== 'undefined') module.exports = api;
})();
