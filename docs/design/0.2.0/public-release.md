# Leaflit 0.2.0 public release

## Authorization and scope

On 2026-10-19 the owner requested: "Publish 0.2.0." This extends the completed local 0.2.0 sidebar/icon endpoint to a public GitHub preview and an update of the existing personal Homebrew tap. Preserve the 0.1.0 release and all historical QA. The app remains read-only, Apple Silicon only, with a macOS 14 deployment target. No updater, Intel build or official Homebrew cask submission is included.

The existing three independent sidebar UI rounds and their corrections remain the product evidence identified in [the sidebar report](../../qa/sidebar-report.md). The centered icon has separate final Finder observations in the [PR #18 handoff](https://github.com/magicsih/leaflit/pull/18#issuecomment-6257585191). This release preparation changes documentation, not reader behavior. Do not repeat or relabel those rendered reviews.

## Execution

1. Fix and commit the release preparation. An independent executor runs `./scripts/verify.sh Release` followed by a separate ordinary `./scripts/build.sh Release` on the final candidate. Preserve existing processes, public artifacts, fixtures and preferences.
2. Reuse the registered Developer ID and notarization authorization, checking their public identity. Prepare a new immutable 0.2.0 distribution, notarize, staple and verify strict signature and Gatekeeper.
3. Extract and launch the exact signed artifact with owned fixtures. Verify Files, Outline, relative navigation, Back, Mermaid, math, source hashes and bundled launcher. Inspect the new icon only where the target can be attributed to that exact app. This is a bounded distribution smoke check, not a fourth sidebar redesign review.
4. Create and read back the fixed `v0.2.0` tag. Upload the final archive, checksum and manifest to a draft English GitHub preview. Verify asset digests, then publish that same draft.
5. Download the public assets without authentication, verify their bytes, signature, ticket and Gatekeeper, and launch the actual downloaded app.
6. Update the existing personal tap with the immutable version/checksum through a Ready PR. Preserve unrelated tap changes and repository rules. Verify the live cask and a quarantined installation in an isolated app directory; preserve the user's existing /Applications installation and running apps. Keep official cask policy separate.
7. Update README and the public website only after the new download exists. Recheck the deployed version, links, images and narrow layout. Record publication, Homebrew, downloaded artifact and installation as separate results.

## Limits

Only Apple M3/macOS 26.6.2 runtime evidence exists. Keep earlier macOS (#5), spoken VoiceOver (#4), actual Finder drops (#8), network-isolated execution (#12) and sidebar width persistence (#13) unverified unless executed. Resource measurements retain their original candidate identity; this release does not claim the 60MiB goal or a new performance improvement. Icon Dock/application-switcher coverage is tracked in #9. Indexing and traffic measurement remain #16. A known unexecuted check is not a pass and must remain visible in the release notes.
