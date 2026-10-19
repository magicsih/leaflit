# Files and Outline: independent rendered review round 3

Completed on 2026-10-19 KST. This was the third and final authorized rendered review of the sidebar change, following the [approved plan](sidebar-ui-round3-plan.md). No fourth review was started. The reviewer operated the actual normal Release app with native CUA input. Preparation, source review, automated tests and other reviewers' observations are separate evidence.

## Candidate and result

- Product source: `eebc9489216d3ed46e26c2a1850d196d0db3d5ff`.
- App: `build/Leaflit-0.2.0/Leaflit.app`, version 0.2.0, Apple Silicon.
- Executable SHA-256: `5688e944bab1950fb0f01e6b3b93bde1ec4d71dcb02584cee3d8a60a3c6a2333`.
- Environment: the current Apple M3/macOS 26.6.2 development host. macOS 14 remains the deployment target and was not executed.
- Outcome: no new product defect was observed in the executed scenarios. Finder Open With, actual cross-app drop, VoiceOver speech/cursor behavior and execution with host networking disabled remain unverified. These limitations are not passes.
- Raw observations: `build/qa/sidebar-round3-eebc948/`, including numbered JPEG/AX captures, `execution.json`, `mutations.jsonl`, initial hashes and `completion.json`.

Preserved actual screens: [Outline with local images](screenshots/sidebar-outline-0.2.0.jpg) and [Files after native root selection](screenshots/sidebar-files-0.2.0.jpg).

Independent automation on the same product candidate passed web 8, core 8, packaging 7 and Release Xcode 34 tests, followed by a normal Release build. See `build/sidebar-verification/result-eebc948.json` and its verify/build logs. Automated paused-frame, early-scroll, large-document and 20-transition checks are attributed to that execution, not to this rendered round. The transition attachment's timing provenance is not established; it is linked as functional evidence only, without a numerical timing comparison.

## Executed observations

| Scenario | Actual observation | Raw capture stems |
| --- | --- | --- |
| Divider fix | Dragged the real pane from approximately 320pt to actual 180pt. Both Files and Outline labels fit, and coordinate clicks on each label selected the intended mode at the narrow width. | 02–05 |
| Live appearance and background | Math, Mermaid and populated Outline rendered in Dark. Restored Auto, reactivated the reader after background exposure, scrolled and observed active heading tracking. | 06–08 |
| Find plus recovery at 480pt | A long query and missing current file were visible together at actual 480pt width. Previous/Next, Retry and Open were operated, with the old body preserved. Open's native chooser was cancelled. Restoring the fixture recovered the document. | 09–13 |
| Valid local images | A decoded PNG and JPEG both rendered. A missing image retained its alternative text. Initial JPEG failure came from invalid generated fixture bytes, corrected and recorded separately. | 13, fixture-generation-correction |
| Folder selection and expansion | Chose the owned Root using the native chooser, expanded Guides and Nested, opened Deep, navigated by keyboard to a Unicode/space filename and used Command-[ to return. Expanded child rows remained stable. | 14–19 |
| Find, mode and visibility | Typed a known query, used Command-G and Shift-Command-G, switched Files/Outline and hid/showed the sidebar with Control-Command-S. Query and reading position survived. | 20–23 |
| Duplicate anchors and copying | Clicked the second exact Duplicate heading and reached its second marker. Selected/copied a sentence and pasted it into Find, observing the selected text including paragraph whitespace. | 24–25 |
| Directory refresh | Changed a collapsed folder, expanded it to see the new file, opened it, then removed it while expanded. Nested expansion and unrelated selection survived. | 26–29 |
| Independent directory errors | Denied access to owned Error A while Readable B remained expanded. A new Readable B file appeared without clearing Error A's message. Restored permissions and clicked Retry; Error A recovered. | 30–33 |
| Last revision and replacement save | Two rapid writes and an atomic replacement produced the final revision 3 in both body and Outline while retaining the prior visible reading position. Original Markdown bytes were restored afterward. | 34–35 |
| Root boundary and no headings | Followed an outside-root relative link in the current window, observed the unchanged selected root and unselected file tree, used Back, and opened a no-heading document. | 36–38 |
| Rendering and security | Invalid Mermaid and math retained readable source/errors. Script HTML and a dangerous link remained literal. Clicking the dangerous text did not execute or navigate. A remote image showed its blocked alternative. | 39–40 |
| Safe web navigation | Clicked the explicit safe example.com link and observed Example Domain in the default Chrome browser. Chrome was initially stopped; the reviewer closed only the newly opened test tab and browser process afterward. | 41–42 |
| Large Files | Selected a separate scale root with 1,000 root files plus 100 folders containing ten files each. Opened an expanded child, used Back, scrolled to middle file 0638 and last file 0999, and opened each intended body. | 43–49 |
| Large Outline and CLI | The bundled launcher opened a path with spaces in a separate owned window. Navigated a 2,000-heading document at first Unicode target 0000, middle 0993 and last 1998. Active selection followed body scrolling. Collapse/expand and a saved changed heading updated body and Outline together. | 50–58 |
| Native Open and duplicate window | Command-O and a real native chooser opened Reading.md in a separate window. Opening the same canonical file through exact-path `open -a` retained the same three owned windows, with one Reading.md entry. | 59, 63–64 AX |
| Small window and 200% | Reset Actual Size, clicked Zoom In ten times (the app's 10% steps), then resized to 640pt outer width. Text, math, diagram and both mode labels remained readable. Long table/code stayed in their own horizontal areas. Restored Actual Size and 900pt width. | 60–62, 66 |

The large document's generated Unicode titles have unique numeric suffixes. Exact duplicate-title behavior was exercised in Reading.md; it is not claimed as a separate exact-duplicate scale case. Large-tree navigation and small-root refresh were executed; a separate large-tree mutation sequence was not. The last anchor was visible at the bottom while the active heading tracked the viewport's top, so a persistent selection of the last row is not claimed. Horizontal table/code containment and scrollbars were observed; a particular horizontal displacement was not independently established by the attempted gesture.

## Tool limitations and unexecuted conditions

- Finder Open With: opened a new reviewer-owned Finder window and inspected the fixture's context menu, which included Leaflit 0.1.0 and 0.2.0. A full AX read changed element indexes before selection; the stale input opened a Share popover. No transmission occurred. The exact-app opening route remains unverified. The reviewer closed the popover/window and did not change the default association. Raw menu/result evidence is retained; the misleading result filename is not a pass.
- Cross-app drag/drop was not attempted because the available bound-window coordinate information did not establish a verified source-to-target screen mapping. No guessed drop onto an ambiguous Leaflit Dock item was made.
- VoiceOver: the native switch changed from off to on and the system Quickstart/tutorial opened. An actual Control-Option-Right input in the reader produced no observable speech or VoiceOver cursor evidence through the tool. Restored off. The Quickstart close action timed out; its newly owned process alone was then terminated. Speech/cursor navigation remains unverified, consistent with existing [issue #4](https://github.com/magicsih/leaflit/issues/4).
- Host networking was not disabled. Bundled local rendering and blocked remote content were observed, but network-isolated execution remains separate [issue #12](https://github.com/magicsih/leaflit/issues/12).
- Earlier OS versions and other hardware were not executed. No signing, notarization, publication, installation or mobile-device action occurred.
- Early motion during a deterministic paused-frame wait remains same-candidate automated evidence. This bounded rendered round does not claim to have reproduced the precise OS callback-pausing trigger from round 2.

## Preservation and closure

The owned native-review app PID 71441 exited. Pre-existing user app PIDs 95552 and 96665 remained present with their original paths. Auto appearance, Automatic scrollbars and VoiceOver off were restored; keyboard navigation was not changed. The reviewer-owned Finder window, newly launched browser and Settings app were closed.

All 2,015 original fixture entries remained present. All original Markdown hashes matched after restoration, including Reading.md (`ca8ce1658ab5181ba7d0229e6446c890af014f8369a7b451ca35068b25b24a69`) and the 2,000-heading file (`bfbceb487cd7ca6d791eb86fc08a2b2ed78b50e544d52099456c05ec95402755`). The only changed original files were the two deliberately corrected invalid image fixtures; their old bytes, decoder checks and new hashes remain under `fixture-generation-correction/`. Owned additions and mutation history are retained. The candidate executable still matched its supplied hash at closure.

The separate observation-matched memory, cold-open and idle CPU measurements follow the [measurement protocol](sidebar-measurement-protocol.md) and have their own [results and limits](sidebar-resources.md). Their readiness observations are controlled measurement setup, not an additional UI regression round.

Final handback after measurements restored the rendered round's initial Files/visible/180 preference through a separately owned native window, with actual 180pt pane observation and `Files`, `1`, `180` defaults readback. This differs from the later memory-protocol start, which was Outline/visible/222. Initial state is recorded in `execution.json`; final native AX/JPEG, process ownership and readback are under `build/sidebar-measurement-tool-check/prefs-restoration/`. The restoration process exited via Command-Q. Only preserved PIDs 95552, 96665 and the later unconfirmed public PID 77888 remained; no unowned window was closed. The supplied candidate executable hash was unchanged at final handback.
