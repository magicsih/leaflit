# Leaflit 0.1.0 local-candidate QA

Executed 2026-10-18 on Apple M3 and macOS 26.6.2. The build target is macOS 14; earlier OS execution remains unverified. Product-source candidate: `dffa027d7aa566b915ea0a0fe59a80af73922e01`. Final documentation/test commit `8768530d030eca9b6e15c40b283d9e240296fd2c` was reverified and rebuilt, recording its SHA in `build/verification.json` and `build/Leaflit-0.1.0/build-info.json`. Product sources and the shipping executable hash were unchanged. This report records the original local candidate; later public-distribution work is described in [release preparation](../design/0.1.0/public-release.md).

## Implementation

The Swift/AppKit/WKWebView app and Foundation-only document module provide macOS file opening, per-document windows, relative navigation and Back, search, copy, zoom, heading anchors, file watching and recovery. Locked markdown-it, Mermaid, KaTeX and fonts are bundled; math and diagram libraries load on demand.

Raw HTML renders as text. CSP and WebKit rules block remote requests; only referenced PNG/JPEG files with verified formats are served. The app does not write documents or add a server, analytics or full-disk-access request. This local candidate uses ad-hoc signing, without App Sandbox, Developer ID or notarization. Finder defaults and PATH were unchanged.

## Automated verification

An independent reviewer directly ran `./scripts/verify.sh Release`. Initial log: `build/verify-independent.log`; results and original screenshots are in xcresult bundles under `build/DerivedData/Logs/Test`.

| Check | Result |
| --- | --- |
| Web parser tests | 4 passed |
| Foundation module | 6 passed |
| Initial independent Xcode suite | 18 passed, including the 6 core tests and 12 actual WKWebView tests |
| Final complete Xcode suite | 19 passed after adding the real-menu regression test; 6 core and 13 actual WKWebView tests |
| Production dependency audit | 0 vulnerabilities reported by npm audit |
| Source immutability | Before/after data comparisons and independent fixture SHA-256 comparisons passed |
| Large documents | Approximately 1MiB and 5MiB bodies displayed and remained unchanged |

Do not add the standalone core-test count to Xcode's count as unique tests. Integration coverage includes all four math delimiters, visible Mermaid labels and accessibility names, invalid syntax, hostile HTML/links, relative documents/anchors, actual menu dispatch, atomic/rapid saves, obsolete-result rejection, deletion/recovery, images, scroll restoration and intervening user scrolling, identical saves/sibling changes, zoom/appearance and blocked external fetch.

Test windows alone use a floating level to avoid WebKit animation-frame suspension when obscured. Product windows do not. Release-configuration integration tests use `ENABLE_TESTABILITY=YES`; the shipping candidate is a separate ordinary clean Release build. Final rerun evidence is `build/verify-final.log` and `build/verification.json`.

## Independent UI reviews

See [round 1](ui-round1.md), [round 2](ui-round2.md), [round 3 plan](ui-round3-plan.md) and [round 3 results](ui-round3.md). Different candidates and scopes remain explicit; an earlier failure is not silently treated as a later pass.

Round one found missing diagram labels, nonfunctional menu Back and search paste. Round two confirmed labels and paste recovered, and retained Back and fragmented formula-error-border findings. Fixes separated read-request and displayed revisions, routed menu commands through visible-window order, corrected error borders and improved diagram accessibility names.

Round three exercised ordinary/replacement saves, twenty rapid updates, identical saves and sibling changes followed by navigation, deletion/UTF-8 errors, formula borders, diagram names and Finder Open With. Four fixture hashes matched before and after.

Initial CUA menu/Cmd+F observations differed from a single bounded reconnection check on the identical binary. The final check successfully returned through menu Back and opened focused search. A tool `originalApplicationActivationFailed` event occurred between them; the original observations remain in the report. Actual NSMenu activation, zoom, Back and Cmd+F dispatch also have automated regression coverage.

VoiceOver activation and its process were confirmed, then the original off state restored. Speech and VoiceOver cursor movement could not be verified through the tool. Finder Open With passed without changing its default. An actual cross-app Finder drop was not executed because a grounded drag path was unavailable.

Actual WKWebView captures at 640pt and 200%:

![Light appearance](screenshots/640pt-200percent-light.png)

![Dark appearance](screenshots/640pt-200percent-dark.png)

## Performance and resources

Display events follow DOM replacement and two animation frames. They approximate paint timing rather than hardware-observed pixels. OS file caches were not cleared.

- Input: `Fixtures/Benchmark100KiB.md`, 102400 bytes including Korean, emoji, math and Mermaid.
- Cold opens: twenty new processes, timed from the open request to the display event with `scripts/benchmark.py`.
- Transitions: twenty switches between copies of the fixed document in a running ReaderController.
- Resources: prelaunch/new PID comparison includes WebKit helpers; footprint and sixty idle CPU samples use `scripts/measure-resources.py`.
- p95: nearest-rank nineteenth value among twenty sorted samples.

[Complete samples](measurements.json) are preserved.

| Display phase | Median | p95 |
| --- | ---: | ---: |
| Cold body | 1169.9ms | 1288.9ms |
| Cold math/diagrams complete | 1508.2ms | 1622.7ms |
| Transition body | 115.0ms | 121.5ms |
| Transition complete | 172.3ms | 192.7ms |

Combined app/WebKit footprint was **148.5MiB** in the original resource run; final RSS sum was 142.4MiB. These are different metrics. Sixty idle samples over 70.34 seconds averaged 0.14% aggregate CPU. Installed size was 5.5MiB by `du`, logical file size 5.02MiB. One replacement-save sample reached body display in 252.3ms; this is not a percentile or a sustained guarantee.

On 2026-10-19, [separate memory measurements](memory-analysis.md) compared empty, plain, math and Mermaid conditions on the identical binary. Do not reinterpret the original single 148.5MiB value as a repeated statistic.

The approximately 1MiB document measured 880.7ms body/909.6ms complete; approximately 5MiB measured 3074.3/3107.4ms. Actual byte counts were 1048573 and 5242873. Bodies were not omitted and before/after source data matched.

Initial comparison goals of 500ms cold display, 100ms transition and 60MiB memory were missed. Installed size under 20MiB and idle CPU under 1% were observed. Refresh under 300ms was observed once. These results do not establish general performance superiority.

## Original distribution state and limitations

The original output was `build/Leaflit-0.1.0/Leaflit.app`, its launcher and build-info, without remote publication or distribution signing. The owner later authorized public release as a separate stage.

Earlier macOS, Intel and public-download execution were not verified by this original report. The renderer's actual remote-request blocking was tested without disabling OS networking. Actual Finder drop, default-browser web-link opening, spoken VoiceOver and full keyboard-menu navigation remained incomplete. Later release-stage evidence must be recorded separately, without rewriting these historical observations.
