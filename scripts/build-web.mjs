import { build } from 'esbuild';
import { mkdir, cp, writeFile, readFile, rm } from 'node:fs/promises';
const out = 'Sources/Leaflit/Web';
await rm(out, { recursive: true, force: true });
await mkdir(out, { recursive: true });
await mkdir('build', { recursive: true });
await build({ entryPoints: ['Web/src/renderer.js'], outdir: out, bundle: true, splitting: true, format: 'esm', target: 'safari17', minify: true, chunkNames: 'chunks/[name]-[hash]', legalComments: 'linked', metafile: true }).then(result => writeFile('build/web-metafile.json', JSON.stringify(result.metafile, null, 2)));
await cp('Web/index.html', `${out}/index.html`);
await cp('Web/src/style.css', `${out}/style.css`);
await cp('node_modules/katex/dist/katex.min.css', `${out}/katex.min.css`);
await cp('node_modules/katex/dist/fonts', `${out}/fonts`, { recursive: true });
const lock = JSON.parse(await readFile('package-lock.json', 'utf8'));
let notices = '# Third-party software\n\nBundled renderer dependencies and their licenses.\n';
for (const [path, info] of Object.entries(lock.packages)) {
  if (!path || info.dev) continue;
  notices += `\n${path.replace('node_modules/', '')} ${info.version} (${info.license || 'see package'})\n`;
  for (const file of ['LICENSE', 'LICENSE.md', 'LICENSE.txt', 'LICENSE-MIT', 'LICENSE-MIT.txt', 'license', 'license.md']) {
    try { notices += `${await readFile(`${path}/${file}`, 'utf8')}\n`; break; } catch {}
  }
}
await writeFile(`${out}/THIRD-PARTY-NOTICES.txt`, notices);
