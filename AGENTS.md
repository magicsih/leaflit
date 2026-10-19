# Repository instructions

- Use English for maintained repository documentation, code comments, commit messages, pull requests, issues, labels, release notes, repository metadata and other GitHub assets.
- Keep Unicode examples and non-English strings when they are deliberate test inputs. Explain those tests in English.
- Preserve existing commit history. Translating a historical QA report must preserve its candidate, observations, failures, limitations and verification status.
- Keep conversation language separate from repository language; Korean conversation remains supported.
- Work on local `main` while preparing the first public release, as authorized by the owner. Preserve unrelated changes and never rewrite existing history without explicit approval.
- Keep the app read-first. Opening, rendering, refreshing and switching modes never write to a document. Write only after an explicit Source Save or Save a Copy action. Preserve dirty drafts on external changes and never silently overwrite a changed original.
- Run `scripts/verify.sh Release` for product changes. Use the approved independent L3 verification for release candidates. Do not repeat the three original UI review rounds for documentation-only changes.
- Keep build, signing, notarization, GitHub publication, Homebrew publication and downloaded-artifact verification as separate recorded states.
- Reuse registered signing identities without exposing secrets. Do not commit credentials, local evidence logs or generated build output.
- Record remaining work in GitHub issues with observed evidence and acceptance criteria. Do not claim unexecuted checks passed.
