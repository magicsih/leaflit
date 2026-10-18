import { markdown } from './markdown.js';
let current = 0;
const article = document.querySelector('article');
const post = payload => window.webkit?.messageHandlers?.leaflit?.postMessage(payload);
const frame = () => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)));
function position() {
  const blocks = [...article.querySelectorAll('[data-source-line]')];
  const block = blocks.find(node => node.getBoundingClientRect().bottom >= 0);
  return { line: Number(block?.dataset.sourceLine || 0), offset: block?.getBoundingClientRect().top || 0, y: scrollY };
}
function restore(location) {
  if (typeof location?.anchor === 'string') {
    document.getElementById(location.anchor)?.scrollIntoView(); return;
  }
  if (location?.line !== undefined) {
    const nodes = [...article.querySelectorAll('[data-source-line]')];
    const block = nodes.reduce((best, node) => Number(node.dataset.sourceLine) <= location.line ? node : best, null);
    if (block) { scrollTo(0, scrollY + block.getBoundingClientRect().top - location.offset); return; }
  }
  scrollTo(0, location?.y || 0);
}
function failure(node, source, kind) {
  node.replaceChildren();
  const label = document.createElement('small'); label.textContent = `${kind} could not be rendered`;
  const raw = document.createElement('code'); raw.textContent = source;
  const pre = document.createElement('pre'); pre.append(raw); node.append(label, pre); node.classList.add('render-error');
}
window.Leaflit = {
  position,
  anchor(value) { document.getElementById(value)?.scrollIntoView(); },
  async render(payload) {
    current = payload.revision;
    const revision = current, start = performance.now();
    const saved = payload.location || (payload.preserve ? position() : { y: 0 });
    const result = markdown(payload.text, revision);
    if (revision !== current) return;
    article.innerHTML = result.html;
    article.querySelectorAll('img').forEach(img => {
      img.addEventListener('error', () => { const fallback = document.createElement('span'); fallback.className = 'image-fallback'; fallback.textContent = `${img.alt || 'Image'} — image unavailable`; img.replaceWith(fallback); });
    });
    restore(saved);
    await frame();
    if (revision !== current) return;
    post({ type: 'displayed', revision, phase: 'body', milliseconds: performance.now() - start });
    if (result.math.length) {
      const { default: katex } = await import('katex');
      if (!document.querySelector('#katex-css')) {
        const css = document.createElement('link'); css.id = 'katex-css'; css.rel = 'stylesheet'; css.href = 'katex.min.css'; document.head.append(css);
        await new Promise(resolve => { css.onload = resolve; css.onerror = resolve; });
      }
      if (revision !== current) return;
      for (const item of result.math) {
        const node = document.getElementById(item.id); if (!node) continue;
        try { katex.render(item.content, node, { displayMode: item.display, throwOnError: true, trust: false, strict: 'error', maxExpand: 1000 }); }
        catch { failure(node, item.content, 'Formula'); }
      }
      await document.fonts.ready;
    }
    if (result.diagrams.length) {
      const [{ default: mermaid }, { default: DOMPurify }] = await Promise.all([import('mermaid'), import('dompurify')]);
      if (revision !== current) return;
      mermaid.initialize({ startOnLoad: false, securityLevel: 'strict', htmlLabels: false, theme: matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'default', suppressErrorRendering: true,
        maxTextSize: 100000, flowchart: { htmlLabels: false }, fontFamily: '-apple-system, sans-serif' });
      for (const item of result.diagrams) {
        if (revision !== current) return;
        const node = document.getElementById(item.id); if (!node) continue;
        try {
          if (/%%\s*\{|^\s*---/m.test(item.content)) throw new Error('Document configuration is disabled');
          const { svg } = await mermaid.render(`svg-${item.id}`, item.content);
          if (revision !== current) return;
          node.innerHTML = DOMPurify.sanitize(svg, { USE_PROFILES: { svg: true, svgFilters: true }, FORBID_TAGS: ['a', 'image', 'foreignObject', 'script'], FORBID_ATTR: ['href', 'xlink:href'] });
          node.setAttribute('role', 'img');
        } catch { if (revision === current) failure(node, item.content, 'Diagram'); }
      }
    }
    if (revision !== current) return;
    restore(saved);
    await frame();
    if (revision === current) post({ type: 'displayed', revision, phase: 'complete', milliseconds: performance.now() - start });
  }
};
document.addEventListener('click', event => {
  const a = event.target.closest('a');
  if (!a) return;
  event.preventDefault();
  post({ type: 'navigate', href: a.getAttribute('href') });
});
matchMedia('(prefers-color-scheme: dark)').addEventListener('change', () => post({ type: 'appearance' }));
post({ type: 'ready' });
