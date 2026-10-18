# Files and Outline: independent UI review round 1 plan

Prepared on 2026-10-19 KST against the owner-approved [design](../design/navigation-sidebar/design.md) and [L3 test plan](../design/navigation-sidebar/test-plan.json). This plan covers Files, Outline, same-window navigation and Back. It does not count as a rendered review round.

## Status and execution boundary

Source review only. The implementation snapshot is `f1f097c3e46e5d17f2093eff9d58e855f5204b5d` on `design/files-outline-sidebar`. The working tree was clean when the snapshot was recorded. Remote default `main` resolved to `4feb81ea590aa97bbd9287f89dc9da77284e2369` through a read-only `git ls-remote` query.

No tests, builds, apps or UI actions were started for this sidebar review. Another reviewer owns the shared execution environment. Wait for the implementer's explicit UI handoff, final candidate SHA and app path after independent automation completes. If the source changes, record the new SHA and hashes before executing; the snapshot below is not evidence for a later candidate.

The UI executor must be independent of the implementation author. Use the actual Leaflit macOS app and `cua_repl` screenshots, accessibility state and native input. Source reasoning, direct test calls and a conceptual layout preview do not constitute rendered UI passes. Do not publish, sign, notarize, update Homebrew, change Finder defaults or PATH, or access mobile devices.

## Environment and source identity

Read-only environment query: Apple M3, macOS 26.6.2, build 25G83. Record the actual Xcode version, app configuration, bundle version, executable SHA-256, screen size and current appearance at handoff. macOS 14 is the deployment target, not a tested runtime.

Current scripts use `build/DerivedData-0.2.0` and `build/Leaflit-0.2.0`; use the exact path supplied by the implementer. Preserve the baseline 0.1.0 artifacts and baseline measurements. No path in this plan is permission to overwrite those artifacts.

SHA-256 snapshot:

| Source | SHA-256 |
| --- | --- |
| `Sources/Leaflit/NavigationSidebarController.swift` | `e9dd5c49ea34c6c070865457cbc7fb43068a9d8e031268eb982592219caf4b38` |
| `Sources/LeaflitCore/Navigation.swift` | `1603b9548ec44a7bad31d2cbd42c7f7e6ac621e59892a3588f5695ce92140afa` |
| `Sources/Leaflit/ReaderController.swift` | `b978acf058436064bcedddd97e2e3e865881fbc722d6dc699da93f69bfdf6c18` |
| `Sources/Leaflit/AppDelegate.swift` | `9caba1a8ec097214fc91530264a4ac99c9433802bfff1483efef2359c00dfc8c` |
| `Web/src/markdown.js` | `4f4c0326a1aa3bf9048e1cc70d85ad357d4439b50f5f45feeba696468796f1b5` |
| `Web/src/renderer.js` | `022ceb452e93b60f4be17a5af307263eac9cdd098376af30703242014a3dbd12` |
| `Tests/LeaflitCoreTests/NavigationTests.swift` | `5552ad94eacce5270653e0c77c57c377fbfc7131934eaeb24c0731cc0cd6fd6d` |
| `Tests/LeaflitTests/NavigationReaderTests.swift` | `3aeba2a7a97747f7f95b00799abc90f64c29f50310c6483b04329495863dce92` |
| `scripts/build.sh` | `92010c1639d92f0dc96ecd486d6465184e4663c51e42e5894d03bb34984a6eed` |
| `scripts/leaflit` | `b61fefc8abfd9920c8802d66ac26b29eb5ba77165924e83314ce5cd39996ae58` |
| `scripts/package-release.py` | `77667e9678fd7a5a66d8aa3e71ae0fa1045b7af1f1d750dbae6dc50a361ce4d4` |

## Isolated data and evidence

After handoff, create reviewer-owned data under `build/qa/sidebar-round1-<candidate>/`. Do not mutate repository Fixtures or user documents. Save a manifest and initial hashes before reading. Keep screenshots, raw accessibility snapshots, operation logs and before/after hashes under that ignored directory. The maintained English report must identify each evidence file, actual action and outcome.

Planned tree:

```text
Root Space/
  Guides/
    Reading.md
    Nested/
      Deep.markdown
  Notes Space/
    Unicode 😀.markdown
  Empty/
  A.md
  B.mdown
  No Headings.md
  .hidden.md
  unsupported.txt
  image.png
  link-inside.md -> A.md
  link-outside.md -> ../Outside.md
Outside.md
```

`A.md` contains a long body with nested and skipped heading levels, duplicate English and Unicode headings, bold/link/code text in labels, math, a Mermaid diagram, local images and a relative link to `Outside.md`. Include enough content below the final heading to permit an unambiguous anchor-position check. `B.mdown` is a visibly different document with a link back. `Reading.md` provides another nested navigation target. Symlink destinations are reviewer-owned. Use a separate empty root for the empty-folder state.

Only this data may be changed for additions, removals, atomic replacement and permission failures. Record mutation timestamps. Restore any temporary permissions before cleanup. Hash unchanged fixture files after reading; compare intentionally changed files with their expected final bytes rather than claiming that all files were immutable.

## Actual-app sequence and expected results

| Area | Actual action to perform | Expected result and evidence |
| --- | --- | --- |
| Empty navigation | Launch the handed-off app without a document. Switch Files and Outline, cancel Open Folder, then choose the isolated root explicitly. | No automatic parent/root restoration. Files offers Open Folder before choice; Outline explains that no document is open. The top mode control remains visible. Cancellation changes no root. |
| Tree contents | Read root entries and expand Guides and Nested. | Only visible directories and `.md`, `.markdown`, `.mdown` regular files appear. Directories precede files with localized filename ordering. Hidden, unsupported and both symlink entries are excluded. Expansion reveals the correct nested list. |
| Same-window selection | Open A, scroll to a recognizable paragraph, enter a Find term, select B from Files and use toolbar Back and View Back. | File selection replaces this window's document. Back restores A and the visible reading block. The root stays the same. Record document title, selected file and screenshot before and after each navigation. |
| Switching modes | With A partially scrolled and Find visible, select Outline, collapse a heading group, scroll its list, then switch Files and return. Repeat after scrolling Files. | Body, search text, selected document and reading position remain unchanged. Each mode retains its own list position, expansion and relevant selection. No second document window appears. |
| Rendered heading identity | Click nested, skipped-level, duplicate and Unicode outline rows. Compare heading labels with the rendered body. | Correct headings are targeted using the renderer's actual IDs. Inline markup is represented as readable plain text. Collapsible outline hierarchy follows heading levels, including skipped levels. |
| Scroll tracking | Scroll through several body sections, then collapse an outline ancestor while reading its child section. Hide the sidebar, scroll, and show it again. | Selection follows the visible body section, uses a visible ancestor when a child is collapsed, and does not repeatedly jump the sidebar list. Reopening Outline selects the current body section. |
| Outside-root relative link | Follow A's relative link to Outside.md, then Back. | Same window navigation is allowed, selected root remains unchanged, Files is unselected outside it and shows `Outside selected folder`. Back restores A and the prior reading position. No new directory tree is scanned. |
| Duplicate window | Open B separately, return to A's window and select B in Files. | The existing B window activates. A's window does not load B or gain a history entry; returning to it shows a file selection consistent with its actual document. |
| Loaded collapsed directory | Expand Guides once, collapse it, add a Markdown file inside it, then re-expand. Repeat with a removal. | Re-expansion shows the current directory, not its cached children. Existing unaffected expansion and the reading document remain stable. |
| Expanded refresh | Expand multiple nested directories, add and remove a sibling, and atomically replace the current document. | Affected entries and headings update. Unaffected expansion, selection and list position survive. No unintended file opens occur during reload or selection restoration. |
| Empty and unavailable | Choose the empty root; then return to the populated root, make one reviewer-owned expanded directory unreadable, and modify another readable expanded directory. Restore access and Retry. | Empty root shows `No Markdown files`. Failure remains visible with Retry until that directory recovers; an unrelated successful refresh does not clear it. Reader content is retained. |
| No headings and recovery | Select No Headings.md, then A. Remove A while displayed and recreate it with changed headings. | Outline explains the no-heading state. File loss retains previous content with recovery actions. Restored content and outline agree; obsolete rows and active-heading events do not reappear. |
| Basic reading regression | Search next/previous, select and copy text, adjust zoom, read the diagram, formulas and local image. | Existing reading features remain usable with the sidebar visible and hidden. Verify copied text through an actual paste path. Record visual output and source hashes. |

This round owns the sequence above. Small-window, 200%, appearance, extensive keyboard and actual VoiceOver coverage belong primarily to round 2. Final integrated regression, controlled stale-result checks and matched memory/latency measurements belong primarily to round 3. Any incidental observations in round 1 must be labeled with the actual action performed; do not transfer unexecuted checks as passes.

## Source-review concerns for implementation and controlled verification

These are source-derived scenarios, not observed UI outcomes:

1. At the recorded snapshot, `outlineViewItemWillExpand` refreshes Files only when `children == nil`. Collapsing removes that directory's watcher, and the remaining root watcher is not recursive. A loaded folder can therefore show stale cached children when re-expanded after a nested add or removal. Re-expansion refresh needs a regression test and the actual-app scenario above.
2. Any successful directory refresh hides the single Retry button and clears the shared status. An unavailable expanded directory A can lose its failure state when readable directory B refreshes. Keep recovery state until the affected directory succeeds, and exercise an unrelated B change while A is unavailable.
3. Files validates `FolderTree.canOpen` when the row is selected, before `ReaderController.navigate` obtains position through an asynchronous WebView call. `open` later resolves the path again. Replacing the selected file with an outside-root symlink while that callback is pending can display the outside target without another Files containment check. Controlled automation should mutate the isolated selected path during this gap and require rejection; intentional relative links outside root must continue to work. A timing-dependent attempt alone is not a successful race test.
4. When `canNavigate` activates an existing other window, the selecting window's Files row has already changed, but neither navigation nor selection restoration runs there. Returning to the original window can leave B highlighted while A is still displayed. The duplicate-window UI scenario must check both windows, not only activation.

Before reporting a defect fixed, record the updated implementation and an executed regression result separately. The new tests at this snapshot cover basic Files updates, heading identity, navigation, replacement saves, stale revision rejection and narrow-window visibility. They do not establish passes for the scenarios above.

## Completion record

Write the round's English outcome report only after actual execution. Include final candidate SHA and hashes, environment, exact app path, fixture manifest, actual inputs, selected screenshots and accessibility observations, successful and failed checks, tool limitations and omitted cases. Treat this plan's source review and another reviewer's automation as separate evidence. End by stating whether Leaflit and any reviewer-started processes remain running and returning exclusive UI control to the implementer.
