#!/usr/bin/env python3
"""Measure sidebar cohorts without controlling UI or touching existing windows.

Each fresh process pauses at an explicit human/CUA readiness gate. Files requires
a real native folder choice. The ready subcommand records the operator's actual
observations; it cannot configure the app. Raw output stays under ignored build/.
"""
import argparse
import ctypes
import datetime as dt
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import plistlib
import queue
import re
import shutil
import signal
import statistics
import subprocess
import sys
import tempfile
import threading
import time


sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parent.parent
CASES = ['empty', 'plain1KiB', 'plain100KiB', 'benchmark100KiB']
COHORTS = ['hidden', 'Files', 'Outline']
HELPERS = {'com.apple.WebKit.WebContent', 'com.apple.WebKit.GPU',
           'com.apple.WebKit.Networking'}
FIXTURES = {
    'plain1KiB': (1024, '293c9cb423037c5007817852075acf1439a7134bcfb6a9aaaef1059f2f337ad2'),
    'plain100KiB': (102400, '6f89428d6f4e3ce1efcc1e90678e76158f3b5c48dcf02827eafa8febb624925e'),
    'benchmark100KiB': (102400, '55464dacf92db737fbec845a17723c38da683d0fcef0b52d994a0040edff7f61'),
}
PREFERENCE_KEYS = ['sidebar.mode', 'sidebar.visible', 'sidebar.width']


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def now():
    return dt.datetime.now(dt.timezone.utc).isoformat()


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n')


def build_fixtures(directory):
    """Reproduce the exact bytes retained by the approved 0.1.0 baseline."""
    directory.mkdir(parents=True, exist_ok=False)
    source = ROOT / 'scripts/measure-memory-cases.py'
    spec = importlib.util.spec_from_file_location('leaflit_memory_reference', source)
    reference = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(reference)
    # Keep the selected Files root at exactly three entries. Extra generated cases
    # stay in a newly owned temporary directory and never enter that root.
    with tempfile.TemporaryDirectory(prefix='leaflit-sidebar-fixtures-', dir=directory.parent) as temporary:
        generated = reference.fixtures(Path(temporary))
        for case, original in [('plain1KiB', 'short'), ('plain100KiB', 'prose'),
                               ('benchmark100KiB', 'combined')]:
            shutil.copy2(generated[original], directory / f'{case}.md')
    return fixture_metadata(directory)


def fixture_metadata(directory):
    require({path.name for path in directory.iterdir() if not path.name.startswith('.')} ==
            {f'{case}.md' for case in FIXTURES},
            'The matched Files root must contain exactly the three retained visible fixtures')
    result = {}
    for case, (size, expected) in FIXTURES.items():
        path = (directory / f'{case}.md').resolve(strict=True)
        require(path.stat().st_size == size and digest(path) == expected,
                f'Fixture bytes differ from the retained baseline: {path}')
        result[case] = {'path': str(path), 'bytes': size, 'sha256': expected}
    return result


def responsible_function():
    # Fail closed if this host does not expose the OS ownership function.
    system = ctypes.CDLL(None)
    function = system.responsibility_get_pid_responsible_for_pid
    function.argtypes = [ctypes.c_int]
    function.restype = ctypes.c_int
    return function


def processes(responsible):
    result = {}
    for row in subprocess.check_output(['/bin/ps', '-axo', 'pid=,rss=,comm='], text=True).splitlines():
        fields = row.strip().split(None, 2)
        if len(fields) != 3:
            continue
        pid, rss, path = fields
        name = Path(path).name
        if name == 'Leaflit' or name in HELPERS:
            pid = int(pid)
            result[pid] = {'pid': pid, 'name': name, 'rssKiB': int(rss),
                           'path': path, 'responsiblePID': responsible(pid)}
    return result


def start_token(pid):
    return subprocess.check_output(['/bin/ps', '-p', str(pid), '-o', 'lstart='], text=True).strip()


def stop_owned(pid, binary, token, responsible):
    row = processes(responsible).get(pid)
    if row is None:
        return
    require(row['path'] == str(binary) and row['responsiblePID'] == pid
            and start_token(pid) == token, 'Owned PID identity changed; will not terminate it')
    os.kill(pid, signal.SIGTERM)


def preserved_present(preserved, responsible):
    rows = processes(responsible)
    return all(pid in rows and rows[pid]['path'] == row['path']
               and start_token(pid) == row['startToken'] for pid, row in preserved.items())


def preferences(bundle_id):
    result = {}
    for key in PREFERENCE_KEYS:
        value = subprocess.run(['/usr/bin/defaults', 'read', bundle_id, key],
                               capture_output=True, text=True)
        result[key] = value.stdout.strip() if value.returncode == 0 else None
    return result


def footprint(directory, number, selected, app_pid, responsible, baseline, binary, token):
    rows = processes(responsible)
    require(app_pid in rows and rows[app_pid]['path'] == str(binary)
            and start_token(app_pid) == token, 'Owned app identity changed before footprint capture')
    current = {pid for pid, row in rows.items() if pid not in baseline
               and (pid == app_pid or row['name'] in HELPERS)
               and row['responsiblePID'] == app_pid}
    require(current == selected, 'Owned process set changed during sampling; retain evidence and stop')
    output = directory / f'footprint-{number}.json'
    command = ['/usr/bin/footprint', '-f', 'bytes', '--noCategories', '-j', str(output)]
    for pid in sorted(selected):
        command += ['-p', str(pid)]
    capture = subprocess.run(command, capture_output=True, text=True, timeout=20)
    (directory / f'footprint-{number}.txt').write_text(capture.stdout + capture.stderr)
    capture.check_returncode()
    value = json.loads(output.read_text())
    require(not value.get('errors'), f'footprint reported errors: {value.get("errors")}')
    require({row['pid'] for row in value['processes']} == selected,
            'footprint did not capture every attributed process')
    per_process = [{**rows[row['pid']], 'footprintBytes': row['footprint'],
                    'footprintMiB': row['footprint'] / 1048576} for row in value['processes']]
    return {'footprintMiB': value['total footprint'] / 1048576,
            'rssSumMiB': sum(rows[pid]['rssKiB'] for pid in selected) / 1024,
            'appFootprintMiB': sum(row['footprintMiB'] for row in per_process if row['pid'] == app_pid),
            'helperFootprintMiB': sum(row['footprintMiB'] for row in per_process if row['pid'] != app_pid),
            'processes': per_process, 'warnings': value.get('warnings', [])}


def acknowledge(args):
    request_path = args.request.resolve(strict=True)
    require(ROOT / 'build' in request_path.parents and request_path.name == 'gate-request.json',
            'Readiness requests must come from an owned run under build/')
    request = json.loads(request_path.read_text())
    require(args.pid == request['appPID'], 'The observed PID does not match the waiting run')
    expected_visible = request['cohort'] not in ['hidden', 'observedControl']
    require(args.visible == expected_visible and args.mode == request['requestedMode'],
            'Observed sidebar state differs from the requested cohort')
    require(args.window_size_unchanged and args.zoom == 1,
            'Keep this fresh window at its native initial size and 100% body zoom')
    require(request['case'] == 'empty' or args.content_ready,
            'Confirm the actual body and any required optional renderers before sampling')
    require(args.outer_width > 0 and args.outer_height > 0, 'Record observed outer window bounds')
    content = [args.content_x, args.content_y, args.content_width, args.content_height]
    require(all(value is None for value in content) or all(value is not None for value in content),
            'Supply all four actual content bounds, or omit them when they cannot be observed')
    if args.content_width is not None:
        require(args.content_width > 0 and args.content_height > 0, 'Observed content bounds must have positive size')
    if expected_visible:
        require(abs(args.sidebar_width - 230) <= 2, 'Use a 230pt sidebar, within 2pt')
    if request['cohort'] == 'Files':
        require(args.native_folder_choice and args.folder is not None,
                'Files requires an actual native folder choice in this new process')
        require(args.folder.resolve(strict=True) == Path(request['fixtureDirectory']),
                'The selected root must be the exact directory requested by this waiting run')
    else:
        require(args.folder is None and not args.native_folder_choice,
                'Do not select a folder for hidden or Outline cohorts')
    if request.get('requiresExpandedFolder'):
        require(args.expanded_folder is not None, 'Observe an actually expanded folder for the idle CPU run')
        expanded = args.expanded_folder.resolve(strict=True)
        root = Path(request['fixtureDirectory'])
        require(expanded.is_dir() and root in expanded.parents,
                'The observed expanded folder must be a child of the selected owned root')
    else:
        require(args.expanded_folder is None, 'Keep all directories collapsed in the matched memory set')
    evidence = args.evidence.resolve(strict=True)
    require(evidence.is_file() and request_path.parent in evidence.parents,
            'Save actual UI observation evidence inside this run directory before acknowledging')
    ready_path = request_path.with_name('ready.json')
    require(not ready_path.exists(), 'This run already has readiness evidence')
    write(ready_path, {**vars(args), 'request': str(request_path), 'folder': str(args.folder.resolve())
                      if args.folder else None, 'evidence': str(evidence), 'observedUTC': now(),
                      'expanded_folder': str(args.expanded_folder.resolve()) if args.expanded_folder else None,
                      'evidenceSHA256': digest(evidence), 'observationKind': 'human/CUA actual UI observation',
                      'observedOuterBounds': {'x': args.outer_x, 'y': args.outer_y,
                                              'width': args.outer_width, 'height': args.outer_height,
                                              'coordinateSpace': args.bounds_coordinate_space},
                      'observedContentBounds': None if args.content_width is None else {
                          'x': args.content_x, 'y': args.content_y,
                          'width': args.content_width, 'height': args.content_height},
                      'sourceDerivedInitialContentSize': request['sourceDerivedInitialContentSize']})
    print(ready_path, flush=True)


def summarize(runs):
    result = {}
    for cohort in dict.fromkeys([*COHORTS, *(run['cohort'] for run in runs)]):
        result[cohort] = {}
        for case in CASES:
            group = [run for run in runs if run['case'] == case and run['cohort'] == cohort]
            if not group:
                continue
            summary = {'runs': len(group), 'allHelpersAttributed': all(run['attribution']['unambiguous'] for run in group)}
            for metric in ['medianFootprintMiB', 'medianAppFootprintMiB', 'medianHelperFootprintMiB', 'medianRSSMiB']:
                values = [run[metric] for run in group]
                summary[metric] = {'median': statistics.median(values), 'min': min(values), 'max': max(values)}
            summary['initialLaunchLatency'] = {}
            for phase in ['body', 'complete']:
                summary['initialLaunchLatency'][phase] = None if case == 'empty' else {}
                if case != 'empty':
                    by_timing = {}
                    available = [run for run in group if run['initialLaunchLatency'][phase] is not None]
                    for timing in sorted({run['initialLaunchLatency'][phase]['timing'] for run in available}):
                        timed = [run['initialLaunchLatency'][phase] for run in group
                                 if run['initialLaunchLatency'][phase] is not None
                                 and run['initialLaunchLatency'][phase]['timing'] == timing]
                        by_timing[timing] = {'samples': len(timed)}
                        for metric in ['fromLaunchMs', 'fromOpenRequestMs']:
                            values = [sample[metric] for sample in timed]
                            by_timing[timing][metric] = {
                                'median': statistics.median(values), 'min': min(values), 'max': max(values)}
                    summary['initialLaunchLatency'][phase] = {'byTiming': by_timing,
                                                              'missingSamples': len(group) - len(available)}
            result[cohort][case] = summary
    return result


def coverage(runs, cohorts, control=False):
    expected = {(repeat, cohort, case) for repeat in range(1, 4)
                for cohort in (['observedControl'] if control else COHORTS) for case in CASES}
    actual = {(run['repeat'], run['cohort'], run['case']) for run in runs}
    full = len(runs) == len(expected) and actual == expected
    attributed = bool(runs) and all(run['attribution']['unambiguous'] for run in runs)
    return {'status': ('passed' if full else 'partial-cohort-coverage')
                      if attributed else 'partial-helper-attribution',
            'completePlanned36RunCoverage': full and not control,
            'completePlanned12ControlRunCoverage': full and control,
            'comparableAsAppPlusWebKit': attributed}


def collect_events(events, app_pid, launched_wall, latency, raw_events):
    """Drain available events without delaying the independent actual UI gate."""
    while True:
        try:
            event = events.get_nowait()
        except queue.Empty:
            return
        if event.get('processID') != app_pid:
            continue
        event_wall = dt.datetime.fromisoformat(event['timestamp']).timestamp()
        if event_wall < launched_wall:
            continue
        match = re.search(r'phase=(body|complete) ms=([\d.]+)', event['eventMessage'])
        if match:
            phase, native_ms = match.groups()
            timing = re.search(r'timing=(animationFrames|timerFallback)', event['eventMessage'])
            latency[phase] = {'fromLaunchMs': (event_wall - launched_wall) * 1000,
                              'fromOpenRequestMs': float(native_ms),
                              'timing': timing.group(1) if timing else 'unreported'}
            raw_events.append(event)


def measure(args):
    app = args.app.resolve(strict=True)
    bundle = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
    require(bundle['CFBundleIdentifier'] == 'io.github.magicsih.leaflit'
            and bundle['CFBundleExecutable'] == 'Leaflit', 'Use the exact Leaflit app bundle')
    binary = app / 'Contents/MacOS' / bundle['CFBundleExecutable']
    app_hash = digest(binary)
    provenance = args.control_manifest.resolve(strict=True) if args.control_manifest else app.parent / 'build-info.json'
    build_info = json.loads(provenance.read_text())
    require(build_info['binarySHA256'] == app_hash, 'Executable does not match build-info.json')
    require(build_info['version'] == bundle['CFBundleShortVersionString'], 'Bundle version differs from build-info.json')
    control = args.control_manifest is not None
    if control:
        require(bundle['CFBundleShortVersionString'] == '0.1.0'
                and build_info['bundleId'] == bundle['CFBundleIdentifier'],
                'The observation-matched public control must be the provenanced 0.1.0 app')
        args.cohorts = ['observedControl']
    fixture_info = fixture_metadata(args.fixtures.resolve(strict=True))
    fixture_dir = args.fixtures.resolve()
    baseline_protocol = None
    paths_match = None
    if args.baseline:
        baseline = json.loads(args.baseline.resolve(strict=True).read_text())
        require(baseline['status'] == 'passed' and baseline['comparableAsAppPlusWebKit'],
                'Use the complete responsibility-attributed baseline dataset')
        sibling = args.baseline.resolve().with_name('protocol.json')
        protocol_path = sibling if sibling.is_file() else Path(baseline['protocolPath'])
        baseline_protocol = json.loads(protocol_path.read_text())
        require(baseline_protocol['settleSeconds'] == 15 and baseline_protocol['samplesPerRun'] == 3
                and baseline_protocol['repeatsPerCase'] == 3, 'Baseline sampling protocol differs')
        require(all(baseline_protocol['fixtures'][case]['sha256'] == value['sha256']
                    for case, value in fixture_info.items()), 'Baseline fixture hashes differ')
        paths_match = all(baseline_protocol['fixtures'][case]['path'] == value['path']
                          for case, value in fixture_info.items())
    if args.require_original_fixture_paths:
        require(paths_match is True, 'Use the exact retained baseline fixture paths for this local comparison')
    responsible = responsible_function()
    initial = processes(responsible)
    preserved = {pid: {**row, 'startToken': start_token(pid)} for pid, row in initial.items() if row['name'] == 'Leaflit'}
    out = args.output.resolve()
    require(out == ROOT / 'build' or ROOT / 'build' in out.parents, 'Evidence must stay under build/')
    out.mkdir(parents=True, exist_ok=False)
    shutil.copy2(__file__, out / 'measure-sidebar.py')
    before_preferences = preferences(bundle['CFBundleIdentifier'])
    protocol = {
        'startedUTC': now(), 'app': str(app), 'appVersion': build_info['version'],
        'sourceSHA': build_info['sourceSHA'], 'binarySHA256': app_hash,
        'provenanceFile': str(provenance), 'provenanceSHA256': digest(provenance),
        'observerCondition': 'One initial CUA AX observation via exact-app binding or the retained exact-path target, '
                             'plus one full AX/screenshot readiness capture; '
                             'Files additionally requires native chooser observations. No further app observations during settling/sampling.',
        'protocolRevision': 'observation-first-v2',
        'control': control,
        'baselineResults': str(args.baseline.resolve()) if args.baseline else None,
        'baselineResultsSHA256': digest(args.baseline) if args.baseline else None,
        'fixturePathsMatchBaseline': paths_match,
        'fixtureGeneratorSHA256': digest(ROOT / 'scripts/measure-memory-cases.py'),
        'harnessSHA256': digest(Path(__file__)),
        'fixtures': fixture_info, 'cohorts': args.cohorts, 'cases': CASES,
        'repeatsPerCaseAndCohort': 3, 'settleSecondsAfterReadyGate': 15,
        'samplesPerRun': 3, 'sampleIntervalSeconds': .5,
        'ownership': 'Establish the exact new app PID first; include only new WebKit helper PIDs whose '
                     'Darwin responsiblePID equals that app PID. Recheck ownership at every sample. '
                     'Exclude unknown/unrelated helpers and mark incomplete attribution separately.',
        'sidebarLaunchPositionArgument': None if control else args.sidebar_position,
        'initialLaunchState': ('Public 0.1.0 has no sidebar and receives no sidebar launch arguments.' if control else
                              'NSArgumentDomain requests the cohort mode/visibility and explicit divider position. '
                              'No selected folder exists at launch. The ready gate confirms actual UI afterward.'),
        'geometry': 'Keep the fresh native window size unchanged. Record actual observed outer bounds '
                    'separately from optional observed content bounds. Initial 900x700 content size is '
                    'derived from source, not an observation; never enter it as measured CUA bounds.',
        'latency': 'Body/complete events retain the original fixture-launch timestamps. '
                   'Both wall-clock launch ms and native document-open ms are retained. '
                   'The log stream is asynchronous and never blocks the UI gate; a phase can arrive during '
                   'or after observation. Retain its original timestamp. Missing events remain missing '
                   'with cause unconfirmed, independently of memory coverage. Empty is N/A.',
        'memory': 'After actual UI verification (and native folder choice for Files), wait 15 seconds, '
                  'take three footprint captures 0.5 seconds apart, and report app, owned helpers and RSS separately.',
        'ordering': 'For each fresh repeat rotate cohort order and case order by one; no cache flush.',
        'cleanup': 'SIGTERM only the new exact-path app PID with unchanged start token. Never terminate '
                   'pre-existing apps or helpers; wait for attributed helpers to exit.',
        'ui': 'Only human/CUA input may configure or inspect the new app. No AppleScript, responder call, '
              'product test API, broad folder scan or preference write is performed by this tool.',
        'persistentPreferencesBefore': before_preferences,
        'preferenceLimit': 'The app itself may persist native layout changes. Report before/after keys; '
                           'do not blindly restore a whole preference domain over user state.',
        'preservedAppProcesses': list(preserved.values()),
        'environment': {key: subprocess.check_output(command, text=True).strip() for key, command in {
            'macOS': ['sw_vers', '-productVersion'], 'macOSBuild': ['sw_vers', '-buildVersion'],
            'architecture': ['uname', '-m'], 'hardwareModel': ['sysctl', '-n', 'hw.model']}.items()},
    }
    write(out / 'protocol.json', protocol)
    events = queue.Queue()
    stream = subprocess.Popen(['/usr/bin/log', 'stream', '--style', 'ndjson', '--level', 'info',
        '--predicate', 'subsystem == "io.github.magicsih.leaflit" AND category == "performance"'],
        stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, bufsize=1)

    def read_events():
        for line in stream.stdout:
            try:
                event = json.loads(line)
                if 'display phase=' in event.get('eventMessage', ''):
                    events.put(event)
            except json.JSONDecodeError:
                pass

    threading.Thread(target=read_events, daemon=True).start()
    result = {'protocolPath': str(out / 'protocol.json'), 'status': 'running', 'runs': []}
    active_pid = None
    active_token = None
    try:
        time.sleep(1)
        for repeat in range(3):
            cohorts = args.cohorts[repeat % len(args.cohorts):] + args.cohorts[:repeat % len(args.cohorts)]
            cases = CASES[repeat % len(CASES):] + CASES[:repeat % len(CASES)]
            for cohort in cohorts:
                for case in cases:
                    before = processes(responsible)
                    run_dir = out / f'{repeat + 1}-{cohort}-{case}'
                    run_dir.mkdir()
                    mode = 'none' if control else ('Outline' if cohort == 'Outline' else 'Files')
                    command = ['/usr/bin/open', '-n', '-a', str(app)]
                    if case != 'empty':
                        command.append(fixture_info[case]['path'])
                    if not control:
                        command += ['--args', '-sidebar.mode', mode, '-sidebar.visible',
                                    'NO' if cohort == 'hidden' else 'YES', '-sidebar.width', str(args.sidebar_position)]
                    launched_wall, launched_mono = time.time(), time.monotonic()
                    result['pendingRun'] = {'repeat': repeat + 1, 'cohort': cohort, 'case': case,
                                            'launchUTC': now(), 'launchCommand': command}
                    write(out / 'results.json', result)
                    subprocess.run(command, check=True, timeout=15)
                    deadline = time.monotonic() + 15
                    while time.monotonic() < deadline:
                        rows = processes(responsible)
                        new = [pid for pid, row in rows.items() if pid not in before and row['path'] == str(binary)]
                        require(len(new) < 2, 'Ambiguous newly launched app PID; stop without choosing one')
                        if new:
                            active_pid = new[0]
                            active_token = start_token(active_pid)
                            break
                        time.sleep(.1)
                    require(active_pid is not None, 'New app PID was not established')
                    result['pendingRun']['appPID'] = active_pid
                    established_ms = (time.monotonic() - launched_mono) * 1000
                    write(out / 'results.json', result)
                    latency = {'body': None, 'complete': None}
                    raw_events = []
                    collect_events(events, active_pid, launched_wall, latency, raw_events)
                    write(run_dir / 'display-events.json', raw_events)
                    request = {'createdUTC': now(), 'appPID': active_pid, 'appPath': str(app),
                               'cohort': cohort, 'requestedMode': mode, 'case': case,
                               'document': fixture_info[case]['path'] if case != 'empty' else None,
                               'fixtureDirectory': str(fixture_dir),
                               'sourceDerivedInitialContentSize': {'width': 900, 'height': 700,
                                   'basis': 'ReaderController NSWindow(contentRect:); not UI-measured'},
                               'keepNativeInitialWindowSize': True, 'sidebarWidth': 0 if control else 230, 'zoom': 1,
                               'readyInstruction': 'Observe only this new PID with CUA/human input immediately, '
                                                   'without waiting for display-log events. Confirm actual body '
                                                   'and optional renderers (empty is N/A). Files: '
                                                   'choose the exact fixture directory through the native '
                                                   'Open Folder panel. Verify actual UI, save evidence, then '
                                                   'use the ready subcommand. Do not change the document.'}
                    request_path = run_dir / 'gate-request.json'
                    write(request_path, request)
                    print(f'WAITING: {request_path} (PID {active_pid}, {cohort}, {case})', flush=True)
                    deadline = time.monotonic() + args.gate_timeout
                    ready_path = run_dir / 'ready.json'
                    while not ready_path.exists() and time.monotonic() < deadline:
                        require(active_pid in processes(responsible), 'The waiting owned app exited')
                        collect_events(events, active_pid, launched_wall, latency, raw_events)
                        time.sleep(.2)
                    require(ready_path.exists(), 'Readiness gate timed out; no memory pass recorded')
                    ready = json.loads(ready_path.read_text())
                    require(ready['pid'] == active_pid and ready['mode'] == mode
                            and ready['visible'] == (cohort not in ['hidden', 'observedControl']), 'Readiness evidence does not match this run')
                    if result['runs']:
                        first = result['runs'][0]['readyEvidence']['observedOuterBounds']
                        current = ready['observedOuterBounds']
                        require(all(abs(current[key] - first[key]) <= 2 for key in ['width', 'height']),
                                'Observed outer window size changed between runs; resolve geometry before sampling')
                    ready_mono = time.monotonic()
                    time.sleep(15)
                    rows = processes(responsible)
                    require(rows[active_pid]['path'] == str(binary)
                            and rows[active_pid]['responsiblePID'] == active_pid, 'App identity/ownership changed')
                    candidates = {pid: row for pid, row in rows.items() if pid not in before and row['name'] in HELPERS}
                    helpers = {pid: row for pid, row in candidates.items() if row['responsiblePID'] == active_pid}
                    unresolved = {pid: row for pid, row in candidates.items() if row['responsiblePID'] <= 0}
                    selected = {active_pid} | set(helpers)
                    attribution = {'method': 'new helper PID with responsiblePID equal to exact new app PID',
                                   'unambiguous': bool(helpers) and not unresolved,
                                   'ownedHelpers': list(helpers.values()),
                                   'excludedUnresolvedHelpers': list(unresolved.values()),
                                   'excludedUnrelatedHelpers': [row for row in candidates.values()
                                                               if row['responsiblePID'] > 0 and row['responsiblePID'] != active_pid],
                                   'selectedPIDs': sorted(selected)}
                    run = {'repeat': repeat + 1, 'cohort': cohort, 'case': case, 'appPID': active_pid,
                           'launchUTC': dt.datetime.fromtimestamp(launched_wall, dt.timezone.utc).isoformat(),
                           'processEstablishedMs': established_ms,
                           'launchCommand': command, 'initialLaunchLatency': latency,
                           'latencyLimit': 'No selected root at launch. Events can arrive before, during or after '
                                           'native folder choice and actual UI readiness; retain original timestamps.',
                           'readyEvidence': ready, 'secondsFromLaunchToReady': ready_mono - launched_mono,
                           'attribution': attribution, 'samples': []}
                    for number in range(1, 4):
                        if number > 1:
                            time.sleep(.5)
                        sample = footprint(run_dir, number, selected, active_pid, responsible, before, binary, active_token)
                        sample['secondsSinceReady'] = time.monotonic() - ready_mono
                        run['samples'].append(sample)
                    for label, metric in [('medianFootprintMiB', 'footprintMiB'),
                                          ('medianAppFootprintMiB', 'appFootprintMiB'),
                                          ('medianHelperFootprintMiB', 'helperFootprintMiB'),
                                          ('medianRSSMiB', 'rssSumMiB')]:
                        run[label] = statistics.median(sample[metric] for sample in run['samples'])
                    collect_events(events, active_pid, launched_wall, latency, raw_events)
                    write(run_dir / 'display-events.json', raw_events)
                    run['latencyCompleteness'] = 'not-applicable' if case == 'empty' else (
                        'complete' if all(latency.values()) else 'missing-events-cause-unconfirmed')
                    write(run_dir / 'run.json', run)
                    result['runs'].append(run)
                    result.pop('pendingRun', None)
                    write(out / 'results.json', result)
                    print(f"CAPTURED {repeat + 1}/3 {cohort} {case}: {run['medianFootprintMiB']:.2f} MiB", flush=True)
                    stop_owned(active_pid, binary, active_token, responsible)
                    active_pid = None
                    deadline = time.monotonic() + 10
                    while selected & set(processes(responsible)) and time.monotonic() < deadline:
                        time.sleep(.2)
                    require(not selected & set(processes(responsible)), 'Owned processes remain; stop before another launch')
                    require(preserved_present(preserved, responsible), 'A pre-existing user app process disappeared')
                    require(digest(binary) == app_hash, 'The candidate executable changed')
                    fixture_metadata(fixture_dir)
        result.update(**coverage(result['runs'], args.cohorts, control),
                      baselineComparisonAvailable=args.baseline is not None,
                      summary=summarize(result['runs']),
                      completedUTC=now(), preExistingAppProcessesStillPresent=list(preserved))
        result['latencyCompleteness'] = {status: sum(run['latencyCompleteness'] == status for run in result['runs'])
                                       for status in ['complete', 'not-applicable', 'missing-events-cause-unconfirmed']}
    except BaseException as error:
        result.update(status='failed', error=f'{type(error).__name__}: {error}', failedUTC=now())
        raise
    finally:
        cleanup_errors = []
        try:
            if active_pid is not None:
                owned = {active_pid} | {pid for pid, row in processes(responsible).items()
                                        if row['name'] in HELPERS and row['responsiblePID'] == active_pid}
                stop_owned(active_pid, binary, active_token, responsible)
                deadline = time.monotonic() + 10
                while owned & set(processes(responsible)) and time.monotonic() < deadline:
                    time.sleep(.2)
                require(not owned & set(processes(responsible)), 'Owned measurement processes remain')
            require(preserved_present(preserved, responsible), 'A pre-existing user app process disappeared')
        except Exception as error:
            cleanup_errors.append(f'Owned app cleanup: {type(error).__name__}: {error}')
        try:
            stream.terminate()
            stream.wait(timeout=5)
        except Exception as error:
            cleanup_errors.append(f'Owned log stream cleanup: {type(error).__name__}: {error}')
        result['persistentPreferencesAfter'] = preferences(bundle['CFBundleIdentifier'])
        result['persistentPreferenceChanges'] = {key: {'before': before_preferences[key], 'after': value}
                                               for key, value in result['persistentPreferencesAfter'].items()
                                               if before_preferences[key] != value}
        if cleanup_errors:
            result['cleanupErrors'] = cleanup_errors
            result['status'] = 'failed'
        write(out / 'results.json', result)
        print(f'Evidence retained: {out}', flush=True)
        if cleanup_errors:
            raise RuntimeError('; '.join(cleanup_errors))


def cpu_seconds(value):
    days, clock = value.split('-', 1) if '-' in value else ('0', value)
    total = 0.0
    for field in clock.split(':'):
        total = total * 60 + float(field)
    return int(days) * 86400 + total


def idle_cpu(args):
    """Take one separate 60-second counter sample after a real expanded-tree gate."""
    app = args.app.resolve(strict=True)
    bundle = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
    require(bundle['CFBundleIdentifier'] == 'io.github.magicsih.leaflit'
            and bundle['CFBundleExecutable'] == 'Leaflit', 'Use the exact Leaflit app bundle')
    binary = app / 'Contents/MacOS' / bundle['CFBundleExecutable']
    app_hash = digest(binary)
    info = json.loads((app.parent / 'build-info.json').read_text())
    require(info['binarySHA256'] == app_hash, 'Executable differs from build-info.json')
    root, document = args.root.resolve(strict=True), args.document.resolve(strict=True)
    require(ROOT / 'build' in root.parents and root.is_dir() and root in document.parents,
            'Use a reviewer-owned root and document under build/')
    document_hash = digest(document)
    out = args.output.resolve()
    require(ROOT / 'build' in out.parents, 'CPU evidence must stay under build/')
    out.mkdir(parents=True, exist_ok=False)
    shutil.copy2(__file__, out / 'measure-sidebar.py')
    responsible = responsible_function()
    before = processes(responsible)
    preserved = {pid: {**row, 'startToken': start_token(pid)} for pid, row in before.items() if row['name'] == 'Leaflit'}
    before_preferences = preferences(bundle['CFBundleIdentifier'])
    result = {'status': 'running', 'purpose': 'One separate Files-expanded idle CPU sample',
              'startedUTC': now(), 'sourceSHA': info['sourceSHA'], 'binarySHA256': app_hash,
              'appPath': str(app), 'root': str(root), 'document': str(document),
              'documentSHA256': document_hash, 'harnessSHA256': digest(Path(__file__)),
              'requestedIdleSeconds': 60, 'sampleIntervalSeconds': 5, 'settleSecondsAfterReady': 15,
              'method': 'Read cumulative ps CPU-time counters for the stable owned process set at 0 and 60 '
                        'seconds, retaining 5-second samples. CPU percent is counter delta / actual elapsed '
                        'wall time * 100, with one fully occupied logical CPU equal to 100%. '
                        'Retain ps percent separately; it is not the primary idle metric.',
              'persistentPreferencesBefore': before_preferences,
              'preservedAppProcesses': list(preserved.values()), 'samples': []}
    write(out / 'results.json', result)
    active_pid, token, selected = None, None, set()
    try:
        command = ['/usr/bin/open', '-n', '-a', str(app), str(document), '--args',
                   '-sidebar.mode', 'Files', '-sidebar.visible', 'YES', '-sidebar.width', str(args.sidebar_position)]
        result['launchCommand'] = command
        subprocess.run(command, check=True, timeout=15)
        deadline = time.monotonic() + 15
        while time.monotonic() < deadline:
            new = [pid for pid, row in processes(responsible).items() if pid not in before and row['path'] == str(binary)]
            require(len(new) < 2, 'Ambiguous new app PID; stop without choosing one')
            if new:
                active_pid, token = new[0], start_token(new[0])
                break
            time.sleep(.1)
        require(active_pid is not None, 'New CPU cohort app PID was not established')
        result['appPID'] = active_pid
        request = {'createdUTC': now(), 'appPID': active_pid, 'appPath': str(app),
                   'cohort': 'Files', 'requestedMode': 'Files', 'case': 'idle-expanded',
                   'document': str(document), 'fixtureDirectory': str(root),
                   'requiresExpandedFolder': True, 'keepNativeInitialWindowSize': True,
                   'sourceDerivedInitialContentSize': {'width': 900, 'height': 700,
                       'basis': 'ReaderController NSWindow(contentRect:); not UI-measured'},
                   'sidebarWidth': 230, 'zoom': 1,
                   'readyInstruction': 'Choose the owned root through the native Open Folder panel, '
                                       'expand a nested folder using actual input, wait for stable rows '
                                       'and the complete document, then save actual UI evidence. '
                                       'Use ready with --expanded-folder. Leave it completely idle afterward.'}
        request_path, ready_path = out / 'gate-request.json', out / 'ready.json'
        write(request_path, request)
        write(out / 'results.json', result)
        print(f'WAITING: {request_path} (PID {active_pid}, Files expanded, 60s idle CPU)', flush=True)
        deadline = time.monotonic() + args.gate_timeout
        while not ready_path.exists() and time.monotonic() < deadline:
            require(active_pid in processes(responsible), 'Waiting CPU cohort app exited')
            time.sleep(.2)
        require(ready_path.exists(), 'CPU readiness gate timed out')
        ready = json.loads(ready_path.read_text())
        require(ready['pid'] == active_pid and ready['native_folder_choice']
                and ready['expanded_folder'], 'CPU readiness evidence does not match this run')
        result['readyEvidence'] = ready
        time.sleep(15)
        rows = processes(responsible)
        helpers = {pid: row for pid, row in rows.items() if pid not in before and row['name'] in HELPERS
                   and row['responsiblePID'] == active_pid}
        unresolved = [row for pid, row in rows.items() if pid not in before and row['name'] in HELPERS
                      and row['responsiblePID'] <= 0]
        result['attribution'] = {'method': 'new helper PID with responsiblePID equal to exact new app PID',
                                 'ownedHelpers': list(helpers.values()), 'excludedUnresolvedHelpers': unresolved}
        require(helpers and not unresolved, 'CPU helper attribution is incomplete; no comparable CPU result')
        selected = {active_pid} | set(helpers)
        tokens = {pid: start_token(pid) for pid in selected}
        result['attribution']['selectedPIDs'] = sorted(selected)
        origin = None
        for number in range(13):
            if number > 0:
                time.sleep(max(0, origin + number * 5 - time.monotonic()))
            rows = processes(responsible)
            current = {pid for pid, row in rows.items() if pid not in before
                       and (pid == active_pid or row['name'] in HELPERS)
                       and row['responsiblePID'] == active_pid}
            require(current == selected and rows[active_pid]['path'] == str(binary)
                    and all(start_token(pid) == tokens[pid] for pid in selected),
                    'Owned CPU process set or identity changed; retain failed samples and stop')
            raw = subprocess.check_output(['/bin/ps', '-p', ','.join(map(str, sorted(selected))),
                                           '-o', 'pid=,time=,%cpu='], text=True,
                                          env={**os.environ, 'LC_ALL': 'C'})
            (out / f'cpu-{number:02d}.txt').write_text(raw)
            captured = time.monotonic()
            if origin is None:
                origin = captured
            per_process = []
            for line in raw.splitlines():
                pid, counter, percent = line.split()
                per_process.append({**rows[int(pid)], 'cpuTimeSeconds': cpu_seconds(counter),
                                    'psPercentCPU': float(percent)})
            require({row['pid'] for row in per_process} == selected, 'A CPU counter was not captured')
            sample = {'capturedUTC': now(), 'secondsSinceSamplingStart': captured - origin,
                      'processes': per_process}
            result['samples'].append(sample)
            write(out / 'results.json', result)
        first, last = result['samples'][0], result['samples'][-1]
        elapsed = last['secondsSinceSamplingStart'] - first['secondsSinceSamplingStart']
        require(elapsed >= 60, 'CPU sampling did not cover the requested minute')
        counters = {row['pid']: row['cpuTimeSeconds'] for row in first['processes']}
        deltas = [{**row, 'cpuSecondsDuringInterval': row['cpuTimeSeconds'] - counters[row['pid']]}
                  for row in last['processes']]
        require(all(row['cpuSecondsDuringInterval'] >= 0 for row in deltas), 'CPU counters moved backward')
        total = sum(row['cpuSecondsDuringInterval'] for row in deltas)
        result.update(status='passed', completedUTC=now(), observedIdleSeconds=elapsed,
                      cpuSeconds=total, cpuPercentOneCore=total / elapsed * 100,
                      appCPUSeconds=sum(row['cpuSecondsDuringInterval'] for row in deltas if row['pid'] == active_pid),
                      helperCPUSeconds=sum(row['cpuSecondsDuringInterval'] for row in deltas if row['pid'] != active_pid),
                      processDeltas=deltas)
        require(digest(binary) == app_hash and digest(document) == document_hash,
                'CPU cohort executable or document changed')
    except BaseException as error:
        result.update(status='failed', error=f'{type(error).__name__}: {error}', failedUTC=now())
        raise
    finally:
        try:
            if active_pid is not None:
                selected |= {pid for pid, row in processes(responsible).items()
                             if row['name'] in HELPERS and row['responsiblePID'] == active_pid}
                stop_owned(active_pid, binary, token, responsible)
                deadline = time.monotonic() + 10
                while ({active_pid} | selected) & set(processes(responsible)) and time.monotonic() < deadline:
                    time.sleep(.2)
                require(not ({active_pid} | selected) & set(processes(responsible)), 'Owned CPU cohort processes remain')
            require(preserved_present(preserved, responsible), 'A pre-existing user app process disappeared')
        except Exception as error:
            result.update(status='failed', cleanupError=f'{type(error).__name__}: {error}')
        result['persistentPreferencesAfter'] = preferences(bundle['CFBundleIdentifier'])
        result['persistentPreferenceChanges'] = {key: {'before': before_preferences[key], 'after': value}
                                               for key, value in result['persistentPreferencesAfter'].items()
                                               if before_preferences[key] != value}
        write(out / 'results.json', result)
        print(f'CPU evidence retained: {out}', flush=True)
    require(result['status'] == 'passed', 'CPU cohort cleanup failed; see retained evidence')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    prepare = commands.add_parser('prepare-fixtures', help='Reproduce retained baseline bytes without launching an app')
    prepare.add_argument('--output', type=Path, required=True)
    run = commands.add_parser('run', help='Launch fresh apps, waiting for actual human/CUA observations')
    run.add_argument('--app', type=Path, required=True)
    run.add_argument('--control-manifest', type=Path,
                     help='Use a verified public 0.1.0 release manifest and a separate 12-run observation-matched control')
    run.add_argument('--baseline', type=Path, help='Complete baseline results.json, when available on this host')
    run.add_argument('--fixtures', type=Path, required=True, help='Hash-verified retained or reproduced fixture directory')
    run.add_argument('--require-original-fixture-paths', action='store_true',
                     help='Local matched comparison: require exact original paths as well as bytes')
    run.add_argument('--output', type=Path, required=True, help='New evidence directory under build/')
    run.add_argument('--cohorts', nargs='+', choices=COHORTS, default=COHORTS)
    run.add_argument('--sidebar-position', type=float, default=230,
                     help='Native divider-position preference; calibrate actual visible pane to 230pt before sampling')
    run.add_argument('--gate-timeout', type=float, default=600, help='Seconds to await each explicit UI readiness gate')
    cpu = commands.add_parser('idle-cpu', help='One fresh Files-expanded process, actual UI gate, then 60 idle seconds')
    cpu.add_argument('--app', type=Path, required=True)
    cpu.add_argument('--root', type=Path, required=True, help='Reviewer-owned folder under build/')
    cpu.add_argument('--document', type=Path, required=True, help='Stable document within that owned folder')
    cpu.add_argument('--output', type=Path, required=True)
    cpu.add_argument('--gate-timeout', type=float, default=600)
    cpu.add_argument('--sidebar-position', type=float, default=230)
    ready = commands.add_parser('ready', help='Record actual UI observations for one waiting process')
    ready.add_argument('--request', type=Path, required=True)
    ready.add_argument('--pid', type=int, required=True)
    ready.add_argument('--mode', choices=['Files', 'Outline', 'none'], required=True)
    ready.add_argument('--visible', action=argparse.BooleanOptionalAction, required=True)
    ready.add_argument('--window-size-unchanged', action='store_true',
                       help='Attest this fresh native window has not been resized')
    for key in ['x', 'y', 'width', 'height']:
        ready.add_argument(f'--outer-{key}', type=float, required=True,
                           help=f'Actually observed native outer window {key} in pt')
        ready.add_argument(f'--content-{key}', type=float,
                           help=f'Optional actually observed content {key}; never infer from source')
    ready.add_argument('--sidebar-width', type=float, default=0)
    ready.add_argument('--bounds-coordinate-space', choices=['window-capture-relative', 'screen'],
                       default='window-capture-relative', help='Coordinate system of the actual observed outer bounds')
    ready.add_argument('--zoom', type=float, required=True)
    ready.add_argument('--content-ready', action='store_true',
                       help='Attest actual body and necessary optional renderers were observed; empty is N/A')
    ready.add_argument('--folder', type=Path)
    ready.add_argument('--native-folder-choice', action='store_true')
    ready.add_argument('--expanded-folder', type=Path, help='Actual expanded child folder, for the separate idle CPU gate only')
    ready.add_argument('--observer', required=True)
    ready.add_argument('--evidence', type=Path, required=True, help='Saved actual screenshot or accessibility observation')
    args = parser.parse_args()
    if args.command == 'prepare-fixtures':
        output = args.output.resolve()
        require(ROOT / 'build' in output.parents, 'Generated fixtures must stay under build/')
        print(json.dumps(build_fixtures(output), indent=2))
    elif args.command == 'ready':
        acknowledge(args)
    elif args.command == 'idle-cpu':
        require(args.gate_timeout > 0 and 180 <= args.sidebar_position <= 320, 'Invalid CPU gate options')
        idle_cpu(args)
    else:
        require(args.gate_timeout > 0 and 180 <= args.sidebar_position <= 320
                and len(set(args.cohorts)) == len(args.cohorts), 'Invalid run options')
        measure(args)


if __name__ == '__main__':
    main()
