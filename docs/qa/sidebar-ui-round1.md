# Files and Outline: independent UI review round 1

## Result

Round 1 is **failed** because expanding a loaded Files directory produces repeated child-row refreshes and prevents reliable file selection. Collapsing the expanded directory allowed the remaining core reading and navigation checks to proceed. Passing observations below retain that workaround condition; they do not clear the failure.

The review followed the [round 1 plan](sidebar-ui-round1-plan.md). It was an actual rendered review by a reviewer distinct from the implementation author. No product code, builds, signing or publication were performed during this round. Later implementation changes must be verified in their own recorded round rather than replacing these outcomes.

## Candidate and environment

| Item | Observed identity |
| --- | --- |
| Product candidate | `1b63b110461180780a5edee517de556119f27395` |
| App | `build/Leaflit-0.2.0/Leaflit.app`, normal Release, bundle version 0.2.0 |
| Executable SHA-256 | `cc5e13d79cebcdf84916424c3c21e2de2114f98be21468e457664154c161eb23`, matched before and after UI execution |
| Runtime | Apple M3, macOS 26.6.2, build 25G83 |
| Xcode | 27.0, build 27A266a |
| Appearance and captures | Light appearance, native window captures of 900 × 784 pixels |
| Execution date | 2026-10-19 KST, approximately 07:18–07:25 |
| Repository changes during execution | Documentation, measurement tools and a new regression test advanced repository HEAD to `1da6920280bcd3ad1cd4b9017297b6da124adc70`. The running product binary remained the candidate above. |

The implementer handed off independent verification results of five JavaScript, eight core, seven packaging and 29 Xcode tests, plus a normal Release build. Those results were not rerun or counted as this reviewer's UI observations. macOS 14 remains a deployment target, not a runtime verified by this round.

Source hashes were refreshed in the plan before execution. The review used only isolated files under `build/qa/sidebar-round1-1b63b11/`. Existing user processes 95552 and 96665 ran 0.1.0 artifacts and were preserved throughout.

## Failure and reproduction

1. Launch the handed-off app and choose the isolated `Root Space` using Open Folder.
2. Expand `Guides`, which contains `Nested` and `Reading.md`.
3. Observe that child views become transient: accessibility snapshots repeatedly replace their row/cell identities, and some captures show gaps where children should appear. The children do appear in other captures; this is not a claim that they are permanently absent.
4. Click the root-level `A.md` using a fresh accessibility row and then its visible coordinates. The window remains the empty `Leaflit` window instead of opening A.
5. Collapse `Guides` and click A again. The app immediately opens A and selects it.

The same unstable expanded-child rendering appeared when `Error A` and `Readable B` were expanded for the recovery check. This affected ordinary file navigation, so it blocks a pass for the Files feature. The implementer's source review identified a possible cycle between refresh, reload, expansion restoration and unconditional refresh on expansion. That explanation is separate from the observed failure; the new regression test had not been run by this reviewer.

Evidence is in the ignored local directory `build/qa/sidebar-round1-1b63b11/`:

- `03-expanded-guides-blank.ax.txt` and its PNG record the expanded state. Despite the historical filename, that PNG contains visible child rows; compare the accessibility state and later captures rather than treating its name as a result.
- `04-a-loaded.ax.txt`, `04-a-loaded.png` and `05-a-coordinate-open.ax.txt` retain the empty `Leaflit` title after file-selection attempts.
- `06-a-collapsed.ax.txt` and `06-a-collapsed.png` show the same file opening once Guides is collapsed.
- `25-expanded-recovery-folders.ax.txt` and `25-expanded-recovery-folders.png` show expanded directories with child gaps during the later planned check.

An early stale-element error immediately after expanding Guides was a tool sequencing error and is not counted as an app failure. The file-click observations above used refreshed state or the actual screenshot coordinates. No repaired binary or additional review round was attempted.

## Executed checks

Each numbered evidence stem below has an actual screenshot and accessibility log unless stated otherwise. The body was read directly in the actual app; source inspection was not substituted for a rendered result.

| Check | Actual observation | Result and evidence |
| --- | --- | --- |
| Initial state | Files offered Open Folder with no selected root. Outline explained that no document was open. Canceling the folder chooser preserved the state. | Pass; `01-empty`, initial tool observations. |
| Explicit root and filtering | The native folder chooser opened Root Space. Directories appeared before A.md, B.mdown and No Headings.md. Hidden, unsupported, PNG and both inside/outside symlink entries were excluded from Files. | Pass for visible filtering and ordering; `02-files-root`. No filesystem tracing was performed to prove enumeration scope. |
| Directory expansion and file selection | Expanded Guides produced unstable rows and blocked A selection until Guides was collapsed. | Fail, as reproduced above. Nested file navigation and a settled expanded tree remain blocked. |
| Outline content | Native outline labels included plain-text bold, link and inline-code labels. Hierarchy represented a skipped heading level and duplicate and Unicode headings. | Pass; `07-outline`. |
| Anchor identity | The second Duplicate row moved to the heading followed by `Second duplicate.`. Skipped level and Unicode rows each moved to the matching visible heading. | Pass; `08-duplicate-anchor`, `09-skipped-anchor.ax.txt`, `11-unicode-anchor`. |
| Diagram and formula display | The actual body showed the `Open` and `Read` Mermaid labels and an inline E=mc² formula while checking anchors. | Display pass; `08-duplicate-anchor` and `11-unicode-anchor`. OS networking was not disabled, so this is not an offline-isolation pass. |
| Scroll tracking | Body scrolling advanced the selected Outline row from the Unicode heading to Meadow section 1 while later sections remained below it. | Pass; `12-outline-scroll-tracking`. |
| Mode preservation | With Find containing `Paragraph 2-1`, collapsed Reading Essentials and Outline scrolled to its end, switching to Files and back preserved the document, body position, query, outline collapse and outline scroll position. | Pass; `13-find-before-mode-switch` through `16-outline-switch-restored`. Files folders were collapsed to avoid the blocker. A separate Files-list scroll position was not exercised. |
| Same-window Files navigation and Back | Selecting B changed the existing window to B Destination. Toolbar Back returned to A with Paragraph 1-0 and Meadow section 2 in the same visible reading position as before the transition. | Pass with Files directories collapsed; `17-b-navigation`, `18-back-restores-a`. |
| Relative link outside root | Following Outside root opened Outside.md in the same window. Root Space remained selected as the root, no tree row was selected, and `Outside selected folder` appeared. | Pass; `19-outside-root`. |
| View Back | View > Back returned from Outside.md to A. The position matched the source-link area, which the native accessibility click had brought into view before navigation. | Pass; `20-view-back-restores-a`. This does not claim return to the earlier Meadow position after the link click itself scrolled the body. |
| No headings | Selecting No Headings.md and switching to Outline showed an empty list with `No headings in this document`. | Pass; `21-no-headings`. |
| Existing-window activation and selection restoration | Open created a separate B window with no folder root. Selecting B in A's Files list activated that existing B window. Window menu still listed A and B, and returning to A showed A selected with its original body. | Pass; `22-separate-b-window` through `24-original-a-selection-restored`. The controlled asynchronous duplicate-open race was not reproduced through native input. |
| Per-directory error retention | With Error A and Readable B expanded, setting reviewer-owned Error A to mode 000 showed `Could not read Error A.` and Retry. Adding Readable B/added.md appeared in that readable list while Error A's message and Retry remained. | Pass for error retention despite the expanded-tree blocker; `26-folder-error`, `27-error-after-unrelated-refresh`, `mutation-log.jsonl`. |
| Permission recovery | After collapsing both directories to stop repeated refreshes, Error A permissions were restored to 755. Clicking Retry cleared the error and hid Retry while A remained displayed. | Pass with the collapse workaround; `28-retry-after-permission-restore`. Expanded recovery stability remains blocked. |

## Unverified and blocked scope

The following are not passes from this round:

- A fresh add/remove inside a previously loaded collapsed directory was not verified on re-expansion. `Guides/added-while-collapsed.md` was prepared, but the known expansion failure and the agreed bounded stop prevented another expansion attempt.
- Normal settled refresh with preserved nested expansion, nested file selection, and full directory-error recovery while expanded are blocked by the same failure.
- The post-selection symlink replacement race and the delayed duplicate-window race require controlled integration timing. The handoff's independent automation covers them separately; this native UI round did not time or inject those races.
- Choosing a separate empty root, replacement-save heading reconciliation, file deletion and recreation, extended keyboard/VoiceOver, zoom, small windows, dark appearance, actual copy/paste and image-rendering quality were not executed in this bounded round. They remain assigned to the approved later coverage, rather than being inferred from source or prior 0.1.0 reviews.
- Performance, network-disabled execution, filesystem-read tracing and source-based claims about broad indexing were not measured here.

## Data integrity, evidence and cleanup

The twelve original regular fixture files matched their initial SHA-256 values after reading. Changes were limited to the two reviewer-created Markdown files and temporary Error A directory permissions. Error A ended at mode 755. `initial-hashes.json`, `final-hashes.json`, `mutation-log.jsonl`, `environment.json` and `execution-summary.json` retain the local evidence and are not committed build output.

Native UI screenshots and accessibility snapshots are saved under `build/qa/sidebar-round1-1b63b11/`; the execution summary lists screenshot hashes. Earlier snapshots include state differences; later captures include complete trees. Curated examples are `08-duplicate-anchor.png`, `16-outline-switch-restored.png`, `18-back-restores-a.png`, `19-outside-root.png`, `24-original-a-selection-restored.png` and `27-error-after-unrelated-refresh.png`.

The reviewer's 0.2.0 process, PID 41649, was terminated using the app's Quit command. A process readback confirmed it was absent and the original user PIDs 95552 and 96665 remained running. No other test or helper processes were started by this reviewer. UI control was returned to the implementer before writing this report; no further app input or execution was performed afterward.
