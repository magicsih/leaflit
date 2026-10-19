# Files and Outline: independent UI review round 2

## Result

Round 2 is **failed**. The expanded-directory repair passed actual navigation and recovery without the round 1 collapse workaround. Two resize problems and a render-completion stall remain to be addressed before the final integrated review. Actual VoiceOver navigation is **unverified** because its output and cursor could not be observed through the available UI surface.

This independent actual-app review followed the [round 2 plan](sidebar-ui-round2-plan.md). No product code, test, build, signing or publication action was performed by this reviewer. A later repair must have its own executed evidence; it cannot replace the observations recorded here.

## Candidate and environment

| Item | Observed identity |
| --- | --- |
| Product source | `8746180602a01f3534341e923b17421989f779f0` |
| App | `build/Leaflit-0.2.0/Leaflit.app`, normal Release, version 0.2.0 |
| Executable SHA-256 | `08339f6df3e6f621a45b2433068aa4d214dbb187a4a82492be5f4468f96bbbea`, matched before and after review |
| Build-info | Same source SHA and binary hash, arm64, minimum OS 14.0, ad-hoc signing |
| Runtime | Apple M3, macOS 26.6.2, build 25G83 |
| Execution | 2026-10-19 KST, approximately 07:29–07:39 |
| Appearance | Initial Auto, visibly light; Dark selected for review; Auto restored |
| Reviewer process | PID 51552, exact candidate executable path confirmed before input |

The implementer's handoff reports five JavaScript, eight core, seven packaging and 30 Xcode tests passed, including the expanded-list settling regression, plus a normal Release build. These were not rerun or counted as this reviewer's rendered checks. Documentation and measurement-tool commits advanced repository HEAD during the review; the running binary remained unchanged. macOS 14 was not executed.

All inputs used `cua_repl`. Fixtures and raw evidence are isolated under `build/qa/sidebar-round2-8746180/`. Screenshot files retain the raw tool bytes with historical `.png` filenames; their actual encoding is JPEG. `screenshot-manifest.json` records dimensions, capture times and hashes. A filename containing a target width is not a measurement; actual dimensions are reported below.

## Failures

### Sidebar segments clip after resizing

With A open in Outline, close Find, then drag the divider from about 188pt to 320pt and back toward the minimum. The final native splitter value was 188. At 320, both labels fitted. After shrinking, Files occupied most of the control and the selected Outline segment became a narrow blue sliver with its label clipped. Both choices remained in the accessibility tree. Selecting Files later restored their visual balance, so that interaction is a recovery observation, not a pass for resizing.

Evidence: `40-sidebar-width320.png`, `40-sidebar-width320.ax.txt`, `41-sidebar-width180.png` and `41-sidebar-width180.ax.txt`, captured at 07:38:00 and 07:38:01. Both outer captures are 720×784; the second filename records the drag target, while the observed splitter value is 188.

### Error and Find bars prevent the planned 480pt width

With Find containing `Inline`, move the displayed reviewer-owned A.md out of the selected root. The previous body stays visible and Retry/Open are available. Attempting a 640pt window yielded an outer capture of 738×784. Shrinking from the left edge yielded 578×784, then a further attempt toward 480 stopped at 550×784. The sidebar collapsed and actions remained visible, but the intended 480pt error layout was not achievable. Clicking Retry while the file was still missing changed the status to the shorter read-failure message.

Evidence: `33-missing-document640.png` is **738×784**, `34-missing-document-left-edge-resize.png` is **578×784**, and `35-error480-controls.png` is **550×784**. These observed limits must not be reported as 640pt or 480pt passes. A separate drag from an obsolete right-edge coordinate returned `windowNotFoundAtPosition`; the subsequent left-edge attempts and captures establish the bounds above. That tool error is not a separate product defect.

### Rendering and outline completion stall after live appearance change

Before appearance changes, Wide.md displayed rendered inline/display math and a Mermaid diagram, including at 200% zoom. After selecting Dark in System Settings, the colors changed but formulas and the diagram appeared as raw source. Subsequent Files/Outline switches, native file navigation, Back, Find, actual keyboard input and native window Raise did not clear the observed raw state. A then showed `No headings in this document` even though its body contained headings.

The first confirmed dark raw capture is `23-dark-outline-confirmed.png` at 07:32:45. `26-dark-a-render.png` at 07:33:09 shows raw math and Mermaid after A navigation and Find. `28-active-outline-render.png` and `29-raised-active-render.png` at 07:33:38 and 07:33:45 show the missing native outline. Settings was quit and the candidate was raised again; `32-voiceover-active-attempt.png` at 07:36:01 still shows raw source. Native actions were delivered to Leaflit, but OS compositor occlusion and foreground status were not instrumented, so those are not established causes.

After the later isolated A deletion/recreation, rendering eventually completed. The post-recovery accessibility state includes KaTeX nodes and a diagram image, and `37-recovered-outline.png` at 07:37:47 shows the populated outline and rendered formula/diagram again. `36-recreated-document-body.png` had already shown the new recovery marker. The later position differed from that marker view while delayed completion settled. This is a prolonged observed stall with later recovery, not a claim of permanent failure. The exact OS trigger and causal mechanism require controlled regression verification.

The preliminary `22-dark-outline.png` filename is misleading: its pixels are still light. Only the later captures with confirmed dark pixels are used for dark observations.

## Executed checks

| Check | Actual observation | Result and evidence |
| --- | --- | --- |
| Expanded root and nested file clicks | Guides and Nested stayed expanded; root A and nested Deep opened in the same window. Command-[ returned to A with the tree intact. | Pass; `01-expanded-settled` through `04-back-expanded`. No collapse workaround. |
| Re-expansion freshness | Collapse loaded Guides, add new-after-collapse.md, re-expand and open it. Return to A, collapse Guides, move the added file outside the root and re-expand. | Pass; new file appeared and opened, then disappeared; `05-reexpand-new-file-open`, `06-reexpand-removal`, mutation log. |
| Error retention and expanded recovery | Error A and Readable B stayed expanded. Mode 000 produced Error A's message and Retry. A new file in Readable B appeared without clearing that failure. Restore mode 755 and click Retry; then open recovered a.md with Error A, Readable B, Guides and Nested expanded. | Pass; `07-expanded-permission-error` through `10-recovered-file-open`. No collapse workaround. |
| Copy through a real paste path | Triple-click the body sentence, Command-C, Command-F, Command-V. Find contained `Copy this exact sentence.` with paragraph trailing whitespace. | Copy pass; `12-copy-paste-find`. The pasted whitespace caused Not found; this is not a search-match pass for that exact pasted paragraph. |
| Find shortcuts | Type Marker 1., use Command-G and Shift-Command-G, then Done. A matching Marker 1 was highlighted in the body. | Pass; `13-width640`. Later typing Recovery marker found the recreated content; `36-recreated-document-body`. |
| Normal small windows | Resize to actual 640×784 and 480×784. At 640 both panes were usable; at 480 sidebar collapsed and body/toggle remained available. | Pass for normal reading; `13-width640` through `15-width480-auto-collapse`. Error layout is the separate failure above. |
| Explicit visibility and widening | Control-Command-S at 480 showed the sidebar and widened to 720. Explicitly hide it, then widen to 900; it stayed hidden. Show again. | Pass; `16-shortcut-shows-widens`, `17-explicit-hidden-after-widen`. |
| View menu and toolbar toggle | View > Toggle Sidebar hid it in a fresh reader; the visible toolbar Toggle Sidebar showed it again. | Pass; final native input log and accessibility readback. |
| 200% and overflow | Command-0 then ten Command-plus inputs. At 640 the table and code had independent horizontal scrolling; horizontal input moved the table. Math and Mermaid remained legible. At 480 body reading continued with sidebar collapsed. Restore Command-0. | Pass; `18-zoom200-outline` through `21-zoom200-width480`. Local image was a one-pixel test PNG; no image-quality claim. |
| Divider and long labels | Native divider reached 320 and returned to 188. Long labels truncated; lists and body stayed usable. | Partial; native resizing works, but segment labels clip after shrinking as described above. |
| Appearance colors | Dark changed native sidebar, selected rows and body colors. Text remained legible; Auto restored light pixels. | Color pass for populated states, completion failure above; `23`, `24`, `26`, `27`. Empty/error dark states were not separately executed. |
| Actual keyboard focus | With the system Keyboard navigation setting enabled, Tab traversed Find actions, toolbar, mode control and list. Left focused Files, Space selected it, Tab reached Open Folder and the Files tree, and Down selected B. Command-[ returned. | Pass for these actual paths; `keyboard-tab-trace.json`, `30-keyboard-files-navigation`. The setting was restored off. |
| Keyboard outline operation | After rendering recovered, click the root heading to seed focus, Down selected Reading Essentials, Left collapsed it, Right expanded it and Down selected Skipped level. The body showed the corresponding heading. | Pass for arrow navigation from seeded list focus; `38-keyboard-outline-collapse`, `39-keyboard-outline-anchor`. This is not a fully mouse-free VoiceOver pass. |
| Document loss and recreation | Move displayed A away: previous content and error/actions remain. Retry while still missing. Recreate A with a new heading, type its marker into Find and switch to Outline. | Body/error recovery pass and eventual outline reconciliation; `33` through `37`. The delayed renderer completion and 480pt limit remain failures. |
| Empty root | Choosing Empty while A remains open showed Outside selected folder and preserved the body. In a fresh reader, explicitly choosing Empty showed No Markdown files and Open Folder. | Pass; `42-empty-root-outside-document`, `43-empty-folder-new-window`. |

An early stale-element error during the collapsed-removal setup was corrected by reading fresh state. Some accessibility expansion/click attempts did not visibly change the target; refreshed coordinates were then used, and only the resulting visible state is counted. These tool sequencing incidents are not product failures or passes for unobserved actions.

## VoiceOver limitation

VoiceOver was initially off. Command-F5 sent to Leaflit did not start it. The reviewer enabled the native Accessibility > VoiceOver switch. A separate VoiceOver Quickstart welcome window blocked startup; the reviewer selected Use VoiceOver without changing its welcome preference. A process readback then confirmed the system VoiceOver runtime, PID 56715.

The VoiceOver Utility showed Show VoiceOver cursor and Show caption panel already enabled; neither setting was changed. Actual Control-Option-Right inputs were sent after raising Leaflit. However, binding the VoiceOver app timed out, per-app captures exposed no cursor/caption overlay, and audio output was unavailable. Therefore the reviewer could not observe actual spoken control names, VoiceOver cursor movement or complete Files/Outline/recovery actions through VoiceOver. `31-voiceover-navigation-attempt` and `32-voiceover-active-attempt` preserve the attempts. Accessibility labels and standard keyboard success do not establish those passes.

The native VoiceOver switch was restored off and the runtime process was confirmed absent. Actual VoiceOver navigation remains unverified, with this concrete observation limit.

## Integrity, remaining scope and cleanup

Fourteen of the fifteen original regular fixture files matched their initial SHA-256 after reading. Only reviewer-owned A.md differed intentionally: it was moved out for failure testing and recreated from its recovery copy with a new heading/marker. Added files, the removed test file's retained backup, mutation timestamps and restored directory permissions are recorded locally. No user document or repository fixture was modified. The candidate executable hash remained unchanged.

The outcome does not claim network-disabled rendering, JPEG quality, Finder/open routes, a no-heading file in both appearances, VoiceOver completion, controlled stale-result timing or performance measurements. Those unexecuted checks are not inferred from source or other reviewers. Round 3 remains the final integrated review; any unresolved work after it requires the policy's explicit additional-round decision.

Global settings were restored: appearance Auto, scrollbars automatic, Keyboard navigation off and VoiceOver off. One stale-index click briefly selected Always scrollbars; it was immediately corrected through the native setting and the restored state was recorded. VoiceOver cursor/caption preferences were inspected but unchanged. Reviewer-started System Settings and VoiceOver Utility were quit.

Leaflit PID 51552, including its reviewer-created second empty window, was quit using Command-Q. Process readback confirmed it absent, VoiceOver absent and original user Leaflit PIDs 95552 and 96665 still running at their unchanged 0.1.0 paths. No build/test/helper process remains from this reviewer. Exclusive UI control was explicitly returned to the implementer before this report was written.
