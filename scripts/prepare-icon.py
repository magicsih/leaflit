#!/usr/bin/env python3
"""Render the selected SVG and package a conventional macOS icon with iconutil."""
import argparse
import shutil
import subprocess
import tempfile
from pathlib import Path

from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parent.parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--browser-channel', help='Optional installed browser, such as msedge')
    args = parser.parse_args()
    source = ROOT / 'assets/branding/leaflit.svg'
    (ROOT / 'build').mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='leaflit-icon-', dir=ROOT / 'build') as temporary:
        iconset = Path(temporary) / 'Leaflit.iconset'
        iconset.mkdir()
        with sync_playwright() as p:
            browser = p.chromium.launch(args=['--disable-gpu'], **({'channel': args.browser_channel} if args.browser_channel else {}))
            page = browser.new_page(device_scale_factor=1)
            rendered = {}
            for pixels in [16, 32, 64, 128, 256, 512, 1024]:
                page.set_viewport_size({'width': pixels, 'height': pixels})
                page.set_content('<style>html,body{margin:0;background:transparent}svg{display:block;width:100vw;height:100vh}</style>' + source.read_text())
                page.evaluate('() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)))')
                rendered[pixels] = page.screenshot(omit_background=True, animations='disabled')
            for size in [16, 32, 128, 256, 512]:
                for scale in [1, 2]:
                    pixels = size * scale
                    filename = f'icon_{size}x{size}' + ('@2x' if scale == 2 else '') + '.png'
                    (iconset / filename).write_bytes(rendered[pixels])
            browser.close()
        subprocess.run(['/usr/bin/iconutil', '-c', 'icns', str(iconset), '-o', str(ROOT / 'Sources/Leaflit/Leaflit.icns')], check=True)
        shutil.copyfile(iconset / 'icon_512x512@2x.png', ROOT / 'assets/branding/leaflit-1024.png')
    print('Prepared Leaflit.icns and 1024px PNG from assets/branding/leaflit.svg')


if __name__ == '__main__':
    main()
