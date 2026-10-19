# Read first, edit when needed

The owner approved Read and Source modes on 2026-10-19 after discussing quick corrections to Markdown produced by terminal LLM workflows. This replaces the current-product read-only restriction with explicit editing. Historical release and QA claims remain unchanged. The endpoint is a verified local 0.3.0 candidate, not a public release or installed-app replacement.

## Screen and behavior

Use the existing native window, Files/Outline sidebar, system appearance and toolbar. Add one compact content header. Read is the default for each newly opened document. Source is a plain Markdown editor, not a rich-text Write mode.

```text
Existing window toolbar
┌─────────────────────────────────────────────────────┐
│ [ Read | Source ]       Unsaved changes       [Save] │
├────────────────┬────────────────────────────────────┤
│ Files/Outline  │ Read: rendered draft or saved text  │
│                │ Source: editable Markdown          │
│                │                                    │
└────────────────┴────────────────────────────────────┘

External change while editing:
File changed on disk. Your edits are still here.
[Reload from Disk…] [Save a Copy…]

Unsaved close, navigation or quit:
Save changes to “document.md”?
[Save] [Cancel] [Discard Changes]
```

- Opening, reading, rendering, refreshing, copying and mode changes never write a document. No autosave, automatic formatting or rich-text conversion.
- Instantiate the plain NSTextView only when Source is first requested. Keep drafts and undo in memory. Keep original UTF-8 BOM, existing line endings and Unicode without normalization. Provide native selection, copy/paste, undo/redo, Find and zoom.
- Read previews the in-memory draft and clearly labels unsaved changes. Saving works in either mode with Command-S. A new document resets to Read. The sidebar remains navigation, not a second editing-mode selector.
- Formula/diagram errors retain raw source and a short error. Add Edit Source to reach the relevant original block; never derive editable Markdown from rendered HTML. A parser failure must retain readable raw text and an editing route.
- File changes with a clean draft refresh normally. A dirty draft is never replaced by a watcher event. Changed/deleted/replaced/unreadable originals block normal Save and offer reload after explicit discard, or Save a Copy to a new path. Never offer a silent overwrite action.
- Close, relative links, Files navigation, Back and app quit protect unsaved drafts with Save, Cancel or Discard. A failed save cancels the pending destructive action and keeps the draft.

## Ownership and saving

Keep draft state and UTF-8 encoding in LeaflitCore, with no AppKit or WebKit dependency. The native file adapter reads a regular file through a validated descriptor, retains its identity and original bytes, and coordinates replacement using NSFileCoordinator. Re-read and compare identity and bytes inside the coordinated write, stage a sibling temporary file, preserve destination metadata, then replace atomically. Do not recreate a missing original, follow a newly introduced symlink or escalate permissions. Save a Copy uses exclusive new-file creation and does not resolve the original draft's conflict.

Coordination protects cooperating writers. A comparison followed by replacement cannot provide a filesystem-wide compare-and-swap guarantee against an unrelated uncoordinated writer racing inside that interval. Record this limitation; test observed prior external changes and the pre-commit validation path rather than claiming an absolute cross-process guarantee.

The reader owns the draft, editor and pending save. Saving temporarily disables edits to freeze the submitted text. Watcher events are reconciled after completion. No server, editor web framework, new runtime dependency or storage migration is needed. Existing security boundaries for raw HTML, URLs, images, math and Mermaid remain in force for draft previews.

## Acceptance and verification

Follow [the test plan](test-plan.json). Write failing core tests before implementation, then independent native integration and full Release regression. Three independent actual UI rounds cover the new screen and data-loss routes. Only reviewer-owned fixtures may be modified; preserve installed/user apps, unrelated documents, preferences and all earlier candidate/evidence folders. Use new 0.3.0 build paths.

Check normal save, no-op save, Unicode, spaces, BOM/CRLF, undo across save, external atomic replacement, deletion, read-only files, symlinks and save failures. Check dirty navigation/close/quit, source Find and keyboard focus, error-to-source repair, small windows, 200% zoom and native appearances. Run 1MiB/5MiB cases and three paired fresh-process 100KiB Read/Source memory samples with identical observer conditions and strict helper attribution. Do not infer memory improvements from on-demand allocation alone.

Older macOS, spoken VoiceOver, cross-app Finder drop and true offline isolation retain their existing issue boundaries unless actually executed. Public 0.2.0, Homebrew and the website remain unchanged. Update current README and repository instructions to the approved explicit-save contract; preserve historical read-only reports.

## Official references

- [NSTextView](https://developer.apple.com/documentation/appkit/nstextview)
- [Coordinated writing](https://developer.apple.com/documentation/foundation/nsfilecoordinator/coordinate(writingitemat:options:error:byaccessor:))
- [Alerts](https://developer.apple.com/design/human-interface-guidelines/alerts)

The existing reader is retained. Source editing adds a draft model and native adapter instead of replacing the app with a document framework or a rich-text editor. Write mode is deferred.
