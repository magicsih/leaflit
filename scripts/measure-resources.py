#!/usr/bin/env python3
"""Measure the app and new WebKit helpers during one isolated 60-second run."""
import argparse
import json
import os
from pathlib import Path
import plistlib
import re
import signal
import subprocess
import time
root = Path(__file__).resolve().parent.parent
version = plistlib.loads((root / 'Sources/Leaflit/Info.plist').read_bytes())['CFBundleShortVersionString']
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--app', type=Path, default=root / f'build/Leaflit-{version}/Leaflit.app')
app = parser.parse_args().app.resolve()
fixture = root / 'Fixtures/Benchmark100KiB.md'
out = root / 'build/benchmarks'
out.mkdir(parents=True, exist_ok=True)
def processes():
    result = {}
    rows = subprocess.check_output(['/bin/ps', '-axo', 'pid=,rss=,time=,comm='], text=True).splitlines()
    for row in rows:
        fields = row.split(None, 3)
        if len(fields) != 4:
            continue
        pid, rss, cpu, path = fields
        if 'com.apple.WebKit.' in path or path == str(app / 'Contents/MacOS/Leaflit'):
            mins, sec = cpu.split(':')
            result[int(pid)] = {'pid': int(pid), 'rssKiB': int(rss), 'cpuSeconds': float(mins) * 60 + float(sec), 'path': path}
    return result
baseline = processes()
assert not any('Leaflit.app' in p['path'] for p in baseline.values()), 'Close the candidate app before measuring.'
subprocess.run(['/usr/bin/open', '-n', '-a', str(app), str(fixture)], check=True)
time.sleep(5)
started = processes()
new = {pid: row for pid, row in started.items() if pid not in baseline}
app_pids = [pid for pid, row in new.items() if row['path'] == str(app / 'Contents/MacOS/Leaflit')]
assert len(app_pids) == 1, app_pids
try:
    command = ['/usr/bin/footprint', '-f', 'bytes', '--noCategories', '-j', str(out / 'footprint.json')]
    for pid in new:
        command += ['-p', str(pid)]
    memory = subprocess.check_output(command, text=True)
    (out / 'footprint.txt').write_text(memory)
    elapsed_start = time.monotonic()
    samples = []
    for n in range(60):
        time.sleep(1)
        samples.append({pid: row for pid, row in processes().items() if pid in new})
        if (n + 1) % 15 == 0:
            print(f'Idle sample {n + 1}/60', flush=True)
    elapsed = time.monotonic() - elapsed_start
    final = samples[-1]
    cpu = sum(max(0, final[pid]['cpuSeconds'] - row['cpuSeconds']) for pid, row in new.items() if pid in final)
    result = {'durationSeconds': elapsed, 'idleAggregateCPUPercent': cpu / elapsed * 100, 'initialProcesses': list(new.values()), 'finalProcesses': list(final.values()), 'rssSumMiB': sum(x['rssKiB'] for x in final.values()) / 1024, 'attribution': 'New app and WebKit PIDs after launch compared with a pre-launch process baseline; run in isolation.'}
    (out / 'resources.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, indent=2), flush=True)
finally:
    for pid in app_pids:
        os.kill(pid, signal.SIGTERM)
