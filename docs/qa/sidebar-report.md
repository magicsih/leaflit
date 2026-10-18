# Files and Outline sidebar verification

## Current state

The local 0.2.0 candidate implements the owner-approved [sidebar design](../design/navigation-sidebar/design.md). Independent automated verification and a normal Release build passed at `8746180602a01f3534341e923b17421989f779f0`. The second and third rendered reviews and the matched resource comparison are still pending completion. This report does not declare the full L3 plan passed.

The endpoint is a verified local Release candidate. The published GitHub and Homebrew preview remains 0.1.0. No 0.2.0 distribution signing, notarization, publication, installation or downloaded-artifact verification has been performed.

## Product behavior

One native sidebar uses a fixed top `Files` and `Outline` control alongside the existing single WKWebView. Files starts without a root and browses only an explicitly selected folder. Directory children load on expansion; hidden entries, unsupported files and symbolic links are excluded. Selecting Markdown navigates in the current window with Back, while an already-open canonical document activates its existing window.

Outline labels and identities come from the existing Markdown parse. Native groups follow heading levels, duplicate and Unicode anchors target the rendered IDs, and scrolling updates the selected section. Switching modes preserves the reader, Find query and list state. Visibility, width and mode are remembered; narrow windows collapse the sidebar without replacing the user's visibility preference.

The app remains read-only. Folder-scoped navigation validates the selected file again after asynchronous position capture and before reading through its opened file descriptor. Intentional relative document links may leave the chosen folder while keeping its root unchanged. Renderer events retain document revisions and the existing local-resource and remote-request boundaries.

## Environment and artifact identity

- Runtime: Apple M3, macOS 26.6.2, build 25G83; Xcode 27.0, build 27A266a.
- Deployment target: macOS 14, Apple Silicon. Earlier macOS and Intel execution are not verified.
- Normal Release app: `build/Leaflit-0.2.0/Leaflit.app`, with adjacent `leaflit` launcher and `build-info.json`.
- Product candidate: `8746180602a01f3534341e923b17421989f779f0`.
- Executable SHA-256: `08339f6df3e6f621a45b2433068aa4d214dbb187a4a82492be5f4468f96bbbea`.
- Signing state: local ad-hoc build, without Developer ID or notarization.

Later documentation and measurement-tool commits must be distinguished from changes to this running artifact. Preserve the public 0.1.0 output, installed app and existing user windows.

## Independent automated verification

An executor other than the implementer ran `./scripts/verify.sh Release` and then `./scripts/build.sh Release`. The Release integration suite uses `ENABLE_TESTABILITY=YES`; the local app is a separate ordinary clean Release build.

| Check | Result at 8746180 |
| --- | --- |
| JavaScript parser tests | 5 passed |
| Standalone Foundation module | 8 passed |
| Packaging tests | 7 passed |
| Xcode Release suite | 30 passed: 22 Reader tests and the same 8 core tests |
| Production dependency audit | No vulnerabilities reported |
| Normal Release build | Passed |

Do not count the repeated core tests as unique additional coverage. Integration includes real WKWebView rendering, all math delimiters, Mermaid, hostile HTML and links, blocked fetch, local images, Unicode and spaces, replacement saves, obsolete results, source immutability, Back, menu dispatch, visibility, narrow layout and 1MiB/5MiB bodies. New regressions cover outline identity, Files updates, permission-error retention, collapsed re-expansion, delayed path replacement, delayed duplicate-window activation and expanded-tree quiescence.

Evidence is retained under ignored `build/sidebar-verification/`: `verify-8746180.log`, `build-8746180.log` and `result-8746180.json`. The xcresult path is recorded in the result. Raw logs and generated build output are not committed.

## Failed candidates and corrections

Earlier failures remain separate from later passes:

- `f1f097c`: two native compile errors; no Release or UI pass.
- `9a959f5`: normal scoped reads were rejected because Foundation canonical paths used `/var` while the kernel file-descriptor path used `/private/var`. The anchor test also expected zero offset despite the existing 24pt scroll margin. The path comparison was normalized and the expectation corrected.
- `1b63b11`: automated verification passed, but [actual UI round 1](sidebar-ui-round1.md) failed. Restoring an expanded Files tree started another refresh, repeatedly replacing rows and blocking reliable selection.
- `1da6920`: the new regression failed independently. Expansion events increased from 275 after 250ms to 577 after another 300ms without filesystem changes.
- `8746180`: programmatic expansion restoration no longer starts another refresh. Full automation, including the new quiescence regression, passed. Actual corrected UI behavior must be recorded in the later review results.

## Rendered reviews and resources

[Round 1](sidebar-ui-round1.md) records the failure, bounded workaround, observed passes and omissions. [Round 2 plan](sidebar-ui-round2-plan.md) adds direct verification of expanded-tree navigation and recovery before small-window, zoom, keyboard and VoiceOver checks. The third review will cover integrated regression and large navigation lists.

The [matched resource protocol](sidebar-measurement-protocol.md) compares the public baseline with hidden, Files and Outline states on identical fixtures. Its 36 fresh processes, three footprint captures per run, UI readiness gates and helper ownership checks are separate from the three rendered review rounds. Results remain pending; baseline totals must not be described as sidebar measurements.

## Remaining gates

Complete the second and third actual-app reviews, matched resource comparison, final documentation and final-commit verification/build. Keep any unavailable VoiceOver, cross-app drag or older-OS coverage explicitly unverified and connected to its existing GitHub issue. A local build is not a public release.
