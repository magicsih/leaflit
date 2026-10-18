# Independent UI review, round 2

## Plan and environment

An independent reviewer executed the approved second L3 UI round from the design and test plan, on candidate `737bacf46c7c594de8505c12a0bb49297ebf4358`. App: `build/Leaflit-0.1.0/Leaflit.app`, Release. Environment: Apple M3, arm64, macOS 26.6.2 build 25G83. This does not verify earlier macOS versions.

Fixtures: Welcome.md, Next Page.markdown and Errors.mdown. Additional isolated data: `/tmp/leaflit-ui-round2/Wide Reading.md`, containing a ten-column table, a long code line, Korean and emoji. No user document was opened. Scope: round-one corrections, approximately 640pt width, 200% zoom, horizontal code/table scrolling, errors, escaped HTML, keyboard input and VoiceOver where possible. Expected behavior was defined before execution: visible diagram labels, working Back, copy/paste, readable zoomed content, preserved error source and accessible navigation.

Evidence came from native screenshots and accessibility trees through `cua_repl`, not source inspection. No separate PNGs were saved. Date: 2026-10-18 KST; final timestamp: `2026-10-18T12:50:14Z`. Executable modification time remained `2026-10-18T21:43:45+0900` throughout. The implementer edited source during review but did not replace this app. Only system dark appearance was exercised.

## Actions and observations

| Item | Actual observation | Result |
| --- | --- | --- |
| Mermaid labels | Opened Welcome through the Open panel and scrolled to the diagram. All three node labels appeared inside boxes. | Recovered, passed |
| View > Back | Followed `next page`, clicked enabled Back. The menu closed; the document and title stayed on Next Page. | Failure reproduced |
| Copy and paste | Triple-clicked the copy sentence, then ⌘C, ⌘F, ⌘V. The sentence appeared in search. Trailing whitespace caused `Not found`; this was not a successful exact search assertion. | Paste recovered, passed |
| Small window | Dragged the window to approximately 640pt; toolbar and wrapping text remained readable. | Passed |
| 200% zoom | Clicked Zoom In ten times from 100%, using the implemented 10% increments. Text doubled; headings, Korean and emoji remained readable. The app does not display a numeric zoom value. | Passed |
| Long code | At 640pt and 200%, dragged the horizontal scrollbar from `START-OF-LINE` to `END-OF-LINE`. A tool scroll call had produced no change. | Passed |
| Long table | Independently dragged the table scrollbar to `Column10` and `FINAL-CELL`; the document itself did not scroll horizontally. | Passed |
| Formula error | Errors.mdown showed `Formula could not be rendered` and `\definitelyUnknown{x}`. | Content passed; border defect |
| Diagram error | Invalid syntax and a configuration directive each retained source and an error. | Passed |
| Missing images | Missing local and remote images displayed alternative text and `image unavailable`. This observation alone did not verify network blocking. | Display passed |
| HTML and unsafe URL | The script tag appeared as text with no alert. The javascript link was exposed as Markdown text rather than a link. | Source display passed |
| Custom app link | Clicking returned `frontmostApplicationChanged`; Errors.mdown remained after reacquiring UI. No independent external-navigation observation was obtained. | Unverified |
| Keyboard | ⌘O, ⌘⇧G, path entry, Return, ⌘F, typing, ⌘C, ⌘V and ⌘Q worked. Searching `Diagram` selected a match; Return changed AX selected text to `diagram`. | Executed scope passed |

## Findings and accessibility limits

View > Back still failed and was reported without editing the review app. The formula error's left border appeared as disconnected fragments with empty bracket-like pieces below the source at 900pt and 100%. Diagram error boxes were rectangular.

Spoken VoiceOver navigation was **not executed**. Two ⌘F5 attempts, including after raising the app, did not establish activation. No VoiceOver app or process appeared. Delivery of the system shortcut through app-targeted input was uncertain, so this was not classified as a product failure. The reviewer had been asked not to operate other apps, and did not open Settings or VoiceOver Utility. No system setting was changed.

The diagram accessibility tree contained one `image Diagram` without child node text. Visible labels and a useful accessibility name are separate checks. Math exposed fragments of integral signs, numbers, exponents and formulas; natural spoken math was not verified. Full menu keyboard navigation, the Back shortcut, and VoiceOver link/table navigation remained unverified.

## Source preservation and completion

Before/after SHA-256 values matched:

| Document | SHA-256 |
| --- | --- |
| Fixtures/Welcome.md | `41eceab164f37bcc04639ca4d7cf41a91831b699849b54ca011632e640dc4201` |
| Fixtures/Next Page.markdown | `af959c36eabbe02c4deac10651fa62be5fcaadbed1bd1cf9cbea4e7c1e6df451` |
| Fixtures/Errors.mdown | `4ea2141055ccf8f518f87da78ad0c9878d9c705394dd3d7782d9a3e32a7fcf19` |
| /tmp/leaflit-ui-round2/Wide Reading.md | `9edca12ebb6da47c43450deb8c7f0508603fc8989d6b0efac02f8683a116e39a` |

The isolated wide document was retained for reproduction. After ⌘Q, Leaflit and VoiceOver process queries were empty. Finder defaults, PATH, appearance, networking, user documents and mobile devices were unchanged. No product source was edited; shared UI control was returned.

This round does not establish light-mode, OS-wide offline, file-watcher/recovery, Finder-drop, performance, macOS 14 or spoken VoiceOver coverage. Back and the formula border required a later candidate check.
