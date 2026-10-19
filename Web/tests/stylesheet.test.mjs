import test from 'node:test';
import assert from 'node:assert/strict';
import { createStylesheetLoader } from '../src/stylesheet.js';

function fakeDocument(onAppend) {
  const links = [];
  return {
    links,
    createElement(tag) { assert.equal(tag, 'link'); return new EventTarget(); },
    head: { append(link) { links.push(link); onAppend?.(link); } }
  };
}

test('overlapping render revisions share pending stylesheet readiness', async () => {
  const document = fakeDocument();
  const ready = createStylesheetLoader(document, 'katex-css', 'katex.min.css');
  assert.equal(document.links.length, 0, 'Plain documents must not insert math styles');
  const first = ready();
  const second = ready();
  assert.equal(document.links.length, 1);
  assert.equal(document.links[0].id, 'katex-css');
  assert.equal(document.links[0].rel, 'stylesheet');
  assert.equal(document.links[0].href, 'katex.min.css');
  const completedRevisions = [];
  const revisions = [first.then(() => completedRevisions.push(1)), second.then(() => completedRevisions.push(2))];
  await Promise.resolve();
  assert.deepEqual(completedRevisions, [], 'Neither render may complete while CSS is pending');
  assert.equal(first, second);
  document.links[0].dispatchEvent(new Event('load'));
  await Promise.all(revisions);
  assert.deepEqual(completedRevisions, [1, 2]);
  assert.equal(ready(), first, 'Later revisions reuse completed readiness');
  assert.equal(document.links.length, 1);
});

test('a stylesheet error releases all waiting revisions without another insertion', async () => {
  const document = fakeDocument();
  const ready = createStylesheetLoader(document, 'katex-css', 'katex.min.css');
  const first = ready(), second = ready();
  document.links[0].dispatchEvent(new Event('error'));
  await Promise.all([first, second]);
  await ready();
  assert.equal(document.links.length, 1);
});

test('stylesheet listeners are installed before insertion can complete the load', async () => {
  const document = fakeDocument(link => link.dispatchEvent(new Event('load')));
  const ready = createStylesheetLoader(document, 'katex-css', 'katex.min.css');
  await ready();
  assert.equal(document.links.length, 1);
});
