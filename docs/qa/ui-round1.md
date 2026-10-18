# Independent UI review, round 1

## Plan and environment

An independent reviewer executed the approved L3 scope in `docs/design/0.1.0/design.md` and `test-plan.json` on candidate `c133ef54963e1a907370e7e7b428000189391003`. Date: 2026-10-18 KST; observation timestamp: `2026-10-18T12:39:31Z`. Environment: Apple M3, macOS 26.6.2 build 25G83, system dark appearance. App: `build/DerivedData/Build/Products/Debug/Leaflit.app`; executable modification time: `2026-10-18T21:35:50+0900`.

Only `Fixtures/Welcome.md` and `Fixtures/Next Page.markdown` were opened. User documents, Finder defaults and PATH were unchanged. Scope: empty state, Open, Markdown, Mermaid, math, search, relative navigation, Back, selection, copy and keyboard input. Expected: readable content, match navigation, in-window relative navigation with return, and copying selected text.

Evidence came from actual application screenshots and the accessibility tree through `cua_repl`. No item was marked passed from source inspection. Screenshots remain in execution records, not separate PNG files.

## Actions and observations

| Item | Actual observation | Result |
| --- | --- | --- |
| Empty state | Launched the exact app path. Document icon, `Open a Markdown file`, drop guidance and `Open Markdown File…` appeared. Back was disabled. | Passed |
| File Open | Used File > Open and Go to Folder to open Welcome.md. The title and document appeared. | Passed |
| Body | Headings, paragraphs, quote, code, table, Korean and emoji were readable at 900pt. Task items were disabled checkboxes in accessibility. | Passed |
| Mermaid | Scrolled to `From idea to page`. Three boxes and two arrows appeared, but node labels were blank. Source contained `Open a file`, `Read the page`, `Follow a link`; accessibility exposed only `image Diagram`. | Failed |
| Math | Table E=mc², inline Pythagorean, integral and Euler formulas were visibly typeset. | Display passed |
| Heading anchor | `Back to the beginning` returned to the first heading; accessibility scroll value changed from 1 to about 0.015. | Passed |
| Relative link | `next page` opened Next Page.markdown in the same window, with both repeated headings. | Passed |
| Toolbar Back | Returned to Welcome and restored approximately 0.015 scroll position. | Passed |
| View > Back | Twice, an enabled menu item closed the menu without leaving Next Page. Toolbar Back worked immediately afterward. | Failed |
| Find shortcut | ⌘F exposed Find in Document and Previous, Next, Done. | Passed |
| Match navigation | Typing `next` selected a heading match. Next selected `The next step`; Previous returned. Typing `room` also selected its match. | Passed |
| Closing search | Done hid the find row. Escape cleared the query but left the row visible. Escape-to-close was not an acceptance criterion in this round. | Observation |
| Selection | Triple-click produced a visible selection and AX selected text `Copy this sentence: Leaflit keeps the original file intact.` Selection in Welcome also worked. | Passed |
| Copy and paste | After ⌘C, ⌘F, ⌘V, the find field stayed empty. Edit > Copy was enabled, but retrying it did not populate search. Edit lacked Paste. Clipboard contents were not independently read. | Paste failed; copy unverified |
| Back shortcut | `super+bracketleft` made no visible change; `super+[` was rejected by the tool as `keyNotFound`. | Unverified; tool limitation |

## Limitations and completion

This round covered the Debug app only. Release execution, OS-wide offline operation, light appearance, a small window, 200% zoom, spoken VoiceOver, reload/recovery, Finder drop and performance were not executed. Visible math is not evidence of network blocking.

`git diff -- Fixtures` was empty after reading. No before-reading hashes were collected, so this is not a hash-comparison pass. Mermaid labels, View > Back and search paste were reported for correction; copy needed further verification. No product code was edited.

Returned to Welcome using toolbar Back and quit with ⌘Q. No Leaflit process or other reviewer-started test process remained. Shared UI control was returned.
