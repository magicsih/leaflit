# Public website

This directory is the public English introduction at <https://magicsih.github.io/leaflit/>. It explains the terminal-to-Markdown use case and links the public 0.3.1 release, including Read, explicit Source editing, Files, Outline and the Leaf Page icon.

## Local preview

```sh
python3 scripts/prepare-site.py
python3 -m http.server 8766 --bind 127.0.0.1 --directory build/site
```

The site needs no package installation or JavaScript build. The only runtime script is the install-command copy button, with a readable fallback. Fonts use the system. There are no analytics requests or tracking cookies.

## Publication

The `Publish website` GitHub Actions workflow runs for `site/`, the canonical brand SVG, the staging script or workflow changes on `main`; it can also be dispatched manually. It stages only this site's content, excluding this maintainer README, and the selected SVG into `build/site`. Pages settings must use the `workflow` build type. Ordinary app-only commits do not deploy the site.

The workflow uses pinned official checkout/configure/upload/deploy Pages actions and the `github-pages` environment. Source permissions are read-only; Pages write and OIDC permissions are limited to its publishing job. It never builds, signs or publishes a macOS app. See [GitHub's workflow documentation](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages).

After changes, check desktop/narrow rendering, all images, anchors, keyboard focus, copy success/failure, link destinations and metadata. Confirm the workflow's exact source commit and the live HTTPS result separately. The sitemap, description, canonical URL, structured app data and social image are discovery preparation; search indexing or traffic is not guaranteed or measured here.

## Actual screens and share image

- `assets/leaflit-0.3.0-read.jpg` and `assets/leaflit-0.3.0-source.jpg` are original unedited 900×784 native captures of the signed 0.3.0 distribution with reviewer-owned English notes. Both came from the exact final ZIP `1735b01cdd702be50c8f1275bccdf235e7d2fd25c1c1640456e92a990f22d418`, signed executable `3a679de7ea154f030fcf03fb7c7b6d936343850f250e30588b5d00c0aced12fb`. Read image SHA-256 is `c2f96e434a4c99551d1f44c78ceacb4a13dca3355724fa8c0f3e89fc4c9830b7`; Source is `60d291ef20d4633d782b49d52b55ada9497769c440e2549290a4b4641271aa5f`. Original images, AX and bounded distribution smoke remain ignored under `build/release-0.3.0/signed-smoke/`. See [public distribution verification](../docs/releases/0.3.0-verification.md).
- `assets/leaflit-0.2.0.jpg` is an unedited 900×784 native capture of the signed 0.2.0 distribution, showing Files and `plan.md`. It was extracted from the exact final ZIP with SHA-256 `2289bb755734ea82bc10e41def7c6f11675f835a60fc8244d8af007e4c50a812`; the signed executable was `16dfc0d18a0fa7a4e59fd1e128c77dc543f387408499e488aaec88ac4c2430ca`. Raw screenshot, AX and signed smoke results remain in ignored `build/release-0.2.0/signed-smoke/`.
- `assets/leaflit-0.1.0.jpg` is an unedited native capture of an isolated copy of the installed signed public 0.1.0 app, rendering a reviewer-owned `plan.md`. Its binary matched the published executable `20f04c5661b030955ee4e22b041062fbf9ffa244c82ecd16a1efcbf59e45a933`. Raw fixture/capture records are in ignored `build/website-capture-20261019/`. The capture copy was closed and its Markdown hash remained unchanged.
- `assets/sidebar-files-0.2.0.jpg` is byte-identical to the [actual round 3 capture](../docs/qa/screenshots/sidebar-files-0.2.0.jpg). It preserves the local sidebar review candidate before the icon update. The site labels it as a 0.2.0 review capture; its historical status is retained; the current main screen comes from the signed 0.3.0 distribution.
- `assets/social-preview.png` is a 1200×630 presentation card composed from [`social-preview.html`](../assets/branding/social-preview.html), the canonical SVG, text and actual signed 0.3.0 Read capture. It does not replace or fabricate the app screenshot. Regenerate it with `python3 scripts/prepare-social-preview.py --browser-channel msedge` when its text or imagery changes.

Use the repository [branding source](../assets/branding/README.md) to change the icon. Keep download version, captions, structured data and public distribution status consistent.

Search indexing and discovery measurement remain separate follow-up work in [issue #16](https://github.com/magicsih/leaflit/issues/16).

## Search Console

The URL-prefix property is `https://magicsih.github.io/leaflit/`. The owner-provided `google-site-verification` meta tag belongs in the served homepage head and must remain after verification. This public verification token is not an application credential. Robots references `https://magicsih.github.io/leaflit/sitemap.xml`, which contains the canonical homepage.

Read back the deployed HTML/tag and sitemap before using Search Console's Verify and sitemap submission. Record property verification, sitemap acceptance, indexing and actual search traffic separately; publishing a meta tag alone establishes none of the latter states. Account details and browser/session evidence stay outside Git.

See Google's [ownership verification](https://support.google.com/webmasters/answer/9008080?hl=en) and [Sitemaps report](https://support.google.com/webmasters/answer/7451001) instructions.
