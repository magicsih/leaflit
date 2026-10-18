# Matched sidebar memory protocol

This protocol supports the approved [Files and Outline L3 test plan](../design/navigation-sidebar/test-plan.json). Preparing this tool is not measurement evidence. Execute it only during an exclusive app/UI handoff, separately from rendered review actions and builds. The full set is four cases, three cohorts and three fresh repeats: **36 processes**, normally about **20–30 minutes**, plus separate large-folder and large-outline UI checks.

## Retained baseline

The complete public 0.1.0 baseline is `build/sidebar-baseline/20261019-065043/results.json`. Its original executable was `/Applications/Leaflit.app`, source `af15d5d01d0f11e3c4558c793fad43da3c7fc082`, binary SHA-256 `20f04c5661b030955ee4e22b041062fbf9ffa244c82ecd16a1efcbf59e45a933`. The earlier `20261019-064359` dataset has incomplete helper attribution and must not substitute for this baseline.

Use the exact retained fixture directory `build/sidebar-baseline/20261019-065043/fixtures`. Do not rewrite it or create folder-load fixtures inside it.

| Case | Bytes | SHA-256 |
| --- | ---: | --- |
| empty | N/A | No document; display latency is N/A |
| plain1KiB.md | 1,024 | `293c9cb423037c5007817852075acf1439a7134bcfb6a9aaaef1059f2f337ad2` |
| plain100KiB.md | 102,400 | `6f89428d6f4e3ce1efcc1e90678e76158f3b5c48dcf02827eafa8febb624925e` |
| benchmark100KiB.md | 102,400 | `55464dacf92db737fbec845a17723c38da683d0fcef0b52d994a0040edff7f61` |

The benchmark is byte-identical to `Fixtures/Benchmark100KiB.md`. The retained directory is a local option, not a required path on every host. To recreate the exact bytes on another host, the tool imports the existing memory-case generator and verifies every hash:

```sh
python3 scripts/measure-sidebar.py prepare-fixtures --output build/sidebar-fixtures
```

Use `--fixtures build/sidebar-fixtures` for a portable run. A copied complete baseline dataset can be supplied through `--baseline`; without it, the tool records a new dataset without claiming a matched baseline comparison. Different fixture paths are recorded explicitly. The current same-host comparison retains the original paths and opts into the stricter path check below.

## Execute the matched set

Record the exact independently verified candidate and its `build-info.json` first. Preserve all pre-existing Leaflit processes and windows, including older Release and DerivedData apps. Never use a process-name-wide quit or kill. Launch the runner in a terminal or tool session with unbuffered output:

```sh
python3 -u scripts/measure-sidebar.py run \
  --app build/Leaflit-0.2.0/Leaflit.app \
  --baseline build/sidebar-baseline/20261019-065043/results.json \
  --fixtures build/sidebar-baseline/20261019-065043/fixtures \
  --require-original-fixture-paths \
  --output build/sidebar-measurements/REPLACE_WITH_CANDIDATE_AND_TIMESTAMP
```

The output directory must be new and under ignored `build/`. The runner uses `/usr/bin/open -n -a` with the exact app path and optional fixture. Standard Foundation argument-domain values request `sidebar.mode`, `sidebar.visible` and a 230pt width. These are existing application preferences, not product test hooks. They do not select or restore a folder. Each run starts with no selected root.

For every `WAITING` line, read its `gate-request.json` and establish the exact new app PID in CUA. Observe only that owned window. Keep the fresh window at its native initial size, 100% document zoom, its initial document and default reading position. Do not run UI regression, search, scroll, resize experiments or source mutations during the memory cohort. For visible cohorts record the actual pane width and keep it at 230pt, within 2pt. If that observed width differs from the requested preference, resolve the cause and correct the protocol before capturing memory.

CUA's AXWindow bounds can describe the outer frame, including native title and toolbar areas. Record those actual outer bounds through the four `--outer-*` options. The app's initial 900×700 content rectangle is a source-derived value; do not enter it as an observed height. Supply the optional four `--content-*` values only when the actual content bounds are available in runtime evidence, otherwise omit them. The tool keeps source-derived and observed geometry separate and stops if observed outer width or height changes by more than 2pt between runs. The original baseline also kept its default native window; it did not measure outer geometry.

1. **hidden:** verify the sidebar is actually hidden. Do not select a folder.
2. **Files:** verify Files is visible. Use File > Open Folder or the sidebar's Open Folder button, and choose the exact retained fixture directory in the native chooser. Wait until its three Markdown rows are visible and loading has ended. For document cases verify the already-open fixture is selected. For empty verify no document was opened. Leave every directory collapsed.
3. **Outline:** verify Outline is visible for the already-open fixture. Wait until the headings or appropriate empty state appear. Keep its default expanded groups and the initial reading position. Do not select a folder or navigate to a heading.

Save a screenshot or accessibility observation showing the actual state, observed outer bounds, visible pane bounds and PID under that run's evidence directory. Supply the observations explicitly to `ready`; that command records them and performs no app control. For example, replace all placeholders with actual values from the pending run:

```sh
python3 scripts/measure-sidebar.py ready \
  --request build/sidebar-measurements/RUN/1-Files-plain1KiB/gate-request.json \
  --pid OBSERVED_PID --mode Files --visible \
  --window-size-unchanged \
  --outer-x OBSERVED_X --outer-y OBSERVED_Y \
  --outer-width OBSERVED_WIDTH --outer-height OBSERVED_HEIGHT \
  --sidebar-width OBSERVED_PANE_WIDTH --zoom 1 \
  --folder build/sidebar-baseline/20261019-065043/fixtures \
  --native-folder-choice --observer independent-reviewer \
  --evidence build/sidebar-measurements/RUN/1-Files-plain1KiB/observed-ui.json
```

For hidden use `--mode Files --no-visible`, omitting folder options and using `--sidebar-width 0`. For Outline use `--mode Outline --visible`, omitting folder options. Never acknowledge a gate from source code, expected preferences or a previous process's screenshot. If the state cannot be observed, leave it pending or stop; timeout is a failed measurement, not a pass.

## Timing, attribution and preservation

The runner retains the original body and complete unified-log events for its exact new PID. These occur before native folder choice and readiness. Record both wall-clock time from the launch request and the app's native time from its document-open request. Empty is N/A. Describe this as **initial launch latency with the requested mode**, never as Files latency with an already-selected folder. The earlier baseline launched without these sidebar preferences; this difference remains part of the comparison limits.

Memory collection begins 15 seconds after the readiness acknowledgement. Collect three raw `footprint` captures 0.5 seconds apart. As in the baseline, report each run's median, then the median and range of its three fresh repetitions. Report app footprint, owned WebKit footprint and RSS as different metrics. Keep OS caches unchanged and rotate cohort and case order between repetitions.

Establish exactly one new process at the exact app executable path before considering WebKit helpers. Include only new helpers whose Darwin `responsibility_get_pid_responsible_for_pid` equals that app PID. Record unrelated and unresolved helpers as exclusions; incomplete attribution must not be presented as a comparable full app-plus-WebKit total. Recheck the selected process set for each capture. The ownership function is host-specific; unavailable ownership or changed processes stops the run rather than falling back to temporal PID proximity.

After capture, terminate only the newly launched exact-path app PID with its original process start token. Wait for every included helper to exit; never kill shared helpers. Verify preserved user processes, fixture hashes and candidate executable hash after every run. Raw evidence, failures, actual gate observations and summaries remain under `build/`.

The tool reads relevant persistent preferences before and after but does not restore a whole defaults domain. Native app layout code can persist changes even when argument-domain launch values are supplied. Record any changed keys and restore the user's initial sidebar state through approved native UI during handback if needed; do not overwrite unrelated preferences. Close only reviewer-owned processes and explicitly return UI control.

## Separate expanded-Files idle CPU sample

The 0.1.0 CPU result does not establish the new sidebar's idle behavior. After integrated review, take one additional 60-second sample with Files visible, a selected reviewer-owned root and at least one expanded child folder. Use an isolated folder already prepared for the third review, not the retained three-file memory root. This extra process is separate from the 36 matched memory runs.

```sh
python3 -u scripts/measure-sidebar.py idle-cpu \
  --app build/Leaflit-0.2.0/Leaflit.app \
  --root build/qa/sidebar-round3-CANDIDATE/Root \
  --document build/qa/sidebar-round3-CANDIDATE/Root/Reading.md \
  --output build/sidebar-measurements/CANDIDATE-idle-cpu
```

The new process has its own `gate-request.json`. Through actual native input choose that root, expand a nested folder, wait until its children and the document remain stable, and save UI evidence. Acknowledge using the same `ready` command and observed bounds, adding `--expanded-folder` with the actual child folder. The tool then waits 15 seconds. Leave the app untouched for the next minute; no refresh mutation, UI review, build or test may run during sampling.

The sample retains cumulative CPU-time counters every five seconds from zero through 60 seconds, only for the exact owned app and WebKit helpers with matching responsible PID and unchanged process start tokens. The selected process set must remain stable. Primary CPU percent is the total counter increase divided by the actual elapsed interval, with one occupied logical CPU equal to 100%. Keep app and helper CPU seconds separately, and preserve the raw `ps` percent as a different metric. A changed process set, unresolved ownership or less than a minute of coverage fails the sample; do not silently replace it with a temporal helper estimate. The tool closes only its own app afterward and records preference differences and preserved processes.

## Result limits and remaining checks

This is a small matched comparison, not a population performance claim or proof of a memory target. Keep candidate SHA, binary hash, fixtures, actual launch preferences, UI readiness delay, host details, attribution limits and persistent preference changes with the results. Preserve failed output; do not retry by changing timing or helper attribution without recording the protocol change. The final English comparison report and `docs/qa/sidebar-resources.json` must retain all samples, ranges and medians, normalize personal paths to repository-relative paths and link raw evidence under `build/`.

The primary comparison is the same fixture before and after the sidebar change, with hidden, Files and Outline separated. The 100KiB benchmark contains 1,484 heading lines; it has a different document/DOM structure from the 100KiB prose fixture as well as Mermaid and math. Do not attribute the baseline's approximately 83.4MiB prose versus 154.2MiB benchmark difference solely to optional renderers. This matched set cannot separate heading/DOM costs from Mermaid/math costs. Earlier experiments that separately removed math or Mermaid are different evidence and must remain attributed to their own protocol.

The integrated third review separately covers large folder and heading lists, refresh, stale events, native navigation and source immutability. Do not add those files to the retained memory fixture root or count their UI review as one of the 36 measurements. Publication, signing and installation remain outside this local Release endpoint.
