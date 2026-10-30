# Keep front matter out of the reading view

The owner reported that metadata enclosed by `---` at the start of a Markdown file appears as an oversized, combined title. The renderer currently interprets the closing delimiter as a Setext heading underline. This bounded correction keeps the existing reader layout and document-writing contract.

```text
Source                         Read
---                            Project notes
title: Internal metadata       Body text.
tags: [draft, notes]
---
# Project notes
Body text.
```

Recognize front matter only at the beginning of a document, allowing an initial UTF-8 BOM and using the Markdown parser's existing line-ending normalization. An opening line containing exactly `---`, optionally followed by spaces or tabs, must have a matching `---` or YAML document-end `...` line. Consume that complete block before ordinary Markdown block parsing. Do not evaluate YAML, use metadata as a title, or add a runtime dependency. Read and Outline contain only the Markdown body. Existing body headings remain unchanged; the native window continues to identify the file when the body has no heading.

Preserve original parser line numbers for scroll restoration and Edit Source. Source shows all metadata, including in unsaved drafts, and only explicit saving may write it. Incomplete blocks remain visible as ordinary Markdown instead of hiding the rest of a document. Body separators, Setext headings, nested blocks and fenced examples retain their existing behavior. A closed leading block uses the front-matter convention; this change does not validate its YAML content or support TOML/JSON front matter.

This follows the top-of-file metadata convention documented by [Obsidian](https://help.obsidian.md/properties) and [Jekyll](https://jekyllrb.com/docs/front-matter/). The Markdown parser's block rule preserves source positions without removing lines from the original text. Reverting the rule restores the previous display without a data migration.

Use [the L1 development test plan](test-plan.json). This is a rendering correction, not a new screen or a release candidate. App publication, signing, notarization and replacing the installed app remain outside this task. See [the verification record](../../qa/front-matter.md) for executed checks and evidence retention.
