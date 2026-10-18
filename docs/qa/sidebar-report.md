# Files and Outline sidebar verification

## Current state

The local 0.2.0 candidate implements the owner-approved [sidebar design](../design/navigation-sidebar/design.md). Two rendered reviews found defects, and their failed outcomes remain below. Independent verification and a normal Release build passed at `eebc948`; the third rendered review and matched resource comparison are in progress. This report does not declare the full L3 plan passed.

The endpoint is a verified local Release candidate. The published GitHub and Homebrew preview remains 0.1.0. No 0.2.0 distribution signing, notarization, publication, installation or downloaded-artifact verification has been performed.

## Product behavior

One native sidebar uses a fixed top `Files` and `Outline` control alongside the existing single WKWebView. Files starts without a root and browses only an explicitly selected folder. Directory children load on expansion; hidden entries, unsupported files and symbolic links are excluded. Selecting Markdown navigates in the current window with Back, while an already-open canonical document activates its existing window.

Outline labels and identities come from the existing Markdown parse. Native groups follow heading levels, duplicate and Unicode anchors target the rendered IDs, and scrolling updates the selected section. Switching modes preserves the reader, Find query and list state. Visibility, width and mode are remembered; narrow windows collapse the sidebar without replacing the user's visibility preference.

The app remains read-only. Folder-scoped navigation validates the selected file again after asynchronous position capture and before reading through its opened file descriptor. Intentional relative document links may leave the chosen folder while keeping its root unchanged. Renderer events retain document revisions and the existing local-resource and remote-request boundaries.

## Environment and artifact identity

- Runtime: Apple M3, macOS 26.6.2, build 25G83; Xcode 27.0, build 27A266a.
- Deployment target: macOS 14, Apple Silicon. Earlier macOS and Intel execution are not verified.
- Normal Release app: `build/Leaflit-0.2.0/Leaflit.app`, with adjacent `leaflit` launcher and `build-info.json`.
- Product candidate: `eebc9489216d3ed46e26c2a1850d196d0db3d5ff`.
- Executable SHA-256: `5688e944bab1950fb0f01e6b3b93bde1ec4d71dcb02584cee3d8a60a3c6a2333`.
- Signing state: local ad-hoc build, without Developer ID or notarization.

Later documentation and measurement-tool commits must be distinguished from changes to this running artifact. Preserve the public 0.1.0 output, installed app and existing user windows.

## Independent automated verification

An executor other than the implementer ran `./scripts/verify.sh Release` and then `./scripts/build.sh Release`. The Release integration suite uses `ENABLE_TESTABILITY=YES`; the local app is a separate ordinary clean Release build.

| Check | Result at eebc948 |
| --- | --- |
| JavaScript parser and frame-progress tests | 8 passed |
| Standalone Foundation module | 8 passed |
| Packaging tests | 7 passed |
| Xcode Release suite | 34 passed: 26 Reader tests and the same 8 core tests |
| Production dependency audit | No vulnerabilities reported |
| Normal Release build | Passed |

Do not count the repeated core tests as unique additional coverage. Integration includes real WKWebView rendering, all math delimiters, Mermaid, hostile HTML and links, blocked fetch, local images, Unicode and spaces, replacement saves, obsolete results, source immutability, Back, menu dispatch, visibility, narrow layout and 1MiB/5MiB bodies. New regressions cover outline identity, Files updates, permission-error retention, collapsed re-expansion, delayed path replacement, delayed duplicate-window activation, expanded-tree quiescence, paused-animation progress, initial-wait scrolling, actual pane shrink with both native mode buttons in bounds, and simultaneous Find/recovery at 480pt. Diagnostics observed a 180pt pane with two 79pt segments and a 480pt reader with 338pt fitting minimum.

Evidence is retained under ignored `build/sidebar-verification/`: `verify-eebc948.log`, `build-eebc948.log` and `result-eebc948.json`. The xcresult path is recorded in the result. Raw logs and generated build output are not committed.

## Failed candidates and corrections

Earlier failures remain separate from later passes:

- `f1f097c`: two native compile errors; no Release or UI pass.
- `9a959f5`: normal scoped reads were rejected because Foundation canonical paths used `/var` while the kernel file-descriptor path used `/private/var`. The anchor test also expected zero offset despite the existing 24pt scroll margin. The path comparison was normalized and the expectation corrected.
- `1b63b11`: automated verification passed, but [actual UI round 1](sidebar-ui-round1.md) failed. Restoring an expanded Files tree started another refresh, repeatedly replacing rows and blocking reliable selection.
- `1da6920`: the new regression failed independently. Expansion events increased from 275 after 250ms to 577 after another 300ms without filesystem changes.
- `8746180`: programmatic expansion restoration no longer starts another refresh. Full automation, including the new quiescence regression, passed. Actual corrected UI behavior must be recorded in the later review results.
- [Round 2](sidebar-ui-round2.md) confirmed expanded navigation and recovery without the workaround, but found clipped mode labels after divider shrink, a 550pt minimum with Find and recovery visible, and prolonged raw math/diagram placeholders with an empty Outline after a live appearance change. A later document mutation recovered rendering; the precise OS trigger remains unproven.
- `78eb9cd`: controlled paused-animation rendering and the 550pt layout failed. Its initial segment assertion inspected a group rather than the two radio buttons, so that assertion was not valid clipping evidence.
- `a5d2cb9`: corrected native accessibility traversal proved a 130pt overflow by the second mode button after shrinking the control.
- `5e5860d`: automation passed, but the executor noticed that explicit segment sizes prevented the pane from actually shrinking. The normal build was held. Stronger tests at `6d0d84f` failed on an actual 311pt pane and on completion resetting an intervening scroll to zero.
- `eebc948`: a mode control with no intrinsic horizontal width leaves sizing to the split view; explicit segment geometry is recomputed within it. Search and recovery text can shrink/wrap at 480pt. Rendering and outline updates use one-shot fallback timers when animation callbacks pause, retain timing provenance, cancel losing callbacks and preserve movement during the initial wait. Independent full verification and the normal Release build passed; actual round 3 remains in progress.

## Rendered reviews and resources

[Round 1](sidebar-ui-round1.md) records the failure, bounded workaround, observed passes and omissions. [Round 2](sidebar-ui-round2.md) confirms the expanded-tree correction and records its three additional failures. Keyboard selection, shortcuts and actual copy/paste passed; VoiceOver startup was confirmed, but speech/cursor navigation remained unverified and the original off state was restored. The [third review plan](sidebar-ui-round3-plan.md) covers all three corrections, integrated regression and large navigation lists.

The [matched resource protocol](sidebar-measurement-protocol.md) compares the public baseline with hidden, Files and Outline states on identical fixtures. Its 36 fresh processes, three footprint captures per run, UI readiness gates and helper ownership checks are separate from the three rendered review rounds. Results remain pending; baseline totals must not be described as sidebar measurements.

## Remaining gates

Complete the third actual-app review, matched resource comparison, final documentation and final-commit verification/build. Keep any unavailable VoiceOver, cross-app drag or older-OS coverage explicitly unverified and connected to its existing GitHub issue. A local build is not a public release.
