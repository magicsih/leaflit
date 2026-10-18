# Leaflit 0.1.0 implementation design

The owner-provided implementation plan dated 2026-10-18 authorized a read-only Markdown viewer for Apple Silicon and macOS 14 or later, through a verified local candidate. The initial scope excluded remote repository creation, push, public distribution and notarization. Feature commits were kept on local main. The owner's 2026-10-19 instruction extends the approved work through public GitHub and Homebrew distribution; see [public release preparation](public-release.md).

## Window and navigation

```text
┌────────────────────────────────────────────────────┐
│ ● ● ●  ←  Open       document.md        Find   − + │
├────────────────────────────────────────────────────┤
│              Heading                               │
│              Paragraph, links and math              │
│              ┌──────────────────────┐              │
│              │ code / table         │              │
│              └──────────────────────┘              │
└────────────────────────────────────────────────────┘
```

Use a 900×700 initial window, 16pt text, a 760pt maximum content width and system colors. The empty state emphasizes Open Markdown File. Keep only the document, search and error areas, with no sidebar. On refresh failure, retain the previous content, identify it as outdated, and offer Retry and Open. Toolbar and menu actions have keyboard equivalents and accessibility names.

Finder, Open, drop and the launcher share the same file-opening path. Canonical file URLs prevent duplicate windows. Relative Markdown links navigate within the same window, recording reading position for Back. External web links require a user click.

## Structure and security

LeaflitCore depends only on Foundation and handles URL classification, UTF-8 reads, revision numbers and allowed image references. The AppKit layer owns windows, menus, file watching, search and WKWebView. The web renderer bundles markdown-it, Mermaid 11, KaTeX and fonts. esbuild produces Safari 17 modules and lazy chunks. Building for macOS 14 does not establish runtime verification on that OS.

Pass document content through `WKWebView.callAsyncJavaScript` arguments, never by inserting it into executable source text. Reject obsolete asynchronous rendering results by revision. Watch both the file and its parent directory to handle replacement saves. Restore scrolling by the visible block's source line and offset within the viewport.

Escape raw HTML. Block remote resources with CSP and WebKit content rules. Serve only referenced local PNG/JPEG files after checking their formats. A separate URL scheme confines bundle resources. Use Mermaid strict mode with sanitized SVG and reject document configuration directives. KaTeX uses `trust=false`. Do not add a server, analytics, file writes or a full-disk-access request. The original local candidate uses ad-hoc signing and no App Sandbox; it follows existing OS file access permissions. Public distribution adds Developer ID signing and notarization without changing document access scope.

## Verification and recovery

The adjacent `test-plan.json` records the approved tests. Write document-module tests first. Verify presentation with actual WKWebView integration tests and three independent UI review rounds. Performance values are comparison targets, not assumed passes. Record the actual environment, executed scope, candidate SHA and remaining checks under `docs/qa`. Preserve the source document on failure. Local build and verification do not install PATH entries or change Finder defaults; Homebrew installation is a separate user-requested distribution step.

## References

- [markdown-it](https://github.com/markdown-it/markdown-it)
- [Math parser and mixed delimiters](https://mdit-plugins.github.io/tex.html)
- [Mermaid API](https://mermaid.js.org/config/usage.html)
- [Apple WKWebView](https://developer.apple.com/documentation/webkit/wkwebview)
