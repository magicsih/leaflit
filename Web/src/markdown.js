import MarkdownIt from 'markdown-it';
import taskLists from 'markdown-it-task-lists';
import { tex } from '@mdit/plugin-tex';

export const escape = text => text.replace(/[&<>"']/g, c => ({'&':'&amp;', '<':'&lt;', '>':'&gt;', '"':'&quot;', "'":'&#39;'}[c]));
export function markdown(source, revision) {
  const md = new MarkdownIt({ html: false, linkify: false, typographer: false }).use(taskLists);
  const math = [], diagrams = [], headings = new Map(), outline = [];
  md.use(tex, { delimiters: 'all', render(content, display) {
    const id = `math-${revision}-${math.length}`;
    math.push({ id, content, display });
    return `<${display ? 'div' : 'span'} id="${id}" class="math">${escape(content)}</${display ? 'div' : 'span'}>`;
  }});
  const fence = md.renderer.rules.fence;
  md.renderer.rules.fence = (tokens, idx, options, env, renderer) => {
    const token = tokens[idx];
    if (token.info.trim() !== 'mermaid') return fence(tokens, idx, options, env, renderer);
    const id = `diagram-${revision}-${diagrams.length}`;
    diagrams.push({ id, content: token.content });
    return `<figure id="${id}" class="diagram" aria-label="Diagram"><pre>${escape(token.content)}</pre></figure>`;
  };
  md.renderer.rules.image = (tokens, idx) => {
    const token = tokens[idx], src = token.attrGet('src') || '';
    const alt = md.renderer.renderInlineAsText(token.children, md.options, {});
    let path;
    try { path = decodeURIComponent(src); } catch { path = ''; }
    if (!path || /^(?:[a-z][a-z0-9+.-]*:|\/|\\)/i.test(path) || !/\.(png|jpe?g)$/i.test(path)) {
      return `<span class="image-fallback">${escape(alt || 'Image')} — image unavailable</span>`;
    }
    return `<img src="leaflit-image://${revision}/${encodeURIComponent(path)}" alt="${escape(alt)}" loading="lazy">`;
  };
  const tokens = md.parse(source, {});
  for (let i = 0; i < tokens.length; i++) {
    const token = tokens[i];
    if (token.map && token.nesting !== -1) token.attrSet('data-source-line', String(token.map[0]));
    if (token.type === 'heading_open') {
      const label = (tokens[i + 1]?.children || []).map(t => t.content).join('');
      const base = label.toLowerCase().trim().replace(/[^\p{L}\p{N}\p{Extended_Pictographic}\s_-]/gu, '').replace(/\s+/g, '-') || 'section';
      let slug = base, n = 0;
      while (headings.has(slug)) slug = `${base}-${++n}`;
      headings.set(slug, true); token.attrSet('id', slug);
      const title = md.renderer.renderInlineAsText(tokens[i + 1]?.children || [], md.options, {});
      outline.push({ id: slug, title, level: Number(token.tag.slice(1)) });
    }
  }
  return { html: md.renderer.render(tokens, md.options, {}), math, diagrams, headings: outline };
}
