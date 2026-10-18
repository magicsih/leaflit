# Independent UI review, round 3: execution plan

Prepared 2026-10-18 KST for an independent reviewer. Authorization: the owner-provided plan, `docs/design/0.1.0/design.md` and `test-plan.json`. This personal magicsih repository is not subject to the Seorilabs organization validator.

## Timing and isolation

Wait for the implementer's final SHA, Release path and exclusive execution handoff, after round two has returned the shared UI. Do not launch, build, test or operate the screen before handoff. Review Leaflit 0.1.0 for Apple Silicon and the same-source macOS development tests. Distinguish the macOS 14 build target from the actual runtime environment.

Do not change user documents, Finder defaults or PATH; do not access mobile devices or distribute externally. Hash existing Fixtures before and after reading. Create reload/deletion/recovery data only under `build/qa-round3`, and modify only that data. Judge UI behavior from actual screenshots and accessibility trees through `cua_repl`; DOM/source-only checks are not UI passes. Record candidate, environment, logs, results, tool limitations and omissions in `ui-round3.md`.

## Actual-app coverage

| Area | Action | Expected result |
| --- | --- | --- |
| Open and windows | Exercise empty state, Open and launcher with Unicode/space paths; reopen one file and open another. | Existing file activates its window; separate files use separate windows. |
| Navigation and commands | Follow relative links and duplicate heading anchors; use toolbar, View and available shortcuts; search and copy. | Correct document/window, restored reading position, working match movement and copy. |
| Saves | Read the middle of a long document; perform normal, atomic and rapid saves. | Last content wins and the visible reading block keeps its position. |
| Unchanged and sibling files | Save identical bytes, create an unrelated sibling, then follow a link and Back. | No needless visual change; navigation remains usable. |
| Delete and recover | Delete reviewer-owned data, check retained content, stale status, Retry and Open, then restore it. | No crash or blank replacement; recovery displays current content. |
| Read failure | Write invalid UTF-8 to reviewer-owned data, then restore it. | Short error and recovery actions, followed by normal display. |
| Safety and errors | Render hostile HTML, unsafe URLs, remote images and invalid math/Mermaid. | No script or unsafe navigation; source and readable errors remain; one continuous formula-error border. |
| Local images | Open allowed PNG/JPEG, missing and malformed images. | Valid images render; other cases show alternative text. |
| Reading and accessibility | Small window, 200%, both appearances, keyboard and possible actual VoiceOver navigation. | Readable text and horizontal code/table scrolling; diagram names contain node labels or description; tool limits stay explicit. |

Read rounds one and two; do not carry an unexecuted check forward as a new pass. Verify CSP and WebKit request blocking in actual integration tests, and separately disclose whether OS networking was disabled.

## Independent checks and build

After final-candidate handoff, independently run:

```sh
./scripts/verify.sh Release
./scripts/build.sh Release
```

The verifier installs locked web dependencies, runs web tests and the production dependency audit, builds assets, runs Foundation tests and actual WKWebView integration tests. Coverage includes Unicode, all math delimiters, diagrams, invalid/hostile content, relative navigation, replacement/rapid saves, obsolete-result cancellation, local images, scroll restoration, 1MiB/5MiB documents, source immutability, twenty 100KiB transitions, appearances/zoom, blocked external fetch and refresh latency.

Read source and generated-asset diffs after building and report any departure from the starting candidate. Keep build success, automated checks and actual UI observations separate. Public signing, notarization and distribution are outside this original review round.

## Source-review concerns to exercise

Review found that `reload(preserve:)` advanced the displayed revision even for identical-content reads or read failures. Link messages from the unchanged page could then be rejected. This was reported as a source concern, not an observed runtime failure, and added to unchanged-save, sibling-file and recovery coverage.

Also check whether completion of an asynchronous diagram overwrites a user's intervening scroll. The implementer reported both concerns fixed; verify them on the final candidate. Accessibility requires actual input/navigation observations beyond named controls and an AX tree. Since round two could not activate VoiceOver with ⌘F5, the reviewer may use the VoiceOver app, Utility or Settings to establish activation, try navigation and restore the initial state.
