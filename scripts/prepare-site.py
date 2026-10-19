#!/usr/bin/env python3
"""Stage only public website files and the selected brand SVG for GitHub Pages."""
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUTPUT = ROOT / 'build/site'
if OUTPUT.exists():
    shutil.rmtree(OUTPUT)
shutil.copytree(ROOT / 'site', OUTPUT, ignore=shutil.ignore_patterns('README.md'))
shutil.copyfile(ROOT / 'assets/branding/leaflit.svg', OUTPUT / 'assets/leaflit.svg')
print('Prepared static GitHub Pages artifact in build/site')
