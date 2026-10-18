#!/usr/bin/env python3
"""Measure local app launches using WebKit display events from the unified log.

OS file caches stay warm. No OS settings, credentials or documents are changed.
Only the benchmark's launched processes are stopped.
"""
import argparse
import datetime as dt
import json
import os
from pathlib import Path
import plistlib
import queue
import re
import signal
import subprocess
import threading
import time

root = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser()
version = plistlib.loads((root / 'Sources/Leaflit/Info.plist').read_bytes())['CFBundleShortVersionString']
parser.add_argument('--app', type=Path, default=root / f'build/Leaflit-{version}/Leaflit.app')
parser.add_argument('--count', type=int, default=20)
args = parser.parse_args()
app = args.app.resolve()
assert app.is_dir(), app
out = root / 'build/benchmarks'
out.mkdir(parents=True, exist_ok=True)
fixture = root / 'Fixtures/Benchmark100KiB.md'
assert fixture.stat().st_size == 102400
events = queue.Queue()
stream = subprocess.Popen(['/usr/bin/log', 'stream', '--style', 'ndjson', '--level', 'info', '--predicate', 'subsystem == "io.github.magicsih.leaflit" AND category == "performance"'], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, bufsize=1)
def read_events():
    for line in stream.stdout:
        try:
            value = json.loads(line)
            if 'display phase=' in value.get('eventMessage', ''):
                events.put(value)
        except json.JSONDecodeError:
            pass
threading.Thread(target=read_events, daemon=True).start()
samples = []
launched = set()
try:
    time.sleep(1)
    for n in range(args.count):
        while not events.empty():
            events.get_nowait()
        started = time.time()
        subprocess.run(['/usr/bin/open', '-n', '-a', str(app), str(fixture)], check=True)
        sample = {'iteration': n + 1}
        pid = None
        deadline = time.monotonic() + 30
        while time.monotonic() < deadline:
            event = events.get(timeout=30)
            stamp = dt.datetime.fromisoformat(event['timestamp']).timestamp()
            if stamp < started:
                continue
            pid = event['processID']
            path = subprocess.check_output(['/bin/ps', '-p', str(pid), '-o', 'comm='], text=True).strip()
            if path != str(app / 'Contents/MacOS/Leaflit'):
                continue
            launched.add(pid)
            match = re.search(r'phase=(body|complete) ms=([\d.]+)', event['eventMessage'])
            if not match:
                continue
            phase, render_ms = match.groups()
            sample[phase] = (stamp - started) * 1000
            sample[phase + 'FromOpen'] = float(render_ms)
            if phase == 'complete':
                break
        if 'complete' not in sample:
            raise RuntimeError('Display completion timed out')
        samples.append(sample)
        print(json.dumps(sample), flush=True)
        os.kill(pid, signal.SIGTERM)
        launched.remove(pid)
        time.sleep(.25)
finally:
    for pid in launched:
        os.kill(pid, signal.SIGTERM)
    stream.terminate()
    stream.wait(timeout=5)
    (out / 'cold-opens.json').write_text(json.dumps(samples, indent=2) + '\n')
