# Public website

This directory is the public English introduction at <https://magicsih.github.io/leaflit/>. It explains the terminal-to-Markdown use case and links the current public 0.1.0 preview. Main's local 0.2.0 sidebar and new icon are explicitly distinguished from that download.

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

- `assets/leaflit-0.1.0.jpg` is an unedited native capture of an isolated copy of the installed signed public 0.1.0 app, rendering a reviewer-owned `plan.md`. Its binary matched the published executable `20f04c5661b030955ee4e22b041062fbf9ffa244c82ecd16a1efcbf59e45a933`. Raw fixture/capture records are in ignored `build/website-capture-20261019/`. The capture copy was closed and its Markdown hash remained unchanged.
- `assets/sidebar-files-0.2.0.jpg` is byte-identical to the [actual round 3 capture](../docs/qa/screenshots/sidebar-files-0.2.0.jpg). It shows the local sidebar candidate before the icon update and is labeled as local 0.2.0.
- `assets/social-preview.png` is a 1200×630 presentation card composed from [`social-preview.html`](../assets/branding/social-preview.html), the canonical SVG, text and actual public app capture. It does not replace or fabricate the app screenshot. Regenerate it with `python3 scripts/prepare-social-preview.py --browser-channel msedge` when its text or imagery changes.

Use the repository [branding source](../assets/branding/README.md) to change the icon. Keep download version, captions, structured data and public distribution status consistent.

Search indexing and discovery measurement remain separate follow-up work in [issue #16](https://github.com/magicsih/leaflit/issues/16).
