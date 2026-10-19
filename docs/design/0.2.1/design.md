# Product follow-ups for 0.2.1

The owner requested prioritized product fixes, performance improvements and additional verification on 2026-10-19. The endpoint is a verified **local** Release candidate. Publishing another version, changing the 0.2.0 preview designation and official Homebrew inclusion are separate work.

## Behavior and implementation

| Area | Existing evidence | Change and acceptance |
| --- | --- | --- |
| Sidebar width, #13 | Native pane width and divider position differ on this host | Store and restore the same visible width using native coordinate conversion. Repeated reopen, toggle and narrow-window cycles preserve a non-minimum width. No fixed OS inset. |
| Heading allocations, #1 | Unchanged headings rebuild the native tree on every body event | Retain the existing tree when complete heading metadata is unchanged. Changed headings still appear, with selection and collapsed groups preserved. |
| Rendering, #3 | Duplicate anchor suffixes repeatedly scan previously used suffixes | Keep identical unique anchor output while avoiding repeated suffix searches. Retain Unicode and mixed-name collision coverage. |
| Optional math | Overlapping revisions can see an existing stylesheet before it finishes loading | Wait for the same stylesheet readiness across revisions. Failed math retains source and an error. |
| Window lifetime, #2 | Helpers can persist after close; no confirmed ownership leak | Verify controller, window, WebView and sidebar lifetimes and another window's continued operation before changing teardown. Classify helper/cache behavior separately. |

These are bounded corrections to the existing design, not new screens or a sidebar redesign. The three original independent sidebar review rounds remain historical evidence. Broader asynchronous I/O coalescing and visited-folder cache eviction require separate evidence and remain follow-ups.

The targeted native check also exposed a width-persistence failure when a 620pt window, 200% zoom and the Find bar constrain the pane. Automatic layout compression must not replace the user's preferred width, including across an ordinary app restart. Add this actual reproduction to the width acceptance tests before accepting the candidate. Apple documents the distinction between user resizing and layout in [split-view resize notifications](https://developer.apple.com/documentation/appkit/nssplitview/didresizesubviewsnotification?changes=__3&language=objc).

## Verification

Use independent L3 regression on local macOS development and ordinary Release apps. First demonstrate the width failure, then verify the correction. Run `scripts/verify.sh Release` and `scripts/build.sh Release` at the final candidate commit. Preserve failed runs, exact source and binary identities and unchanged document hashes. Compare the preserved ordinary 0.2.0 app with the candidate using identical fixtures, warm OS caches and the same observer condition. Record body and optional-renderer completion separately, including animation-frame versus timer fallback provenance. Do not infer a whole-app memory saving from a parser microbenchmark.

Additional native checks target keyboard navigation, appearance and icon surfaces, offline execution and Finder opening routes. Existing tool or environment gaps stay unverified when they cannot be executed faithfully. Earlier macOS and spoken VoiceOver are not inferred from current-host accessibility labels. Android and iOS are outside scope.

The installed app, public 0.2.0 artifacts, existing processes, preferences and historical evidence are preserved. Live preflight found the installed app already updated to signed 0.2.0 and no Leaflit process running; this work did not update or close them. New outputs use 0.2.1 and ignored `build/product-followups/`. No document editing, migration, credentials, signing or network service is introduced.
