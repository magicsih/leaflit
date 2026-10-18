#!/usr/bin/env python3
from pathlib import Path
root = Path(__file__).resolve().parent.parent
intro = '# Benchmark\n\n$x^2 + y^2 = z^2$\n\n```mermaid\nflowchart LR\n A["Open"] --> B["Read"]\n```\n\n'
row = '## Section\n\nA fixed paragraph with **bold**, 한글 and emoji 🌿.\n\n'
raw = (intro + row * 2000).encode()[:102400]
while True:
    try:
        raw.decode()
        break
    except UnicodeDecodeError:
        raw = raw[:-1]
(root / 'Fixtures/Benchmark100KiB.md').write_bytes(raw.ljust(102400, b' '))
