# Icon, README and GitHub Pages verification

## Scope and identity

Executed on 2026-10-19 on Apple M3/macOS 26.6.2. The owner selected A / Leaf Page after comparing three editable SVG concepts. The [decision and test scope](../design/app-icon/design.md) cover the icon resource and public introduction. No reader implementation or web-renderer source changed. The earlier [sidebar report](sidebar-report.md) remains historical evidence for its identified artifact, including failed review rounds and unverified conditions; it is not a new memory measurement of the icon-updated app.

- Editable master: `assets/branding/leaflit.svg`.
- Initial selected ICNS SHA-256, before the alignment correction below: `cd3bedb71f743827cbcfef2f0c8c7bbd57204f6b6ad307e996c09d1c81784fb3`.
- Initial 1024px PNG SHA-256, before the alignment correction: `071a671f1ee84aed438492e90e93c83c6af8ab9d25c04360d09147b1222188b6`.
- Public screenshot: `site/assets/leaflit-0.1.0.jpg`, SHA-256 `261153494de6aa2e0d2d9e1541ad0f39ff3b6553cdfbccc8e5a33ddb12ace8bb`.
- Sidebar screenshot: byte-identical to the preserved actual 0.2.0 round 3 Files capture, explicitly labeled as a local candidate.

Normal builds use the committed ICNS; no browser is needed to build the app. The PNG/ICNS export procedure is in the [branding README](../../assets/branding/README.md).

## Executed asset and native observations

The icon decoded into ten standard macOS slots, covering 16/32/128/256/512-point 1× and 2× sizes. The declared `CFBundleIconFile` and packaged resource bytes matched in a successful ordinary preparation build. Actual Finder Get Info for that exact app showed the selected page-and-leaf artwork at its small header and large Preview sizes, with version 0.2.0 and Apple Silicon app identity. The app was launched with a reviewer-owned Markdown file and showed its actual reader. Only that app and the newly owned Finder/Info windows were closed afterward.

That preparation build preceded the final software-rendered export. Initial GPU-based exports produced a different raster in an equivalent size slot between runs. The exporter now uses software rendering, waits for two frames, renders each physical size once and reuses it for equivalent slots. Two fresh export processes then produced the identical final PNG/ICNS hashes above. Earlier files and pixel-comparison diagnostics are retained under `build/website-qa/`; they are not relabeled final-candidate evidence. The final normal build must use the final ICNS and its native Finder presentation must be read back separately in the local handoff record.

No Dock or application-switcher inspection is claimed. Existing apps with the same bundle identifier remained open; their icons must not be assumed to represent the new exact-path candidate. Earlier macOS icon presentation, Developer ID signing, notarization and installed/downloaded new-icon distribution remain unverified and separate from this local work.

## Actual public app screenshot

An isolated copy of the installed public 0.1.0 app rendered the reviewer-owned `plan.md`, including Mermaid, a table, math and disabled task items. Its executable SHA-256 matched `20f04c5661b030955ee4e22b041062fbf9ffa244c82ecd16a1efcbf59e45a933`. The saved native screenshot is unedited. The file hash was unchanged and the capture app exited. Raw fixture and capture metadata are in `build/website-capture-20261019/`. The tool returned `procNotFound` when asked for state after Command-Q; independent process readback confirmed the intended exit, rather than an app-open failure.

The selected new brand icon appears in the README and site; their text explicitly says that the public 0.1.0 binary still has its original icon. The separate sidebar screen is labeled local 0.2.0 and predates the icon update.

## Local website checks

An isolated headless Edge browser rendered the staged site at 1440×1000, 768×1024, 390×844 and 320×760. At every width the actual images decoded, there was no document-level horizontal overflow, no page-script error and no HTTP asset error. The local 0.2.0 image is lazy-loaded: it was scrolled into view and decoded before the full-page capture, rather than counting an offscreen unloaded image as a broken URL.

Actual button clicks copied the exact Homebrew command. An injected clipboard-denial condition produced readable fallback feedback. The user's clipboard was restored. Keyboard Tab reached the visible skip link, Enter moved to main, and Get Leaflit navigated to the install section. The resource-notes disclosure opened. Canonical URL, structured app version 0.1.0, fixed public-download link and section anchors were checked. Screenshots and structured results are in `build/website-qa/local-*.png` and `local-result.json`.

Initial harness attempts did not complete: the bundled Playwright Chromium executable was absent, then a context-page argument and an assignment evaluation were corrected. The completed run used installed Edge without installing a browser. These are tool/setup failures, not claimed site passes or observed product defects. The successful run is recorded separately.

The site stages only public HTML, CSS, JavaScript, image assets, sitemap and robots, plus the canonical brand SVG. It excludes the maintainer README and internal design/QA folders. The 1200×630 share card combines the real public-app screen with website text and artwork; it does not fabricate app UI. Website assets use system fonts and no analytics integration.

## Owner-reported horizontal alignment

After the first site/icon implementation the owner observed that the app artwork looked left of center. The SVG confirmed that the document's horizontal bounds were 234–712, centered at x=473, while the tile was centered at x=512. Earlier Finder observations established that the selected icon displayed; they did not establish correct optical alignment.

The document and leaf now move together 39 units to the right. The new document bounds are 273–751 with center x=512, leaving equal 193-unit gaps inside the 80–944 tile. The chosen shapes, colors and background remain the same. An actual browser-rendered before/after comparison at large and 64/32/16px sizes is retained in `build/icon-centering/comparison.png`; it is artwork-preview evidence, not a new app UI review.

The SVG, PNG, ICNS and site share card were regenerated together. Corrected ICNS SHA-256 is `a79b15e973b8086f1c5c617a2c0064c345674fb707e165b25ee2b43a289f8804`; corrected 1024px PNG is `020db40eb3516b21a5ec0a8c9abe3cd709df2066529eb83d52ddd169bbee8c60`. Share-card HTML and its preparation script are now maintained with the artwork, so later mark changes can regenerate the presentation without a retained local server or hidden source.

The corrected candidate requires its own independent full verification, ordinary Release build and exact packaged Finder icon readback under `build/icon-centering/`. The earlier results below remain historical; do not relabel their uncentered icon or app hashes as verification of the corrected resource. Reader source and renderer logic are unchanged. No fourth sidebar review or new public app release is part of this correction.

## Initial checks and publication records

Independent verification and a separate ordinary Release build passed at merged source `55592d64eef7f1c96f0caeee351e195e8b75a1c2`, both exit 0. JavaScript 8, standalone core 8, packaging 7 and Xcode 34 passed, with zero failures and no reported production dependency vulnerabilities. The Xcode total contains 26 Reader tests and the same 8 core tests; do not count the repeated core tests as unique additional coverage. Complete logs, actual xcresult and artifact manifest are retained under ignored `build/branding-site-verification/`.

The normal app executable SHA-256 was `e4d8ae7e0a8106680657cfb1740b009dc829125462c5ec3a7b99168c8b1cc230`. Its icon matched the final committed ICNS above. The parent then inspected a fresh exact copy through actual Finder Get Info: the small header and large Preview showed the selected artwork, with version 0.2.0 and Apple Silicon identity. All 188 content-entry hashes of the observed copy matched the normal app. No app was launched for that Finder readback. The owned window was closed and the final Finder state was Desktop. Raw evidence and `root-native-readback.json` remain under `build/branding-site-verification/`.

The independent executor preserved the installed public binary, all 605 public artifact file hashes, five repository fixtures, the historical sidebar app/records, old DerivedData, original process paths/start tokens and Files/visible/180 preferences. No extra sidebar rendered-review round, installation or public app action occurred.

Later documentation-only commits remain distinct from that actual product execution. The final handoff must record the current Git SHA, verification/build outcomes and complete app-content equivalence to the observed normal app, rather than silently relabeling the historical candidate. Keep its exact final record under `build/branding-site-verification/` and link the completed handoff from the PR and issues.

The owner authorized public GitHub Pages in this request. The first [Publish website run](https://github.com/magicsih/leaflit/actions/runs/39182931807) completed successfully at `55592d64`, publishing <https://magicsih.github.io/leaflit/>. The live root and all eight linked CSS/JavaScript/image/robots/sitemap assets returned HTTP 200 and exactly matched staged bytes. The repository homepage, description and topics were read back. Later website edits require their own exact deployment and live-browser readback on [issue #14](https://github.com/magicsih/leaflit/issues/14).

Local previews are not publication. Metadata and sitemap do not establish search indexing or increased traffic; that follow-up is [issue #16](https://github.com/magicsih/leaflit/issues/16). New app signing, notarization, GitHub Release, Homebrew publication and downloaded-artifact verification remain separate states; this task does not publish a new app release.

Existing user PIDs 95552, 96665 and 77888, their paths/start tokens, the installed public binary, Markdown fixture and sidebar preferences were preserved during documentation capture. Runtime handback and final preservation must also be recorded by the final executor.
