import { test } from 'node:test';
import assert from 'node:assert/strict';
import { markdown } from '../src/markdown.js';
test('leading front matter is metadata rather than a combined title or outline entry', () => {
  const source = '---\ntitle: A long internal title\ntags: [draft, notes]\ndescription: Internal metadata\n---\n\n# Project notes\n\nBody text.';
  const result = markdown(source, 1);
  assert.deepEqual(result.headings, [{ id: 'project-notes', title: 'Project notes', level: 1 }]);
  assert.ok(result.html.startsWith('<h1 data-source-line="6"'));
  assert.ok(!result.html.includes('Internal metadata'));
  assert.ok(!result.html.includes('A long internal title'));
  assert.ok(!result.html.includes('<hr'));
});
test('front matter preserves original body lines across BOM and line endings', () => {
  for (const newline of ['\n', '\r\n', '\r']) for (const close of ['---', '...']) {
    const source = '\ufeff' + ['--- \t', 'title: Metadata', close + '\t', '', '# Body', '', '$\\bad$', '', '```mermaid', 'invalid!', '```'].join(newline);
    const result = markdown(source, 2);
    assert.deepEqual(result.headings, [{ id: 'body', title: 'Body', level: 1 }]);
    assert.ok(result.html.startsWith('<h1 data-source-line="4"'));
    assert.deepEqual(result.math.map(item => item.line), [6]);
    assert.deepEqual(result.diagrams.map(item => item.line), [8]);
  }
});
test('metadata does not create body content or activate optional renderers', () => {
  const source = '---\ntitle: <script>alert(1)</script>\nformula: $x$\nexample: |\n  # Hidden heading\n  ```mermaid\n  invalid!\n  ```\n---';
  const result = markdown(source, 3);
  assert.equal(result.html, '');
  assert.deepEqual(result.headings, []);
  assert.deepEqual(result.math, []);
  assert.deepEqual(result.diagrams, []);
  assert.equal(markdown('---\n---\n\nBody without a title.', 4).html, '<p data-source-line="3">Body without a title.</p>\n');
});
test('incomplete front matter and ordinary Markdown separators remain visible', () => {
  for (const [source, visible] of [
    ['---\ntitle: Unclosed metadata\n\n# Body', 'Unclosed metadata'],
    ['\n---\ntitle: Not at the start\n---', 'Not at the start'],
    ['# Body\n\n---\n\nA real Setext heading\n---', 'A real Setext heading'],
    ['```yaml\n---\ntitle: A visible example\n---\n```', 'A visible example'],
    ['> ---\n> title: Quoted Markdown\n> ---', 'Quoted Markdown'],
    ['- ---\n  title: Nested Markdown\n  ---', 'Nested Markdown']
  ]) {
    assert.ok(markdown(source, 5).html.includes(visible), visible);
  }
});
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
test('error repair locations come from original blocks with BOM, CRLF and repeated content', () => {
  const source = '\ufeff# 😀\r\n\r\n$\\bad$\r\n\r\n$\\bad$\r\n\r\n$$\\bad$$\r\n\r\n```mermaid\r\ninvalid!\r\n```\r\n\r\n```mermaid\r\ninvalid!\r\n```';
  const result = markdown(source, 41);
  assert.deepEqual(result.math.map(item => item.line), [2, 4, 6]);
  assert.deepEqual(result.diagrams.map(item => item.line), [8, 12]);
  for (const item of [...result.math, ...result.diagrams]) assert.ok(result.html.includes(`id="${item.id}" data-source-line="${item.line}"`));
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
