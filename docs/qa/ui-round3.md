# Independent UI review, round 3

## Candidate and environment

An independent reviewer executed the approved final round from the implementation plan, test plan and `ui-round3-plan.md` on candidate `dffa027d7aa566b915ea0a0fe59a80af73922e01`, dated 2026-10-18 KST. Environment: Apple M3, 24GB RAM, arm64, macOS 26.6.2 build 25G83. macOS 14 and 15 were not run.

Release app: `build/Leaflit-0.1.0/Leaflit.app`; executable SHA-256: `e8a08c1690631337f49801d039a4ee11d3c93f60d9eb371b7515578bae82cce7`. Read-only Fixtures and reviewer-created `build/qa-round3` data were used. User documents, Finder defaults and PATH were unchanged.

## Independent automated execution

The reviewer directly executed the following commands rather than copying the implementer's results:

```sh
./scripts/verify.sh > build/verify-independent.log 2>&1
./scripts/build.sh > build/build-independent.log 2>&1
python3 scripts/benchmark.py > build/benchmark-independent.log 2>&1
python3 scripts/measure-resources.py > build/resources-independent.log 2>&1
```

| Check | Observed result |
| --- | --- |
| Web syntax | 4 passed, 0 failed |
| Foundation module | 6 passed, 0 failed |
| Xcode tests | 18 passed, 0 failed: 6 document-module tests and 12 actual WKWebView integration tests |
| Production dependencies | `npm audit --omit=dev`: 0 vulnerabilities |
| Release build | `BUILD SUCCEEDED`; build-info and verification recorded the same candidate SHA |

Result bundle: `build/DerivedData/Logs/Test/Test-Leaflit-2026.10.18_22-02-35-+0900.xcresult`. The reviewer exported and inspected 640pt, 200% light/dark PNGs under `build/qa-screenshots`. Headings, Korean, emoji, math and Mermaid Open/Read labels were readable without page-level horizontal overflow. These are development-test-window captures, distinct from manually operating the Release app.

## Performance and resources

Input: a fixed 102400-byte document. Body display and math/diagram completion were measured separately. Each cold open used a new process; OS file caches were not cleared. Twenty document transitions used the actual WKWebView integration test. p95 is the nineteenth of twenty sorted samples.

| Operation | Count | Body median | Body p95 | Complete median | Complete p95 |
| --- | ---: | ---: | ---: | ---: | ---: |
| Cold open | 20 | 1169.9ms | 1288.9ms | 1508.2ms | 1622.7ms |
| Document transition | 20 | 115.0ms | 121.5ms | 172.3ms | 192.7ms |

Cold maxima: body 2033.6ms, complete 2400.2ms. Transition maxima: body 152.0ms, complete 253.9ms. One 100KiB replacement-save sample displayed its body in 252.3ms. The approximately 1MiB document measured 880.7/909.6ms; approximately 5MiB measured 3074.3/3107.4ms. Actual sizes were 1048573 and 5242873 bytes, and automated before/after comparisons confirmed source immutability.

Raw samples: `build/benchmarks/cold-opens.json`, `build/qa-screenshots/24D0381D-E377-49F7-AADE-40317D8B1AF1.json`, `build/qa-round3/timing-summary.json`. Installed app size: 5.5MiB by `du -sh`.

App and newly started WebContent, GPU and Networking helpers were identified against a prelaunch PID baseline. Sixty idle samples spanned 70.34 seconds; aggregate CPU was 0.142%. Final RSS sum was 142.375MiB, of which app-only RSS was about 74.45MiB. Initial footprint total was 155749664 bytes, about 148.53MiB, including app-only footprint about 32.99MiB. RSS and footprint differ in definition and sampling time. The combined 60MiB target was not met. Raw files: `build/benchmarks/resources.json`, `footprint.json`, `footprint.txt`.

## Actual Release UI execution

After automated checks and resource measurements, the reviewer opened the final app and observed screenshots and accessibility trees with `cua_repl`. Screenshots are retained in execution records, not separate PNGs.

| Item | Action and observation | Result |
| --- | --- | --- |
| Empty state | Document icon, `Open a Markdown file`, drop guidance and Open appeared. | Passed |
| Open menu | Cmd+O opened the standard panel. Go to Folder path entry/completion was not delivered reliably enough to finish file selection. | Panel passed; selection unverified |
| Launcher and paths | The bundled launcher opened `build/qa-round3/한글 live file.md`. Unicode/space filename, Korean and emoji appeared. Reopening activated the same window. | Passed |
| Duplicate anchor | Clicked `Repeated heading`; scrollbar moved from 0 to 1 and the second Repeat with `Second repeated heading target.` became visible. | Passed |
| Normal save | At scroll value 0.500073, an ordinary write changed `Read marker 20` to `Read marker 20 UPDATED` at the same screen height. | Passed |
| Replacement and rapid saves | Twenty temporary-file/rename replacements ended at `Read marker 20 FINAL 20`, preserving reading position. | Passed |
| Identical save and sibling change | Replaced with identical bytes, created an unrelated sibling txt, then followed Next document to next page.markdown and Target in the same window. | Passed |
| Toolbar Back | Restored the previous document, marker 20 and scroll value 0.500073. | Passed |
| View menu | Initially Back and all three zoom items were disabled despite enabled toolbar Back. One recheck after launcher activation still showed disabled zoom. A bounded final check with a fresh connection is recorded below. | Initial failure observation; final check passed |
| Delete | Deleted reviewer-owned data; previous content remained with the stale-content message, Retry and Open. Retry retained the body and displayed read failure. | Passed |
| Restore deleted file | Recreated the file; error disappeared and `Read marker 20 RECOVERED` appeared at the prior position. | Passed |
| Invalid UTF-8 | Invalid bytes retained the previous body with refresh error, Retry and Open. Valid bytes were restored, but that restored screen was not observed again in this case. | Error display passed; this recovery view unverified |
| Formula border | Render and safety.md showed source and error inside one continuous rectangle, correcting round two's fragments. | Recovered, passed |
| Hostile source and errors | Script and javascript-link text appeared without an alert. Invalid math/Mermaid retained source and a short error. | Executed display scope passed |
| Mermaid accessibility | Open and Read appeared inside boxes; AX exposed `image Diagram: Open. Read`. | Passed |
| Local images | Reviewer PNG/JPEG green squares rendered. Missing, wrong-format PNG and remote images showed alternative text and `image unavailable`. | Passed |
| Search | Toolbar Find opened the row; `Leaflit` selected a match. Initial Cmd+F did not show the row. A bounded fresh-connection check appears below. | Toolbar passed; final Cmd+F check passed |
| Copy | Triple-click, Cmd+C and Cmd+V into search did not produce copied content. Clipboard contents were not read independently. | Unverified in this round |
| Finder Open With | Right-clicked Fixtures/Welcome.md in Finder and selected Open With > Leaflit. Welcome rendered in one final-Release process. Visual Studio Code remained the default handler. | Passed |

Native scroll-tool calls produced no screen movement; the reviewer instead adjusted visible scrollbar accessibility values. This tool difference is not classified as an app scrolling failure. Remote-image fallback observations and automated blocked-fetch evidence are distinct. OS networking was not disabled.

## VoiceOver and omissions

Launching VoiceOver directly returned `timeoutReached` without a running instance. Utility did not offer the activation action, so Settings > Accessibility > VoiceOver was used. The initial off value was recorded, changed to on, and the startup dialog accepted. After closing the tutorial, the actual system VoiceOver process was confirmed.

Ctrl+Option+Right in Leaflit did not yield verifiable VoiceOver cursor movement or speech through the tool. Activation was confirmed; spoken document, link, table and math navigation remained unverified. An AX name alone is not a speech-navigation pass.

Settings was restored to off and read back. The reviewer closed Settings and terminated only reviewer-started VoiceOver Quickstart helpers by exact path/PID. Final VoiceOver process queries were empty.

An actual Finder-to-Leaflit file drop was not executed: app-local coordinates did not provide a grounded cross-app drag path. This was not classified as a product drop failure. Small window, 200% zoom and both appearances were checked by actual WKWebView integration snapshots. Release interaction in this round used system dark mode; a Release-window light transition was not performed. Full keyboard-menu navigation, opening a web link in the default browser, speech and earlier OS versions were not verified.

## Bounded final menu and Find confirmation

After the initial report, the implementer added a test for real NSMenu activation and command dispatch without changing product source. That execution is not included in the independent eighteen-test count above. A single fresh-connection confirmation was requested only for the two inconsistent menu/Find observations; no other UI regression round was repeated.

The reviewer reacquired the exact Release app with `getApp`, followed Welcome's relative link to Next Page, and clicked View. The first attempt returned `originalApplicationActivationFailed` before menu state. After reconnecting once, Back, Zoom In, Zoom Out and Actual Size were enabled. Clicking Back visibly returned to Welcome. Cmd+F then opened the find row with focus in Find in Document.

Back and Find passed in that final actual check. Earlier disabled/ignored-input observations are retained. Product source and executable hash did not change, and the tool reported an activation error, so those earlier observations alone do not establish a product defect. The app was quit with Cmd+Q; Leaflit and VoiceOver processes were absent and UI control was returned.

## Source preservation

`build/qa-round3/source-hashes-before.json` and `source-hashes-after.json` matched for all four Fixtures:

| Document | Before/after SHA-256 |
| --- | --- |
| Benchmark100KiB.md | `55464dacf92db737fbec845a17723c38da683d0fcef0b52d994a0040edff7f61` |
| Welcome.md | `41eceab164f37bcc04639ca4d7cf41a91831b699849b54ca011632e640dc4201` |
| Next Page.markdown | `af959c36eabbe02c4deac10651fa62be5fcaadbed1bd1cf9cbea4e7c1e6df451` |
| Errors.mdown | `4ea2141055ccf8f518f87da78ad0c9878d9c705394dd3d7782d9a3e32a7fcf19` |

No product source, mobile device, user document, PATH entry or Finder default was changed. Both the initial review and bounded confirmation returned shared UI control.
