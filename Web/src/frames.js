// Animation callbacks may stop when WebKit has no rendering opportunity.
// Keep work progressing; a timer result does not establish that pixels painted.
export function waitForFrames(count = 2) {
  return new Promise(resolve => {
    let remaining = count, request, finished = false;
    const finish = timing => {
      if (finished) return;
      finished = true;
      clearTimeout(timer);
      cancelAnimationFrame(request);
      resolve(timing);
    };
    const tick = () => {
      if (finished) return;
      if (--remaining === 0) finish('animationFrames');
      else request = requestAnimationFrame(tick);
    };
    const timer = setTimeout(() => finish('timerFallback'), 250);
    request = requestAnimationFrame(tick);
  });
}
