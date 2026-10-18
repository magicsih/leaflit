# Files and Outline sidebar design

## Decision and approval status

On 2026-10-19 the owner selected both folder/file navigation and the current document outline, with tabs or a toggle at the top or bottom of the sidebar. Both modes are confirmed requirements. The layout and test plan below are proposed for approval before implementation. The application icon remains a separate design task in [issue #9](https://github.com/magicsih/leaflit/issues/9).

## Layout

Use one collapsible native sidebar with a two-choice control fixed at its **top**, labeled `Files` and `Outline`. The top position keeps navigation discoverable when the window's bottom edge is obscured. Use equally sized text segments, system selection colors and keyboard access. This follows Apple's [sidebar](https://developer.apple.com/design/human-interface-guidelines/sidebars) and [segmented control](https://developer.apple.com/design/human-interface-guidelines/segmented-controls) guidance.

```text
┌────────────────────────────────────────────────────────────┐
│ Sidebar  Back  Open         Getting Started.md    Find  − + │
├─────────────────────┬──────────────────────────────────────┤
│ [ Files | Outline ] │ Getting started                      │
│                     │                                      │
│ Leaflit Guide       │ Read your Markdown in a native       │
│ ▾ Guides            │ window.                              │
│   Reading.md        │                                      │
│   Keyboard.md       │ Read documents                       │
│ Getting Started.md  │ …                                    │
└─────────────────────┴──────────────────────────────────────┘
```

The control switches only the sidebar contents. Preserve the body, search state, selected document and reading position when switching modes. Retain each mode's list selection, expansion and scrolling separately. Keep the current renderer's single WKWebView; implement sidebar content with AppKit lists.

Start with a sidebar around 230pt wide, adjustable between approximately 180–320pt. Keep the 900×700 initial window unless runtime review establishes a better size. Preserve usable document reading at 480pt minimum window width: collapse the sidebar when both panes no longer fit, and retain an accessible toolbar toggle. Add a View menu toggle with the standard Control-Command-S shortcut. Remember the last chosen mode, visibility and width; keep an automatically collapsed narrow-window state separate from the user's saved preference.

## Files

- Start with `Open Folder…` when no folder has been selected. Use an explicit native folder chooser; do not automatically scan a document's parent directory or restore/index folders on startup.
- Keep the chosen root per window. Show folders and Markdown files, with directories first and localized filename sorting. Enumerate children only when their parent expands. Exclude hidden entries and symbolic links from the tree, and keep canonical paths within the selected root.
- Selecting a file navigates in the current window and records the previous document and reading position for Back. Preserve the current duplicate-window rule: if another window already shows the canonical file, activate that window instead of creating a duplicate.
- Keep the selected root stable during relative-link navigation. If a document lies outside it, leave the tree unselected and show a short `Outside selected folder` status; do not scan additional folders automatically.
- Observe the root and expanded directories for file changes; refresh only affected lists, keeping expansion and current selection when possible. Do not read other Markdown bodies to populate the tree.
- Define empty and failure states: `No Markdown files`, `Folder unavailable`, Retry and `Open Folder…`. A disappeared file keeps the existing reader's previous-content/error recovery behavior.

## Outline

- Display the current document's headings with indentation and collapsible groups. Reuse exactly the heading IDs assigned by the renderer, including duplicate titles and Unicode.
- Selecting a heading moves the existing body to that anchor. Scrolling the body updates the selected outline row without forcing the sidebar to jump on every frame.
- Obtain plain-text heading labels during the existing Markdown parse. Send typed heading data and active-heading changes with document revisions; discard stale events after file navigation or a refresh.
- Reconcile entries after saves and replacement saves. Preserve expanded groups by stable heading identity when possible. Show `No headings in this document` when appropriate.
- Pause unnecessary outline observation when hidden; avoid a second Markdown parse, another WebView or per-frame native messages.

## Verification and delivery

The adjacent [test plan](test-plan.json) proposes L3 complete regression on the macOS development and Release apps, with three independent rendered UI review rounds. Measure additional memory and latency with the sidebar hidden, Files active and Outline active on the same fixed documents. Compare against a fresh measurement of the baseline, rather than treating historical numbers as a guarantee.

The proposed endpoint is a verified local Release candidate for owner review. Publishing another GitHub release or updating Homebrew is not authorized by this design proposal. Preserve the existing 0.1.0 artifacts. Track implementation in [issue #10](https://github.com/magicsih/leaflit/issues/10).
