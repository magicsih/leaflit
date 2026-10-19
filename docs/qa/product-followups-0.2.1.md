# Product follow-ups for the local 0.2.1 candidate

This report follows the owner-approved [product follow-up scope](../design/0.2.1/design.md) and [L3 test plan](../design/0.2.1/test-plan.json). It covers corrections and additional verification of the existing reader, not another sidebar redesign or a public release.

## Artifact and automated verification

An independent executor ran `scripts/verify.sh Release`, followed by the separate ordinary `scripts/build.sh Release`, on corrected product candidate `2cb6c647084a13476296c2fd642b7b59008fafd9`. Both commands passed. The ordinary app is `build/Leaflit-0.2.1/Leaflit.app`, with its adjacent executable `leaflit` launcher and `build-info.json`.

- Environment: Apple M3, macOS 26.6.2, Xcode 27. Apple Silicon only; deployment target macOS 14 is not an earlier-OS execution result.
- Version 0.2.1, build 3, bundle ID `io.github.magicsih.leaflit`.
- Executable SHA-256: `953d744170e0f215765f2c30f1d892ee81c3b936884d8749e0aabc6079a42f03`.
- Icon SHA-256: `a79b15e973b8086f1c5c617a2c0064c345674fb707e165b25ee2b43a289f8804`; artwork is unchanged from 0.2.0.
- Signing: local ad-hoc only. No 0.2.1 Developer ID signing, notarization, GitHub Release, Homebrew publication or downloaded-artifact verification was performed.

| Check | Result |
| --- | --- |
| JavaScript parser, frame and stylesheet tests | 13 passed |
| Standalone document module | 8 passed |
| Packaging tests | 7 passed |
| Xcode Release suite | 42 passed: 34 Reader tests and the same 8 core tests |
| Production dependency audit | No vulnerabilities reported |
| Ordinary clean Release build | Passed |

Do not count the repeated core suite as unique extra coverage. The complete regression includes security boundaries, all math delimiters and Mermaid, images, relative links and Back, Unicode and spaces, atomic saves, latest-result rejection, source immutability, and 1MiB/5MiB documents. Raw logs, the archived xcresult, source/fixture hashes, ordinary app manifest and preservation checks are retained under ignored `build/product-followups/full-2cb6c647084a13476296c2fd642b7b59008fafd9/`.

## Corrections and targeted regressions

The sidebar previously stored its visible width but restored it as a native divider position. The independent failing test observed 270, 262, 254, 246 and 238pt through repeated reopen cycles in both Aqua and Dark Aqua. The correction derives the divider adjustment from current native geometry, with no fixed OS inset. Four reopen cycles per appearance now retain 270pt through toggles and 480-to-900pt collapse/reopen. Another test retains a 312pt pane through a 620-to-900pt window resize. Existing native mode-button bounds tests also pass. Earlier macOS remains separate.

Automatic split-view resizing now saves a width only when the notification identifies a user resize. The Find regression uses a 620pt native content width and asserted 2.0 page zoom: it compresses the pane from 312 to 274pt while preserving the preferred 312pt through widening and a new reader. The existing synthetic divider test explicitly supplies the documented user-resize marker; actual dragging is verified separately below. The pre-fix `aeba03c` run failed at reopen (274pt instead of 312pt), and `2cb6c64` passed the three selected width tests before its full regression. Both runs and xcresults remain preserved.

Unchanged heading metadata now preserves the native Outline tree. A 2,001-heading test updates only body text in both Outline and Files, retaining tree identity, collapsed groups, selection and list/body reading position. Separate tests confirm title, ID and level changes and document switches still refresh correctly.

Duplicate heading IDs retain their exact previous output while advancing a suffix cursor instead of rescanning every used suffix. The operation-count regression fails at 2,001,000 lookups before the change and passes its linear budget afterward. Mixed literal suffixes and Unicode remain covered.

Overlapping math revisions now share one stylesheet readiness promise. Unit tests cover pending, completed, error and synchronous-load notification paths. Two real WKWebView tests hold the stylesheet's load-completion event: math B waits behind math A's pending CSS, whereas plain B completes immediately; releasing the event cannot apply stale math or headings. The error unit test verifies waiter release, not a styled-error fallback contract.

## Targeted native failure and corrected behavior

The ordinary `dafb71d` app first passed its 41-test Xcode automated checkpoint, but an independent CUA check subsequently rejected its width persistence. The executor bound the exact newly owned candidate process to a unique fixture title, file URL and heading before acting. Actual Open Folder, Files keyboard expansion and selection, Back, Outline keyboard heading selection, Find highlights, math and Mermaid passed in the current light appearance.

A physical divider drag moved its AX value from 230 to 320 in a 900px window capture. A real edge drag narrowed the capture to 620px; ten Zoom In actions and Find then constrained the divider to AX 282. Widening back to 900px restored AX 320 visually, but after quitting the persistent width was 274. An ordinary fresh launch with no sidebar argument overrides reopened at AX 282. The persisted reading was taken after quitting, not at the narrow screenshot instant. These are observed AX values and raster widths; CUA did not expose native point-valued content/outer bounds or numeric page zoom. Ten native increments from the fresh 1.0 default imply 2.0 zoom.

The executor stopped optional UI paths at this failure. The untouched fixture bytes, screenshots and AX trees, ordinary no-override reopen and preservation checks are retained under `build/product-followups/QA-0.2.1-73b337da/` and `targeted-native-result.json`. Images have JPEG bytes despite their `.png` names; a separate decoder-checked metadata correction preserves the original mistaken dimensions without changing image bytes. The entire measured/rendered candidate, launcher and build-info were archived at `build/product-followups/verified-dafb71d-candidate/` with byte/mode/symlink equivalence before any replacement build. Passing automated tests and completing a measurement cohort do not override this UI failure.

The corrected `2cb6c64` ordinary app then passed the bounded actual failure path on a new owned fixture. A physical divider drag produced AX 320 and saved width 312. At the 620px capture, ten Zoom In actions and Find compressed the divider to AX 282 while the saved width remained 312; widening to 900px restored AX 320. After quitting, an ordinary fresh launch with no sidebar argument overrides reopened at AX 320 with the same saved width. Both Files and Outline buttons remained visible. Screenshots, AX trees, launch commands and preference observations are retained at `build/product-followups/targeted-width-2cb6c647084a13476296c2fd642b7b59008fafd9/`. This verifies real user resizing separately from the synthetic notification test. Native content/outer point bounds and numeric zoom remain subject to the observation limits above.

A post-quit AX request was followed by a new empty candidate process. Its cause was not assigned. The executor recorded and stopped that exact new candidate before the single planned ordinary fixture restart; it did not send UI actions to the preserved installed app. The extra process and its strict ownership/cleanup record are retained, rather than silently counted as a normal fixture launch.

After all owned processes exited, the executor restored only the known owned width change to the latest preflight value. Fixture bytes, the installed whole bundle and user process identity were preserved. The entire corrected candidate, launcher and build-info were archived at `build/product-followups/verified-2cb6c64-candidate/`, with 192 byte/mode/symlink manifest entries verified equal. The combined independent handoff is `build/product-followups/verification-and-profile-handback-2cb6c64.json`.

## Window lifetime and failed test diagnosis

The final synchronous lifetime test confirms Reader, NSWindow, ReaderWebView and Sidebar weak references all become nil after close. Its close callback fires once, another reader still searches, the closed file reopens, and source bytes remain identical. This establishes application-object release in the executed scenario; it does not classify persistent WebKit helper memory as a leak or a cache.

Earlier asynchronous probes repeatedly failed. Local `leaks --traceTree` and `swift-inspect dump-concurrency` captures identified an explicit XCTest outer autorelease-pool reference. A task path passed through the surviving test reader, so it could not establish ownership of the closed reader. Moving the probe into a synchronous run-loop pump with a draining pool resolved the failure on unchanged product code. Diagnostic tools reported configuration and symbol limitations, which remain in their raw records. Temporary pointer/pause instrumentation was removed.

Preserved failure history:

- `aa0eb96`: width drift, two Outline identity failures and the asynchronous lifetime timeout.
- `3692a3d`: width and Outline corrections passed; the asynchronous lifetime probe still failed.
- `cf2c8b9`, `686d106`, `72a79af`, `75e32bf`: lifetime variants still failed. Specific observer removal, releasing the task handle and helper-scope changes must not be described as proven leak fixes.
- Two separately retained diagnostic invocations used uncommitted, hash-recorded test-only instrumentation. Neither was a passing verification run.
- `45080c9`: synchronous draining-pool lifetime probe passed with all four references nil. The complete `dafb71d` and corrected `2cb6c64` regressions repeat that pass.

The close path now removes only its own split-view notification and drops its cancelled task handle. These are bounded cleanup changes; no renderer replacement, shared document store or helper-process termination was introduced. All failed runs and trace files remain under ignored `build/product-followups/lifetime-*` and the source-named selected-test directories.

## Parser measurements and output compatibility

These are matched Node parser microbenchmarks, not WebKit display or app-memory measurements. All samples, fixture hashes, tool versions and before/after source snapshots are retained in `build/product-followups/web-performance-20261019-122235/`.

| Input | Before median | After median |
| --- | ---: | ---: |
| 1,000 identical headings | 56.17ms | 3.65ms |
| 3,000 identical headings | 491.02ms | 12.22ms |
| 6,000 identical headings | 1,971.38ms | 18.50ms |
| Fixed heading-heavy 100KiB benchmark | 62.02ms | 10.00ms |
| Heading-light 100KiB prose | 2.41ms | 2.80ms |

The prose ranges overlap; no prose improvement is claimed. Parser construction/configuration took a small fraction of a millisecond, so parser reuse was not added.

The first 200-case compatibility record lacked a retained generator. It remains historical evidence with that replay limit. A new reproducible cohort uses seed `12345`, stores all 200 generated inputs, all 406 before/after outputs including three fixed fixtures, hashes, source and tool versions. All 203 outputs match. Replay on this measurement host:

```sh
node build/product-followups/web-compatibility-replay/replay.mjs verify
node build/product-followups/web-compatibility-replay/verify-generator.mjs
```

An independent reviewer executed both replay commands successfully, checked Node 24.16.0 and installed lock/dependency identities, and confirmed input/output/source hashes and preservation. Its separate record is `build/product-followups/independent-web-replay/20261019T040155Z-e662de02/result.json`.

## Whole-app measurement method and limits

The ordinary ad-hoc 0.2.0 baseline was copied before any build. Its source is `5defe3c633336a8658a7c368baaed00d5fb1f4c4`, executable SHA-256 `68a025d77f418b3a26219138b7274aefa879085cfc92622955c0a9c10f20812b`. It is compared with the ordinary 0.2.1 app, without mixing Developer ID and ad-hoc artifacts.

The preserved runner and helper have SHA-256 `5835d4d7d8f32089e9a253433122c663cbb250c5f7461800093a193fa5e45808` and `3129e3519b8b6ade03098b0c0950b4ec4baa733377399e41a841b0bec0bf24cb`. There is no CUA, accessibility or screenshot observation during either measurement cohort. Nonempty memory samples start 15 seconds after both native display logs arrive; empty starts 15 seconds after exact PID establishment. Each of three fresh runs per case has three footprint captures spaced 0.5 seconds apart. Files is visible without a selected folder. Baseline divider argument 230 and corrected candidate visible-width argument 222 match source-derived geometry on this host; actual window bounds and painted readiness were not observed by this protocol.

Fresh launches use the same fixed 100KiB fixture 20 times. Body and complete, native-open and launch-wall-clock times and animation-frame/timer-fallback provenance stay separate. OS caches are not cleared. Only the exact newly owned PID and helpers whose responsible PID matches it are included; start tokens and process sets are rechecked. Only the owned app is stopped. Raw events, failures and preservation checks remain local.

The candidate has a concurrent installed Leaflit process that was absent during baseline collection. It is preserved and excluded from attributed totals. Together with the small memory sample, GPU variation, uncontrolled host/cache state and lack of visual readiness observation, this prevents a causal or population-wide memory claim. Results from this protocol must not be blended with earlier accessibility-observed sidebar measurements.

The first candidate attempt stopped after 13 complete fresh launches: iteration 14 produced neither body nor complete event within 30 seconds. The owned app remained alive, and open/PID establishment succeeded. No display event from any PID appeared in the retained stream during that interval. Readiness and cause are unconfirmed. The entire partial attempt is preserved at `build/product-followups/candidate-profile/` and excluded from a complete-cohort timing summary; it is not reclassified as paused animation or successful rendering.

## Whole-app results

The initial `dafb71d` replacement cohort completed all 20 fresh launches and nine fresh memory runs at `build/product-followups/candidate-profile-replacement/`, before the native Find check rejected its width persistence. After correcting that defect, a separate `2cb6c64` cohort again completed all 20 fresh launches and nine fresh memory runs, with no reused samples or new failures. The corrected evidence is `build/product-followups/candidate-profile-2cb6c647084a13476296c2fd642b7b59008fafd9/`; the preserved baseline is `build/product-followups/baseline-profile/`. The table uses the corrected product. [Normalized report data](product-followups-0.2.1.json) retains every complete-cohort latency sample, all 81 memory captures across the three cohorts, and their 20-pair transition samples, without local process IDs or personal paths. Raw logs and full local manifests remain ignored.

Footprint in MiB, median of three fresh-run medians, with the full fresh-run range:

| Input | Ordinary 0.2.0 | Ordinary 0.2.1 |
| --- | ---: | ---: |
| Empty window | 54.41 [53.88–54.55] | 53.82 [53.64–56.85] |
| Heading-light 100KiB prose | 82.44 [74.61–143.08] | 80.85 [80.47–81.50] |
| Heading-heavy 100KiB with math and Mermaid | 146.63 [144.52–201.47] | 121.08 [110.75–123.07] |

Ordinary prose usage is effectively unchanged. The combined benchmark has a lower observed footprint in this small set, but background conditions differ and no allocation-level cause is established. The native-app medians for prose/benchmark are 33.67/33.94MiB; owned-helper medians are 47.80/87.67MiB. These component medians must not be summed as an exact aggregate-tool median. Candidate summed RSS medians are separately 214.64/272.64MiB; RSS and footprint are different metrics. The 60MiB reading comparison target is not met.

| Timing, milliseconds | Before median | After median | Samples and method |
| --- | ---: | ---: | --- |
| Fresh launch to body | 682.09 | 736.09 | 19 versus 20 animation-frame samples |
| Fresh launch to complete | 853.09 | 940.89 | 19 versus 20 animation-frame samples |
| In-process transition to body | 116.45 | 64.74 | 20 each, all animation-frame samples |
| In-process transition to complete | 163.53 | 110.91 | 20 each, all animation-frame samples |

Fresh launch did **not** improve in this comparison. The baseline's separate one timer-fallback sample is 991.83ms body and 1,387.96ms complete; neither complete candidate cohort has a fallback sample. The first baseline animation-frame run (2,266.82/2,475.21ms) is retained. Frame-based events approximate paint; a timer completion does not establish painted pixels. None of these are cache-flushed OS cold starts.

The transitions come from the same XCTest function and fixed input. The baseline function ran in a selected suite, while the corrected candidate runs in the full regression; process preconditioning and host state differ, so this is a descriptive comparison rather than an isolated causal estimate. Baseline native source and all 178 generated Web files matched the ordinary 0.2.0 product; the candidate uses the full final product regression. All 20 payload values on each side were matched to their native phase-log events within 0.00001ms, excluding the initial-open pair. A previous post-fix selected run measured 45.67/92.45ms, and the `dafb71d` full suite measured 52.45/99.28ms. They remain separate; the table uses the corrected full-suite candidate's 64.74/110.91ms. The intermediate `dafb71d` fresh-launch medians were 759.83/1,006.84ms and memory medians 53.69/81.92/122.46MiB; its completed measurement does not change the later native acceptance failure. This is an improvement in the executed document-switching scenario, without a claim that startup or all Markdown is faster.

The ordinary candidate has 187 regular files totaling 6,588,994 apparent bytes (6.284MiB), versus 6,588,102 bytes for the ordinary baseline. Both occupy 6,896KiB in this filesystem's `du -sk` result. These are local app-bundle sizes, not a compressed release archive or runtime memory. No new idle-CPU result is claimed; the earlier expanded-Files sample remains historical evidence.

## Reproduce the product verification

```sh
./scripts/verify.sh Release
./scripts/build.sh Release
open build/Leaflit-0.2.1/Leaflit.app
./build/Leaflit-0.2.1/leaflit Fixtures/Welcome.md
```

The archived local profiling runner is `build/product-followups/profile-readonly.py`, with the exact helper snapshot beside the baseline results. It consumes the retained fixed fixture paths and creates separate evidence directories; it is a host-local measurement record, not a new maintained clean-checkout tool. The maintained benchmark's missing-event ownership failure path is tracked in [#23](https://github.com/magicsih/leaflit/issues/23).

For the final source handoff, rerun both verification and the separate ordinary build on merged `main`. Record the exact merged SHA, actual command results, ordinary app byte/mode/symlink equivalence to the archived corrected candidate and preservation checks in ignored `build/product-followups/final-candidate.json` and the PR completion comment. A previous-SHA result must not substitute for that final execution. Documentation-only commits do not themselves establish another execution result.

## Remaining coverage and distribution state

Earlier macOS [#5](https://github.com/magicsih/leaflit/issues/5), spoken VoiceOver [#4](https://github.com/magicsih/leaflit/issues/4), actual cross-app Finder drop [#8](https://github.com/magicsih/leaflit/issues/8), network-unavailable execution [#12](https://github.com/magicsih/leaflit/issues/12) and remaining icon surfaces [#9](https://github.com/magicsih/leaflit/issues/9) remain distinct from automated regression. A blocked fetch and bundled optional assets do not prove host/app network isolation.

Memory attribution [#1](https://github.com/magicsih/leaflit/issues/1), post-close WebKit behavior [#2](https://github.com/magicsih/leaflit/issues/2) and remaining startup attribution [#3](https://github.com/magicsih/leaflit/issues/3) remain follow-ups. Source review also registered bounded obsolete I/O [#21](https://github.com/magicsih/leaflit/issues/21) and fail-closed rule initialization on Retry [#22](https://github.com/magicsih/leaflit/issues/22), with evidence separated from unexecuted hypotheses.

The installed signed 0.2.0 app, its live process, public release, Homebrew cask, website, unrelated preferences, original documents and historical evidence are preserved. The public preview stays 0.2.0. No 0.2.1 public release or global app installation is part of this work.
