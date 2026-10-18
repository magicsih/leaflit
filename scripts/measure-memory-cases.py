#!/usr/bin/env python3
"""Compare the unchanged Release app in fresh processes, including window teardown.

Writes generated fixtures and raw footprint output under build/. It closes only
the launched app's window using its PID, then stops only that app process.
No user documents, system settings, renderer code, or OS caches are changed.
"""
import argparse
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import queue
import signal
import statistics
import subprocess
import threading
import time


ROOT = Path(__file__).resolve().parent.parent
DEFAULT_CASES = ['empty', 'plain', 'math', 'mermaid', 'combined']
CASES = DEFAULT_CASES + ['short', 'prose']
HELPERS = {'com.apple.WebKit.WebContent', 'com.apple.WebKit.GPU',
           'com.apple.WebKit.Networking'}


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def processes():
    result = {}
    output = subprocess.check_output(
        ['/bin/ps', '-axo', 'pid=,rss=,comm='], text=True)
    for row in output.splitlines():
        fields = row.split(None, 2)
        if len(fields) != 3:
            continue
        pid, rss, path = fields
        name = Path(path).name
        if name == 'Leaflit' or name in HELPERS:
            result[int(pid)] = {'name': name, 'rssKiB': int(rss), 'path': path}
    return result


def window_count(pid):
    script = (f'tell application "System Events" to tell '
              f'(first application process whose unix id is {pid}) '
              'to get count of windows')
    return int(subprocess.check_output(
        ['/usr/bin/osascript', '-e', script], text=True, timeout=10).strip())


def close_window(pid):
    script = f'''tell application "System Events"
        tell (first application process whose unix id is {pid})
            if (count of windows) is not 1 then error "Expected one benchmark window"
            set closeButton to first button of window 1 whose subrole is "AXCloseButton"
            perform action "AXPress" of closeButton
        end tell
    end tell'''
    subprocess.run(['/usr/bin/osascript', '-e', script], check=True,
                   stdout=subprocess.DEVNULL, timeout=10)
    assert window_count(pid) == 0, 'The benchmark window did not close'


def raise_window(pid):
    script = f'''tell application "System Events"
        tell (first application process whose unix id is {pid})
            set frontmost to true
            perform action "AXRaise" of window 1
        end tell
    end tell'''
    subprocess.run(['/usr/bin/osascript', '-e', script], check=True,
                   stdout=subprocess.DEVNULL, timeout=10)


def fixtures(directory):
    original = (ROOT / 'Fixtures/Benchmark100KiB.md').read_text()
    math = '$x^2 + y^2 = z^2$'
    diagram = '```mermaid\nflowchart LR\n A["Open"] --> B["Read"]\n```'
    assert original.count(math) == original.count(diagram) == 1
    result = {}
    for case in DEFAULT_CASES[1:]:
        text = original
        # Preserve every newline, source offset and byte count of the shared body.
        # Two plain-text characters replace a removed feature at its first line.
        for feature, keep in [(math, case in ('math', 'combined')),
                              (diagram, case in ('mermaid', 'combined'))]:
            if not keep:
                replacement = ''.join('\n' if c == '\n' else ' ' for c in feature)
                replacement = 'xx' + replacement[2:]
                text = text.replace(feature, replacement)
        path = directory / f'{case}.md'
        path.write_text(text)
        assert path.stat().st_size == 102400
        result[case] = path
    assert result['combined'].read_bytes() == (ROOT / 'Fixtures/Benchmark100KiB.md').read_bytes()
    paragraph = ('A fixed paragraph with **bold**, 한글 and emoji 🌿. '
                 'A local document opens in a quiet window. The reader can select text, '
                 'follow a link and return to the previous page. This paragraph has no '
                 'formulas, diagrams or images.\n\n')
    for case, size, text in [
        ('short', 1024, '# Short document\n\n' + paragraph * 10),
        ('prose', 102400, '# Prose document\n\n' + ''.join(
            f'## Section {n}\n\n' + paragraph * 40 for n in range(20)))]:
        raw = text.encode()[:size].decode('utf-8', errors='ignore').encode()
        path = directory / f'{case}.md'
        path.write_bytes(raw.ljust(size, b' '))
        assert path.stat().st_size == size
        result[case] = path
    return result


def snapshot(directory, label, baseline, owned, app_pid, retry=0):
    rows = processes()
    selected = {pid: row for pid, row in rows.items() if pid in owned}
    unexpected = set(rows) - set(baseline) - owned
    assert not unexpected, 'Unrelated app/WebKit process started during measurement'
    assert app_pid in selected, 'The benchmark app exited unexpectedly'
    suffix = f'-retry{retry}' if retry else ''
    raw = directory / f'{label}{suffix}.json'
    command = ['/usr/bin/footprint', '-f', 'bytes', '--noCategories', '-j', str(raw)]
    for pid in sorted(selected):
        command.extend(['-p', str(pid)])
    capture = subprocess.run(command, capture_output=True, text=True, timeout=15)
    (directory / f'{label}{suffix}.txt').write_text(capture.stdout + capture.stderr)
    value = json.loads(raw.read_text())
    measured = {p['pid'] for p in value['processes']}
    if capture.returncode or value.get('errors') or measured != set(selected):
        vanished = set(selected) - set(processes())
        if vanished and app_pid not in vanished and retry < 3:
            # A helper may normally exit between ps and footprint after window close.
            # Keep the failed raw capture and sample the surviving owned PIDs again.
            return snapshot(directory, label, baseline, owned, app_pid, retry + 1)
    capture.check_returncode()
    assert not value.get('errors'), value.get('errors')
    assert measured == set(selected), (measured, set(selected))
    return {'footprintMiB': value['total footprint'] / 1048576,
            'rssSumMiB': sum(p['rssKiB'] for p in selected.values()) / 1024,
            'processes': [{'name': p['name'], 'footprintMiB': p['footprint'] / 1048576}
                          for p in value['processes']],
            'warnings': value.get('warnings', []), 'helperExitRetries': retry}


def samples(directory, phase, baseline, owned, pid, since):
    result = []
    for n in range(3):
        if n:
            time.sleep(.5)
        value = snapshot(directory, f'{phase}-{n + 1}', baseline, owned, pid)
        value['secondsSincePhaseStart'] = time.monotonic() - since
        result.append(value)
    return {'samples': result,
            'medianMiB': statistics.median(v['footprintMiB'] for v in result)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--app', type=Path, default=ROOT / 'build/Leaflit-0.1.0/Leaflit.app')
    parser.add_argument('--repeats', type=int, default=5)
    parser.add_argument('--resume', type=Path, help='Resume an incomplete output directory')
    parser.add_argument('--cases', nargs='+', choices=CASES, default=DEFAULT_CASES)
    parser.add_argument('--settle', type=float, default=15)
    parser.add_argument('--close-delay', type=float, default=5)
    parser.add_argument('--late-close-delay', type=float, default=30,
                        help='Seconds after close for the final repeat; 0 disables the extra sample')
    args = parser.parse_args()
    assert args.repeats > 0 and min(args.settle, args.close_delay) >= 0
    assert args.late_close_delay == 0 or args.late_close_delay >= args.close_delay
    app = args.app.resolve()
    binary = app / 'Contents/MacOS/Leaflit'
    info = json.loads((app.parent / 'build-info.json').read_text())
    assert sha256(binary) == info['binarySHA256']
    assert not any(r['name'] == 'Leaflit' for r in processes().values()), 'Close Leaflit first'
    stamp = dt.datetime.now().astimezone().strftime('%Y%m%d-%H%M%S')
    out = args.resume.resolve() if args.resume else ROOT / 'build/memory-cases' / stamp
    if not args.resume:
        out.mkdir(parents=True)
    files = fixtures(out)
    file_hashes = {case: sha256(path) for case, path in files.items()}
    events = queue.Queue()
    log = subprocess.Popen(['/usr/bin/log', 'stream', '--style', 'ndjson', '--level', 'info',
        '--predicate', 'subsystem == "io.github.magicsih.leaflit" AND category == "performance"'],
        stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, bufsize=1)

    def read_events():
        for line in log.stdout:
            try:
                value = json.loads(line)
                if 'display phase=complete' in value.get('eventMessage', ''):
                    events.put(value)
            except json.JSONDecodeError:
                pass

    threading.Thread(target=read_events, daemon=True).start()
    result = {'startedAt': dt.datetime.now().astimezone().isoformat(),
              'app': info, 'macOS': subprocess.check_output(['sw_vers', '-productVersion'], text=True).strip(),
              'hardware': subprocess.check_output(['sysctl', '-n', 'hw.model'], text=True).strip(),
              'architecture': subprocess.check_output(['uname', '-m'], text=True).strip(),
              'hostMemoryAtStart': subprocess.check_output(['/usr/bin/memory_pressure', '-Q'], text=True).strip(),
              'repeats': args.repeats, 'settleSeconds': args.settle,
              'closeDelaySeconds': args.close_delay, 'lateCloseDelaySeconds': args.late_close_delay,
              'cases': args.cases,
              'fixtures': {case: {'bytes': path.stat().st_size, 'sha256': file_hashes[case]}
                           for case, path in files.items()},
              'attribution': 'Fresh app and new WebKit PIDs relative to the pre-launch baseline. '
                             'Abort on unrelated new app/WebKit PIDs. No concurrent UI automation.',
              'runs': []}
    if args.resume:
        previous = json.loads((out / 'results.json').read_text())
        for key in ['app', 'repeats', 'settleSeconds', 'closeDelaySeconds', 'lateCloseDelaySeconds']:
            assert previous[key] == result[key], f'Resume protocol mismatch: {key}'
        assert previous.get('cases', DEFAULT_CASES) == args.cases
        for case, value in previous['fixtures'].items():
            assert value['sha256'] == file_hashes[case], 'Resume fixture changed'
        result = previous
        result.setdefault('resumedAt', []).append(dt.datetime.now().astimezone().isoformat())
    completed = {(r['repeat'], r['case']) for r in result['runs']}
    active_pid = None
    try:
        time.sleep(1)
        for repeat in range(args.repeats):
            order = args.cases[repeat % len(args.cases):] + args.cases[:repeat % len(args.cases)]
            for case in order:
                if (repeat + 1, case) in completed:
                    continue
                baseline = processes()
                assert not any(p['name'] == 'Leaflit' for p in baseline.values())
                run_dir = out / f'{repeat + 1}-{case}'
                if run_dir.exists():
                    run_dir = out / f'{repeat + 1}-{case}-resumed-{stamp}'
                run_dir.mkdir()
                launched_at = time.time()
                command = ['/usr/bin/open', '-n', '-a', str(app)]
                if case != 'empty':
                    command.append(str(files[case]))
                subprocess.run(command, check=True)
                deadline = time.monotonic() + 15
                while time.monotonic() < deadline:
                    current = processes()
                    app_pids = [pid for pid, row in current.items() if row['path'] == str(binary)]
                    if len(app_pids) == 1:
                        active_pid = app_pids[0]
                        break
                    time.sleep(.1)
                assert active_pid, 'App launch timed out'
                deadline = time.monotonic() + 15
                while window_count(active_pid) != 1 and time.monotonic() < deadline:
                    time.sleep(.1)
                assert window_count(active_pid) == 1
                raise_window(active_pid)
                render_complete = None
                if case != 'empty':
                    deadline = time.monotonic() + 30
                    while time.monotonic() < deadline:
                        try:
                            event = events.get(timeout=min(1, max(.1, deadline - time.monotonic())))
                        except queue.Empty:
                            continue
                        if event['processID'] == active_pid:
                            event_time = dt.datetime.fromisoformat(event['timestamp']).timestamp()
                            if event_time >= launched_at:
                                render_complete = event['eventMessage']
                                break
                    assert render_complete, 'Document render timed out'
                ready_at = time.monotonic()
                time.sleep(args.settle)
                rows = {pid: row for pid, row in processes().items() if pid not in baseline}
                assert rows[active_pid]['path'] == str(binary)
                names = [row['name'] for row in rows.values()]
                assert set(names) == HELPERS | {'Leaflit'}, names
                assert len(names) == len(set(names)), 'Ambiguous helper process ownership'
                owned = set(rows)
                run = {'repeat': repeat + 1, 'case': case, 'renderCompleteEvent': render_complete,
                       'raisedWindowBeforeWait': True}
                run['loaded'] = samples(run_dir, 'loaded', baseline, owned, active_pid, ready_at)
                close_window(active_pid)
                closed_at = time.monotonic()
                time.sleep(args.close_delay)
                assert window_count(active_pid) == 0
                run['afterClose'] = samples(run_dir, 'closed', baseline, owned, active_pid, closed_at)
                if repeat == args.repeats - 1 and args.late_close_delay:
                    time.sleep(max(0, args.late_close_delay - (time.monotonic() - closed_at)))
                    assert window_count(active_pid) == 0
                    run['afterCloseLate'] = samples(run_dir, 'closed-late', baseline, owned, active_pid, closed_at)
                result['runs'].append(run)
                (out / 'results.json').write_text(json.dumps(result, indent=2) + '\n')
                print(f"{repeat + 1}/{args.repeats} {case}: loaded {run['loaded']['medianMiB']:.1f} MiB; "
                      f"window closed {run['afterClose']['medianMiB']:.1f} MiB", flush=True)
                os.kill(active_pid, signal.SIGTERM)
                active_pid = None
                deadline = time.monotonic() + 10
                while owned & set(processes()) and time.monotonic() < deadline:
                    time.sleep(.2)
                assert not owned & set(processes()), 'Launched helpers did not exit; do not reuse them'
                assert file_hashes == {case: sha256(path) for case, path in files.items()}
        result['completedAt'] = dt.datetime.now().astimezone().isoformat()
        result['hostMemoryAtEnd'] = subprocess.check_output(['/usr/bin/memory_pressure', '-Q'], text=True).strip()
        result['summary'] = {}
        for case in args.cases:
            runs = [r for r in result['runs'] if r['case'] == case]
            result['summary'][case] = {}
            for phase in ['loaded', 'afterClose', 'afterCloseLate']:
                values = [r[phase]['medianMiB'] for r in runs if phase in r]
                if values:
                    result['summary'][case][phase] = {'medianMiB': statistics.median(values),
                        'minMiB': min(values), 'maxMiB': max(values), 'runs': len(values)}
        (out / 'results.json').write_text(json.dumps(result, indent=2) + '\n')
        print(json.dumps(result['summary'], indent=2), flush=True)
        print(f'Results: {out.relative_to(ROOT)}/results.json', flush=True)
    finally:
        if active_pid is not None:
            try:
                os.kill(active_pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
        log.terminate()
        log.wait(timeout=5)


if __name__ == '__main__':
    main()
