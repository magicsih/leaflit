# Memory measurements by document feature

Measured across 2026-10-18 and 2026-10-19 at the owner's request, comparing an empty window, plain Markdown, math and Mermaid. Product code and the Release app were unchanged.

## Results

Each of the five primary conditions ran five times. Combined app/WebKit median footprint was 53.8MiB for the empty window, 112.5MiB for the heading-heavy 100KiB plain document, and 131.1MiB for that document with math and Mermaid. Additional inputs measured 69.7MiB for a 1KiB document and 85.6MiB for a heading-light 100KiB document. Plain rendering already accounts for substantial growth; the original single 148.5MiB observation cannot be attributed entirely to math and Mermaid.

Ranges below are minima/maxima of per-run medians, not confidence intervals. The 30-second post-close result comes from only the final run of each primary condition.

| Condition | Loaded median | Loaded range | 5s after close, median | 30s after close, one run |
| --- | ---: | ---: | ---: | ---: |
| Empty window | 53.8MiB | 51.3–54.8MiB | 53.5MiB | 55.1MiB |
| Plain, 100KiB | 112.5MiB | 109.1–177.8MiB | 109.0MiB | 108.9MiB |
| Math, 100KiB | 113.1MiB | 109.6–143.7MiB | 116.3MiB | 116.3MiB |
| Mermaid, 100KiB | 121.3MiB | 117.3–155.7MiB | 120.8MiB | 42.9MiB |
| Math and Mermaid, 100KiB | 131.1MiB | 128.4–153.8MiB | 131.0MiB | 159.4MiB |

Loaded process medians follow. Columns are independently summarized, so their sum need not equal the median aggregate above.

| Condition | Leaflit | WebKit content | WebKit GPU | WebKit networking |
| --- | ---: | ---: | ---: | ---: |
| Empty window | 32.0MiB | 11.5MiB | 5.7MiB | 4.3MiB |
| Plain | 32.2MiB | 60.6MiB | 13.2MiB | 5.0MiB |
| Math | 31.0MiB | 63.8MiB | 13.8MiB | 5.1MiB |
| Mermaid | 30.9MiB | 72.1MiB | 12.8MiB | 5.0MiB |
| Math and Mermaid | 32.7MiB | 79.0MiB | 14.3MiB | 5.1MiB |

The math and plain aggregate ranges overlap. Their 0.6MiB median difference is not a precise allocation cost for KaTeX. Mermaid coverage uses only one simple flowchart and does not generalize to complex diagrams.

Closing a window often did not promptly lower usage. Plain-document runs ranged from about 42MiB to about 113MiB five seconds after close. Some helpers exited in the final Mermaid run, while the final combined run retained approximately 108MiB in WebContent after thirty seconds. Process caching, retained references and delayed reclamation were not distinguished; these observations do not establish a leak. After quitting each measured app, the harness confirmed that its app and newly started helper PIDs had exited.

[Primary samples](memory-primary.json) preserve 25 complete runs and every footprint snapshot.

Each additional condition ran three times:

| Additional condition | Loaded median | Loaded range | 5s after close, median |
| --- | ---: | ---: | ---: |
| Short plain document, 1KiB | 69.7MiB | 69.5–69.8MiB | 69.9MiB |
| Heading-light plain document, 100KiB | 85.6MiB | 85.4–88.5MiB | 85.7MiB |

[Additional samples](memory-additional.json) preserve six complete runs. Even the short document without math or Mermaid exceeded the initial 60MiB comparison goal. Two different 100KiB structures differed by about 27MiB in median usage, so byte count alone is insufficient to predict memory. This compares different document structures, not a single isolated heading-count variable.

Follow-up investigation should examine ordinary document-rendering costs and resource lifetime after window close. No renderer replacement or teardown fix was made, and no improvement has been measured.

## Candidate and method

- Source: `8768530d030eca9b6e15c40b283d9e240296fd2c`, Leaflit 0.1.0 Release arm64.
- Executable SHA-256: `e8a08c1690631337f49801d039a4ee11d3c93f60d9eb371b7515578bae82cce7`.
- Environment: Apple M3, macOS 26.6.2. No earlier macOS or Intel result is implied.
- Tools: `footprint -f bytes --noCategories -j`, `ps`, existing app display-completion logs, and target-PID accessibility window closing.
- Metric: `total footprint` for the app and its new WebKit helpers. RSS is a different metric. One MiB is 1,048,576 bytes.
- Each run starts a new app and new helpers, identified against prelaunch PIDs. The harness aborts on an unrelated new Leaflit/WebKit process. It does not stop preexisting user processes.
- Wait fifteen seconds after document completion, or after window appearance for the empty condition. Collect three snapshots about half a second apart and use their median as the run value.
- Run each primary condition five times, rotating the first condition in each round. Summarize the five run values by median, minimum and maximum.
- Press the actual close button and verify accessibility window count zero. Keep the app running. Collect three snapshots after five seconds; in the final primary round also collect three after thirty seconds. The latter is one run per condition, not five repeated runs.
- Do not clear OS caches or close unrelated apps. This is not a dedicated, otherwise idle system. Record host memory state before and after collection.
- Record generated-input byte counts and SHA-256 values and confirm unchanged content after each run. Do not change PATH, Finder defaults, networking or system appearance.

## Input structure

Primary documents share the body of `Fixtures/Benchmark100KiB.md`. Replace the one formula and/or one flowchart with plain text and spaces while preserving newline positions, body offsets and the exact 102400-byte length. Actual parser results confirm one formula only in math/combined, and one diagram only in Mermaid/combined.

The heading-heavy plain input has 1,484 headings and 4,452 body HTML elements. It does not represent every 100KiB document. The additional 1KiB input has one heading and eleven elements; the heading-light 100KiB input has thirteen headings and 919 elements. Both additional inputs include bold, Korean and emoji to exercise the same font range. Words and line breaks also differ, so this is not a heading-count-only causal experiment.

## Preliminary and primary collection

The preliminary pass sampled about five seconds after completion, similar to the original resource run. Some GPU snapshots fell from about 72MiB to about 12MiB while collecting. One math run changed from 208.2 to 203.6 to 140.2MiB across three snapshots. That preliminary pass was stopped and the settling delay increased to fifteen seconds. Preliminary samples were not counted toward primary repetitions.

GPU and content usage still varied after fifteen seconds. This point is not assumed to be a universally stable minimum; retain ranges and process details.

Primary collection stopped once when a display-completion event was missing, and once when a helper exited during post-close footprint enumeration. Neither incomplete execution was counted. Collection resumed while preserving completed runs. The cause of the missing event was not assigned to either the app or the harness. After resuming, the harness additionally raised the target window through accessibility, beyond the app's existing activation request. Per-run `raisedWindowBeforeWait` and dataset `resumedAt` distinguish that change. When a helper exits during enumeration, preserve the failed raw capture and remeasure surviving originally owned PIDs.

## Reproduction and tool verification

Start with Leaflit closed. The local environment already had accessibility permission. Inputs, raw footprint JSON/text and results remain under `build/memory-cases/<timestamp>/`. Original repository documents are not changed.

```sh
python3 scripts/measure-memory-cases.py
python3 scripts/measure-memory-cases.py --cases short prose --repeats 3 --late-close-delay 0
# Resume only after validating the same candidate and measurement parameters.
python3 scripts/measure-memory-cases.py --resume build/memory-cases/20261018-235932
```

Verified Python syntax, exact byte counts and UTF-8 for all six generated inputs, formula/diagram counts with the actual Markdown parser, and repetition/snapshot counts for all 31 complete runs. All 201 completed snapshots were validated: 93 loaded, 93 post-close and fifteen late-close. Input and executable hashes were unchanged. Product and web sources were unchanged. A product-wide regression suite was not rerun for this measurement-only work. No memory-reduction implementation or measured improvement is claimed.
