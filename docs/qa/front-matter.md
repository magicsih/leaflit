# Front-matter rendering correction

Product source: `94024071ba17d30a81cba33d8fc6b7479ed79b05`. Local verification completed on 2026-10-30 using Apple Silicon and macOS 26.6.2. Scope is the [L1 development correction](../design/front-matter/design.md), not a distributable release candidate.

Before the fix, three new renderer tests failed: a complete metadata block appeared as a combined heading, BOM/line-ending cases leaked metadata into the body, and metadata activated optional Markdown renderers. The existing Markdown preservation case passed. After the correction:

| Check | Observed result |
| --- | --- |
| `scripts/verify.sh Release` | Passed on the exact product commit: 18 renderer tests, 16 Swift package tests, 7 packaging tests and 80 Xcode tests. Dependency audit reported zero vulnerabilities. |
| Front-matter parsing | Complete leading blocks with `---` or `...` closure are omitted from Read and Outline. BOM and LF/CRLF/CR retain original body line numbers. Empty and metadata-only blocks do not invent a title. |
| Ordinary Markdown | Unclosed metadata, body separators, Setext headings, quoted/list content and fenced YAML examples remain visible. |
| Native Source integration | The new WKWebView test passed: body heading, original error-to-source location, unchanged bytes during mode switching/draft preview, and exact BOM/CRLF metadata retention after explicit Save. |
| Actual app screen | Launched the test-built Release app from its exact build path and confirmed its PID/executable. The owned `Preview.md` fixture starts with `Project notes`; Outline contains only `Project notes` and `Next steps`. |
| Narrow screen and Source | At a captured 622 by 582 pixel window, Read and Outline remain readable. Source displays the original metadata. Returning to Read restores the body. Fixture SHA-256 is unchanged. |

The Source click produced one transient CUA `AXError.failure`; the next full accessibility/screenshot observation confirmed that the switch had succeeded. This tool error is not counted as a failed app flow. The sidebar was returned to its initial Files mode, and the task-owned app was quit. The installed app was not replaced. Signing, notarization, app publication, downloaded-artifact checks and independent L3 release verification were not performed.

Raw logs, screenshots, accessibility observations, the owned fixture, verification JSON and Xcode results were stream-copied to NAS1dual and directly read back to compare every file's size and SHA-256:

`/Volumes/Data/Backup/agent-artifacts/leaflit/2026-10-30/94024071ba17d30a81cba33d8fc6b7479ed79b05/front-matter-1616`

The 205 files total 1,290,673 bytes. `MANIFEST.json` SHA-256: `8af21e2487a02bb728bfeb9a9de605aa59de1a3ea1fe07e52bdce00779773bb6`. No automatic NAS expiry is authorized. Task-local evidence and regenerable build/dependency outputs are removed after this verified copy; maintained source and this summary remain in Git.
