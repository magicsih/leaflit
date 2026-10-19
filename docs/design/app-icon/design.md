# Selected icon and public introduction

## Owner intent and decision

On 2026-10-19 the owner requested icon selection, a README with actual app screens and the problem being solved, and a public GitHub Pages introduction intended to help discovery. The owner described opening Markdown from LLM terminal work without loading an IDE merely to read it. After seeing three same-size vector candidates in light and dark surroundings at 64/32/16px, the owner explicitly selected **A / Leaf Page**.

The approved direction is a page and leaf, with an ivory/green palette and no lettering in the icon. Editable master: [`assets/branding/leaflit.svg`](../../../assets/branding/leaflit.svg). Conventional ICNS export preserves the existing macOS 14 build target; actual earlier-OS icon rendering remains unverified. [Apple app icon guidance](https://developer.apple.com/design/human-interface-guidelines/app-icons) and [asset configuration](https://developer.apple.com/documentation/xcode/configuring-your-app-icon) informed preparation.

## Scope

- Package the selected artwork in the local macOS app, leaving document reading behavior unchanged.
- Add actual 0.1.0 and explicitly labeled local 0.2.0 screenshots to the English README and site.
- Explain the creator's terminal-to-Markdown problem, a concrete opening command, existing reading behavior and installation.
- Publish a static, responsive, English website at `https://magicsih.github.io/leaflit/` and set the repository homepage. Include metadata, share image, canonical URL, robots and sitemap. These improve discoverability but do not prove search indexing or traffic growth.
- Site deployment is authorized by this request. A new app version, Developer ID signing, notarization, GitHub Release and Homebrew update remain separate work.
- Keep performance goals distinct from measured results. Previously measured sidebar artifacts must not be presented as measurements of the icon-updated app.

## Verification plan

This is an icon resource and public documentation change, with no new app screen, navigation or reading logic. Use L1 asset/documentation verification, plus the repository-required full `scripts/verify.sh Release` and a separate ordinary Release build. Coordinate an independent executor for the final local-candidate automated regression as required by the repository's existing L3 handoff. Inherit only actual passing unchanged reader behavior; retain its existing coverage gaps. Do not repeat the three sidebar UI rounds for this documentation/asset scope.

Check the SVG/PNG/ICNS dimensions and resource linkage, then inspect the selected artwork through the actual packaged local app's macOS presentation. Record the exact controls/surfaces observed and leave any unavailable Dock, Finder or app-switcher surface unverified. Preserve existing user apps, defaults, source documents and public 0.1.0 artifacts.

Render the site at desktop and narrow widths, check images/overflow, keyboard access, copy success and failure feedback, internal anchors, public-download/source links and metadata. Then read back the Pages workflow/deployment and actual HTTPS site, including asset responses. Do not mark local preview as public deployment or search indexing as established. Keep all raw evidence under ignored `build/` and publish a concise English QA report with exact observations.

## Publishing design

Buildless HTML, CSS and one small copy-button script live under `site/`. `prepare-site.py` stages only public site content and the canonical brand SVG into `build/site`; internal QA/design files are not part of the Pages artifact. A path-filtered GitHub-hosted workflow publishes only website changes on `main` or explicit dispatch. Official action versions were checked and pinned by commit SHA. It uses the standard `github-pages` environment, read-only contents and Pages/OIDC deployment permissions. There is no app release action, external font request or analytics integration.

The current public app remains 0.1.0 and has no sidebar/new icon. Main's local 0.2.0 has Files/Outline and the selected icon. Screens, links and captions preserve that distinction.
