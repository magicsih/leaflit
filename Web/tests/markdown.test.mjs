import { test } from 'node:test';
import assert from 'node:assert/strict';
import { markdown } from '../src/markdown.js';
test('GFM, Unicode, duplicate headings and readonly tasks', () => {
  const { html } = markdown('# 안녕 😀\n# 안녕 😀\n\n~~old~~\n\n- [x] done\n\n| A | B |\n|---|---|\n| 1 | 2 |', 1);
  for (const value of ['id="안녕-😀"', 'id="안녕-😀-1"', '<s>old</s>', 'disabled', '<table ']) assert.ok(html.includes(value), value);
});
test('all four math delimiters and fenced code preservation', () => {
  const result = markdown('$x$ and \\(y\\)\n\n$$z$$\n\n\\[w\\]\n\n```txt\n$x$\n```', 2);
  assert.equal(result.math.length, 4);
  assert.ok(result.html.includes('$x$\n</code></pre>'));
});
test('HTML, scripts, remote resources and dangerous links remain inert', () => {
  const { html } = markdown('<script>alert(1)</script>\n\n![private](https://example.com/x.png)\n\n[x](javascript:alert(1))\n\n![local](a%20b.png)', 3);
  assert.ok(!html.includes('<script>'));
  assert.ok(!html.includes('src="https:'));
  assert.ok(!html.includes('href="javascript:'));
  assert.ok(html.includes('leaflit-image://3/a%20b.png'));
});
test('Mermaid source is escaped before deferred rendering', () => {
  const result = markdown('```mermaid\n<script>hello</script>\n```', 4);
  assert.equal(result.diagrams.length, 1);
  assert.ok(result.html.includes('&lt;script&gt;'));
});
