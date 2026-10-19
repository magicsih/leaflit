import test from 'node:test';
import assert from 'node:assert/strict';
import { waitForFrames } from '../src/frames.js';

function pausedFrames() {
  const callbacks = new Map();
  const originalRequest = globalThis.requestAnimationFrame;
  const originalCancel = globalThis.cancelAnimationFrame;
  let nextID = 0;
  globalThis.requestAnimationFrame = callback => { callbacks.set(++nextID, callback); return nextID; };
  globalThis.cancelAnimationFrame = id => callbacks.delete(id);
  return {
    callbacks,
    tick() {
      const [id, callback] = callbacks.entries().next().value;
      callbacks.delete(id); callback();
    },
    restore() {
      if (originalRequest) globalThis.requestAnimationFrame = originalRequest; else delete globalThis.requestAnimationFrame;
      if (originalCancel) globalThis.cancelAnimationFrame = originalCancel; else delete globalThis.cancelAnimationFrame;
    }
  };
}

test('two actual animation callbacks retain frame timing', async () => {
  const frames = pausedFrames();
  try {
    const completion = waitForFrames();
    frames.tick(); assert.equal(frames.callbacks.size, 1);
    frames.tick(); assert.equal(await completion, 'animationFrames');
    assert.equal(frames.callbacks.size, 0);
  } finally { frames.restore(); }
});

test('a paused animation callback yields progress and cancels late work', async () => {
  const frames = pausedFrames();
  try {
    const completion = waitForFrames();
    const lateCallback = [...frames.callbacks.values()][0];
    assert.equal(await completion, 'timerFallback');
    assert.equal(frames.callbacks.size, 0);
    lateCallback();
    assert.equal(frames.callbacks.size, 0);
  } finally { frames.restore(); }
});

test('outline scheduling can wait for one frame without a second callback', async () => {
  const frames = pausedFrames();
  try {
    const completion = waitForFrames(1);
    frames.tick(); assert.equal(await completion, 'animationFrames');
    assert.equal(frames.callbacks.size, 0);
  } finally { frames.restore(); }
});
