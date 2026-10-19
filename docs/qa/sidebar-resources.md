# Files and Outline: independent resource measurements

Completed on 2026-10-19 on the Apple M3 development host, macOS 26.6.2 (25G83), arm64. The [third rendered review](sidebar-ui-round3.md) finished before these measurements. Each measurement used a fresh, separately owned app process. No build, UI regression or other measurement ran concurrently.

All 12 observation-matched public controls, 36 candidate memory runs, 20 fresh benchmark opens and the separate 60-second expanded-Files CPU interval completed. The [numeric record](sidebar-resources.json) retains every memory capture, process attribution, run summary, phase timing, cold-open sample and CPU counter sample. Raw logs, AX trees and gate screenshots remain in ignored `build/`.

## Identity and method

| Artifact | Source SHA | Executable SHA-256 |
| --- | --- | --- |
| Installed public 0.1.0, `/Applications/Leaflit.app` | `af15d5d01d0f11e3c4558c793fad43da3c7fc082` | `20f04c5661b030955ee4e22b041062fbf9ffa244c82ecd16a1efcbf59e45a933` |
| Normal Release 0.2.0, `build/Leaflit-0.2.0/Leaflit.app` | `eebc9489216d3ed46e26c2a1850d196d0db3d5ff` | `5688e944bab1950fb0f01e6b3b93bde1ec4d71dcb02584cee3d8a60a3c6a2333` |

Public identity was checked against its release manifest; candidate identity was checked against its normal build record. Both executable hashes and the three fixed fixture hashes still matched during final compilation of this report. No app installation, product source change, signing or publication occurred.

The [reproducible protocol](sidebar-measurement-protocol.md) and [measurement tool](../../scripts/measure-sidebar.py) specify the exact fixtures, ownership checks and commands. The public control and candidate use byte-identical files at the retained original paths. There are four cases: no document, 1KiB prose, 100KiB prose and the fixed 100KiB benchmark. Each condition has three fresh repetitions. OS caches were left warm; “fresh” does not mean a cold machine or flushed file caches.

For every memory run, actual CUA observation established readiness before a 15-second settle, followed by three `footprint` captures 0.5 seconds apart. The summary is the median of those three captures, then the median and minimum/maximum of the three fresh-run medians. MiB means 1,048,576 bytes. The tool's total footprint, individual process footprints and summed RSS are separate fields; independent role medians should not be added to reconstruct the total.

An exact new app PID and start token were established before helpers were assigned. Only newly created WebKit helpers with Darwin `responsiblePID` equal to that app PID were included. Ownership was rechecked during capture. All retained memory runs had unambiguous app-plus-WebKit attribution. CUA does not return a PID, so candidate captures paired documented exact-path binding with a unique live executable PID, an explicit current-target argument, the candidate's Toggle Sidebar toolbar marker and the actual document identity. Each gate retains that evidence.

Fresh windows stayed at observed outer bounds 900×784 and 100% document zoom. The 900×700 content size is source-derived, not an observed content rectangle. Native calibration showed that divider position 230 yields a 222pt pane because its leading edge is at 8pt. Position 238 yielded the required actual 230pt pane, which every visible candidate gate confirmed without relaxing the ±2pt check. The coordinate round-trip risk is tracked in [issue #13](https://github.com/magicsih/leaflit/issues/13); repeated-window cumulative shrink was not executed here.

## Footprint comparison

Values below are total app-plus-owned-WebKit footprint: **median [minimum–maximum] MiB**, three fresh runs per cell. Files includes a root explicitly selected with the native folder chooser and the current document selected when present. Outline includes the current document's headings or its appropriate empty state. Hidden has no selected root.

| Case | Public 0.1 observed control | 0.2 hidden | 0.2 Files | 0.2 Outline |
| --- | ---: | ---: | ---: | ---: |
| No document | 53.6 [51.6–53.8] | 56.3 [54.3–59.0] | 59.6 [57.3–59.9] | 54.3 [54.3–54.7] |
| 1KiB prose | 66.5 [65.6–67.9] | 70.4 [66.9–72.8] | 71.8 [70.2–73.9] | 71.3 [70.8–72.0] |
| 100KiB prose | 87.3 [77.2–89.9] | 87.0 [80.0–92.5] | 85.2 [85.2–89.8] | 84.6 [84.1–86.4] |
| Fixed 100KiB benchmark | 121.8 [120.5–155.5] | 161.9 [147.9–167.5] | 157.7 [154.2–167.9] | 151.3 [145.8–157.2] |

The observed candidate's benchmark total is higher at its median in all three modes. The larger difference is in WebContent, while Outline also has a larger native-app footprint. The benchmark role breakdown is retained below to make that observation inspectable; it does not establish which implementation or allocation caused the difference.

| Benchmark role | Public 0.1 observed | 0.2 hidden | 0.2 Files | 0.2 Outline |
| --- | ---: | ---: | ---: | ---: |
| Leaflit | 33.0 [31.5–34.0] | 34.7 [34.6–36.3] | 37.0 [36.8–40.1] | 41.6 [41.4–43.5] |
| WebContent | 71.5 [71.3–104.9] | 111.1 [94.5–116.6] | 104.0 [98.0–111.0] | 92.7 [86.1–96.8] |
| GPU | 12.4 [12.2–14.3] | 12.2 [12.2–13.0] | 12.9 [12.8–14.5] | 13.0 [12.1–14.3] |
| Networking | 4.3 [4.2–5.1] | 4.3 [4.3–4.3] | 4.3 [4.2–5.0] | 4.3 [4.3–5.0] |

Three repetitions and overlapping ranges do not support a causal or statistical significance claim. The 60MiB planning target is not met for the document cases as an app-plus-WebKit total. Native app footprint alone must not be substituted for the full reading process set.

## Local bundle size

A static filesystem observation after the runtime handback measured the existing bundles without installing or launching either app. Regular-file logical size excludes symbolic links to avoid counting the framework executable twice; allocation is the sum of `st_blocks × 512`. `du -sk` includes directory entries. APFS compression and shared extents can affect physical allocation, so this is not a download-size or installation-growth measurement.

| Bundle | Regular files | Logical bytes | Allocated bytes | `du -sk` KiB |
| --- | ---: | ---: | ---: | ---: |
| Installed public 0.1.0 | 188 | 5,265,485 | 5,738,496 | 5,604 |
| Local ad-hoc 0.2.0 | 186 | 5,530,522 | 6,000,640 | 5,860 |

The candidate contains about 5.27MiB of regular-file data. The public and local apps have different distribution-signing states, so the size difference is not attributed solely to the sidebar. Raw fields and unchanged executable hashes are retained in the numeric record and `build/sidebar-verification/bundle-sizes.json`. To reproduce the directory allocation observation, run `du -sk /Applications/Leaflit.app build/Leaflit-0.2.0/Leaflit.app`.

## Observer and comparison limits

The original complete 0.1 baseline used no CUA or AX inspection. Its total medians were 55.1, 67.6, 83.4 and 154.2MiB for the four cases, respectively. It remains intact as context. Its settle began after display completion, whereas the new sets settle after actual UI readiness. Those observer and elapsed-time conditions differ.

WebKit's [accessibility performance notes](https://trac.webkit.org/wiki/WebKitAccessibilityPerformance) describe accessibility-tree generation and caching in the web process. This makes observation a plausible memory confound; the existence or size of that effect on this host was not established. The new public controls therefore use the same initial AX observation and full AX/screenshot gate operations as the candidate. This improves matching without isolating every allocation.

There are remaining differences. Files requires four native chooser AX observations, with one extra observation on four runs. Gate delay from launch ranges from 6.8–50.9 seconds for public controls and 6.4–47.0 seconds for candidates. Focus/active-window appearance varied, initial exact-path binding used automatic or explicit AX, and product version, renderer changes and build/signing state differ. Public control run `1-observedControl-benchmark100KiB` used an explicit initial AX read although its historical metadata calls it automatic; both represent one initial read. Every raw observation is preserved. These are descriptive matched-fixture comparisons, not isolated sidebar-cost estimates.

The benchmark contains 1,484 heading lines as well as optional math/Mermaid rendering. Its DOM structure differs from the prose fixture. Differences between document types cannot isolate the cost of math or Mermaid, and are unrelated to the earlier separate renderer-component analysis.

## Initial display latency

These are original document-launch events, collected asynchronously without delaying the UI gate. They may arrive before, during or after observation. No selected folder exists at launch, so they do not measure Files starting with an already-selected root. Raw public-v2 protocol wording that says “before readiness” is superseded by this clarification; the original files were not rewritten.

Values are **median [minimum–maximum] ms from the launch request**, three fresh runs per row. Public events lack timing provenance and remain `unreported`. Every candidate memory-set event below is `animationFrames`. The groups are displayed separately, with no cross-version percentage or merged frame summary. Native document-open-request timings are also retained in JSON. Empty is N/A.

| Unreported group | Case | Body | Complete |
| --- | --- | ---: | ---: |
| Public 0.1 observed | 1KiB prose | 670 [618–720] | 673 [647–746] |
| Public 0.1 observed | 100KiB prose | 655 [592–762] | 660 [621–779] |
| Public 0.1 observed | Fixed benchmark | 718 [677–747] | 912 [843–943] |

| Animation-frame group | Case | Body | Complete |
| --- | --- | ---: | ---: |
| 0.2 hidden | 1KiB prose | 713 [659–735] | 739 [674–751] |
| 0.2 hidden | 100KiB prose | 707 [661–793] | 738 [693–813] |
| 0.2 hidden | Fixed benchmark | 808 [683–821] | 969 [853–1081] |
| 0.2 Files | 1KiB prose | 785 [696–1084] | 809 [722–1113] |
| 0.2 Files | 100KiB prose | 735 [717–939] | 754 [747–962] |
| 0.2 Files | Fixed benchmark | 773 [730–989] | 1000 [959–1238] |
| 0.2 Outline | 1KiB prose | 694 [650–893] | 725 [675–924] |
| 0.2 Outline | 100KiB prose | 700 [697–902] | 719 [719–942] |
| 0.2 Outline | Fixed benchmark | 1010 [904–1062] | 1245 [1164–1275] |

The original renderer used a two-frame method, but its unlabeled events are not upgraded to confirmed frame samples. A frame event approximates display timing; a timer fallback establishes progress without proving painted pixels. The complete phase is fallback if either render wait used the timer. Functional 20-transition, 1MiB and 5MiB coverage comes from same-candidate independent automation; its transition attachment has unestablished timing provenance and supplies no frame-comparable timing here.

## Separate 20 fresh benchmark opens

Executed sequentially after the memory sets, with no CUA/AX observation:

```sh
python3 scripts/benchmark.py --app build/Leaflit-0.2.0/Leaflit.app \
  --count 20 --output build/sidebar-verification/cold-eebc948-20261019-0901
```

All 20 had both phases. Nineteen used animation frames and one used a timer fallback for each phase. This is timing-only evidence without helper attribution or memory capture. The candidate's exact executable path had no running PID at preflight; the three other app processes were preserved.

| Phase and timing | n | From launch ms, median [range] | From open request ms, median [range] |
| --- | ---: | ---: | ---: |
| Body, animationFrames | 19 | 721 [643–820] | 381 [316–462] |
| Complete, animationFrames | 19 | 915 [820–1026] | 576 [491–669] |
| Body, timerFallback | 1 | 899 [899–899] | 561 [561–561] |
| Complete, timerFallback | 1 | 1315 [1315–1315] | 977 [977–977] |

The fallback sample is retained and excluded from frame comparisons. No fallback or unreported sample was silently treated as a frame sample.

## Expanded-Files idle CPU

One separate interval used the scale root with 1,000 root Markdown files and 100 folders of ten children. Files was visible at actual 230pt. The native chooser selected the root, Folder 000 was collapsed and expanded through native AX actions, and Child 00 was current with its ten child rows visible. Actual gate evidence precedes a 15-second settle.

The stable owned process set was app PID 91021 and its responsible GPU, Networking and WebContent helpers. Thirteen cumulative CPU-counter captures were taken at approximately five-second intervals. From the first counter at 09:04:00.181653 KST, the measured interval was **60.259 seconds**. Total CPU was **0.060 seconds**, or **0.100% of one logical CPU**; the native app and helpers each contributed approximately 0.030 seconds. Parent activity was paused throughout this interval. The app and included helpers exited afterward.

This is one idle interval with finite counter precision, not a general CPU guarantee. The earlier 0.1 CPU result is not counted as a pass for the sidebar. All counters, process deltas, start/responsibility checks and actual setup evidence are retained.

## Exclusions, preservation and handback

Two partial attempts remain excluded from the completed sets:

- `build/sidebar-measurements/observed-control-eebc948-20261019-0822`: one completed empty run and a plain1KiB launch with missing display events before the old gate. Its cause is unconfirmed. The full 12-run observation-first-v2 control set replaced it; its completed sample was not reused.
- `build/sidebar-measurements/candidate-eebc948-20261019-0836`: an obsolete CUA helper closure retained the public app target. One possibly incorrect empty capture and a pending nonempty run were excluded in full. Explicit target parameters, unique-path PID proof, candidate toolbar-marker and actual-document checks were then required for the new full 36-run set. This was a measurement-tool error, not a product defect.

The earlier incomplete baseline at `build/sidebar-baseline/20261019-064359` is also excluded because its helper attribution was incomplete. All partial evidence remains under `build/`. Non-app synthetic preflight checked full coverage, duplicate/missing-case rejection, ownership ambiguity, ready-state validation, geometry separation, asynchronous event collection and separate timing groups before the completed sets ran.

At the start of the rendered round the user's sidebar was Files, visible, with width preference 180. At the later measurement-protocol start it was Outline, visible, width 222. Native geometry preparation and candidate sampling subsequently persisted width 230. At final handback, a separately owned blank candidate window restored Files, visible, with an actual 180pt pane; defaults readback was `Files`, `1`, `180`. That restoration process exited through Command-Q. Auto appearance, Automatic scrollbars and VoiceOver off had already been restored. No whole preference domain was overwritten.

Only the preserved apps remained: PIDs 95552 and 96665 at their original old-build paths, plus public PID 77888 whose ownership was unconfirmed and which was deliberately left untouched. All measurement apps were closed. Their WebKit helpers were identified by responsibility, independently of that public process. Candidate app, bundled launcher and normal build records were preserved; exclusive runtime/UI control was returned to the parent before report preparation.

Raw evidence locations:

- Original complete unobserved baseline: `build/sidebar-baseline/20261019-065043/`.
- Completed observed controls: `build/sidebar-measurements/observed-control-v2-eebc948-20261019-0828/`.
- Completed candidate cohorts: `build/sidebar-measurements/candidate-explicit-target-eebc948-20261019-0840/`.
- Geometry, tool preflight, helper source and preference restoration: `build/sidebar-measurement-tool-check/`.
- Fresh benchmark opens: `build/sidebar-verification/cold-eebc948-20261019-0901/`.
- Expanded-Files CPU: `build/sidebar-measurements/idle-eebc948-20261019-0903/`.

`build/sidebar-measurement-tool-check/compile-resource-report.py` compiles retained structured evidence into the curated JSON without starting an app. It verifies case/repeat coverage, sample counts, ready-evidence hashes, candidate target markers, responsibility attribution and unchanged fixture/executable hashes. The final documentation commit still requires the separately coordinated independent verify/build; these reports do not claim that later commit has already been tested.
