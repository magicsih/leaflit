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
test('outline labels share rendered anchors, preserve hierarchy and contain plain text', () => {
  const result = markdown('# Hello **world**\n\n#### [A link](next.md)\n\n## 한글 😀\n\n## 한글 😀\n\n```md\n# not a heading\n```', 7);
  assert.deepEqual(result.headings, [
    { id:'hello-world', title:'Hello world', level:1 },
    { id:'a-link', title:'A link', level:4 },
    { id:'한글-😀', title:'한글 😀', level:2 },
    { id:'한글-😀-1', title:'한글 😀', level:2 }
  ]);
  for (const heading of result.headings) assert.ok(result.html.includes(`id="${heading.id}"`));
});

test('duplicate suffixes preserve mixed literal suffixes, Unicode and per-document state', () => {
  const source = '# A\n# A\n# A-1\n# A-2\n# A\n# 한글 😀\n# 한글 😀\n# 한글 😀-1\n# 한글 😀';
  const expected = ['a', 'a-1', 'a-1-1', 'a-2', 'a-3', '한글-😀', '한글-😀-1', '한글-😀-1-1', '한글-😀-2'];
  for (const revision of [21, 22]) {
    const result = markdown(source, revision);
    assert.deepEqual(result.headings.map(heading => heading.id), expected);
    for (const id of expected) assert.ok(result.html.includes(`id="${id}"`));
  }
});

test('many identical headings do not rescan all previously used suffixes', () => {
  const count = 2000;
  const originals = new Map([[Map.prototype, Map.prototype.has], [Set.prototype, Set.prototype.has]]);
  let probes = 0;
  let result;
  try {
    for (const [prototype, original] of originals) {
      prototype.has = function (key) {
        if (typeof key === 'string' && /^probe-repeat(?:-\d+)*$/.test(key)) probes++;
        return original.call(this, key);
      };
    }
    result = markdown('# Probe repeat\n'.repeat(count), 23);
  } finally {
    for (const [prototype, original] of originals) prototype.has = original;
  }
  assert.equal(result.headings.length, count);
  assert.equal(result.headings[0].id, 'probe-repeat');
  assert.equal(result.headings.at(-1).id, `probe-repeat-${count - 1}`);
  assert.equal(new Set(result.headings.map(heading => heading.id)).size, count);
  // Count identity lookups instead of asserting a machine-dependent time budget.
  assert.ok(probes <= count * 4, `Expected a linear lookup budget, observed ${probes} probes`);
});
