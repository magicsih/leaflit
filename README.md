# Leaflit

A read-only Markdown viewer for macOS, with offline Mermaid diagrams and LaTeX math. Open a file, read it in a native window, and see saved changes appear automatically.

Built with Swift, AppKit and WKWebView for Apple Silicon. The deployment target is macOS 14 or later; runtime verification so far covers Apple M3 on macOS 26.6.2. Earlier macOS releases and Intel Macs have not been verified.

## Install

Download the [0.1.0 preview](https://github.com/magicsih/leaflit/releases/tag/v0.1.0), extract the ZIP and move Leaflit.app to Applications. The public app is signed and notarized. Homebrew installs the app and launcher together:

```sh
brew install --cask magicsih/tap/leaflit
leaflit "path/to/document.md"
```

The launcher does not change Finder's default application. The [public distribution checks](docs/releases/0.1.0-verification.md) cover the downloaded app and Homebrew installation. See the [release procedure](docs/releasing.md) for signing, publication and artifact verification.

## Read

- Open `.md`, `.markdown` and `.mdown` files from Finder, the Open menu, drag and drop, or the `leaflit` launcher.
- Read tables, strikethrough, disabled task lists, code blocks, local PNG/JPEG images, Mermaid diagrams and KaTeX math.
- Search, copy, zoom, follow heading anchors and navigate between relative Markdown links with Back.
- Use separate windows for separate files. Opening the same file again activates its existing window.
- Follow saved changes, including atomic file replacement, while preserving the current reading position.
- Use the system light or dark appearance. No account, server or analytics service is required.

Math delimiters are `$…$`, `$$…$$`, `\(…\)` and `\[…\]`. Diagram and formula errors preserve the original source with a short message. Long code blocks and tables scroll horizontally.

Raw HTML is shown as text. Remote resources, document scripts, unsafe URL schemes and Mermaid configuration directives are blocked. External web links open in the default browser only after a user click. The app never edits its source documents.

| Action | Shortcut |
| --- | --- |
| Open | ⌘O |
| Find | ⌘F |
| Next / previous match | ⌘G / ⇧⌘G |
| Back | ⌘[ |
| Copy selection | ⌘C |
| Zoom in / out / reset | ⌘+ / ⌘− / ⌘0 |

## Build locally

Verified with Xcode 27, Node.js 24 and npm 11. Dependencies are pinned in `package-lock.json`. Ruby is needed only when regenerating the Xcode project, not for a normal build.

```sh
./scripts/build.sh
open build/Leaflit-0.1.0/Leaflit.app
./build/Leaflit-0.1.0/leaflit Fixtures/Welcome.md
open -a "$PWD/build/Leaflit-0.1.0/Leaflit.app" "Fixtures/Next Page.markdown"
```

For Xcode, build the web assets first, then run the Leaflit scheme:

```sh
npm ci --ignore-scripts
npm run build
open Leaflit.xcodeproj
```

The local candidate folder contains the app and launcher. Keep them together when moving the folder. Local builds use ad-hoc signing. They are distinct from a Developer ID signed and notarized public release. Building locally does not change PATH or Finder's default application.

## Verify

```sh
./scripts/verify.sh
# Run performance measurements separately from other app reviews.
python3 scripts/benchmark.py
python3 scripts/measure-resources.py
python3 scripts/measure-memory-cases.py
# Run only the platform-independent document module or web parser tests.
swift test
npm test
```

See the [implementation design](docs/design/0.1.0/design.md), [test plan](docs/design/0.1.0/test-plan.json), [QA report](docs/qa/report.md) and [memory measurements](docs/qa/memory-analysis.md). Measurements include the app and WebKit helpers. On the measured candidate, median footprint was 69.7MiB for a 1KiB document and 85.6–131.1MiB across the measured 100KiB document structures. Some runs used more memory; the reports preserve the full ranges. The initial 60MiB comparison target was not met.

Editing, a table of contents, printing, PDF export, syntax highlighting, Obsidian-specific syntax and automatic updates are outside version 0.1.0. Spoken VoiceOver navigation and earlier macOS runtime coverage remain incomplete. Follow-up work is tracked in [GitHub issues](https://github.com/magicsih/leaflit/issues).

Regenerate the project only when its structure changes, using `ruby scripts/generate-project.rb` with xcodeproj 1.27.0. The generated Xcode project and scheme are checked in.

## License

MIT. Bundled renderer dependency licenses are included in `THIRD-PARTY-NOTICES.txt` inside the app.
