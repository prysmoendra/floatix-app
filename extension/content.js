(() => {
  if (!/^https?:$/.test(location.protocol)) return null;
  const vids = [...document.querySelectorAll('video')];
  const i = FloatixVideo.pickVideo(vids.map(v => ({ width: v.clientWidth, height: v.clientHeight, paused: v.paused })));
  if (i < 0) return null;
  const v = vids[i];
  v.pause();
  window.__floatixSource = v;
  const hasIntrinsic = v.videoWidth > 0 && v.videoHeight > 0;
  return FloatixVideo.buildOpenMessage(location.href, {
    currentTime: v.currentTime,
    width: hasIntrinsic ? v.videoWidth : v.clientWidth,
    height: hasIntrinsic ? v.videoHeight : v.clientHeight,
  });
})();
