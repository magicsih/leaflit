#!/usr/bin/env python3
"""Render the public share card from its HTML, selected SVG and actual app image."""
import argparse
from pathlib import Path

from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parent.parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--browser-channel', help='Optional installed browser, such as msedge')
    args = parser.parse_args()
    with sync_playwright() as p:
        browser = p.chromium.launch(args=['--disable-gpu'], **({'channel': args.browser_channel} if args.browser_channel else {}))
        page = browser.new_page(viewport={'width': 1200, 'height': 630}, device_scale_factor=1)
        page.goto((ROOT / 'assets/branding/social-preview.html').as_uri(), wait_until='load')
        page.locator('img').evaluate_all('(images) => Promise.all(images.map(image => image.decode()))')
        page.screenshot(path=str(ROOT / 'site/assets/social-preview.png'), animations='disabled')
        browser.close()
    print('Prepared site/assets/social-preview.png (1200x630)')


if __name__ == '__main__':
    main()
