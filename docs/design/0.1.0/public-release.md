# Leaflit 0.1.0 public release preparation

## Authorization and scope

On 2026-10-19 the owner requested English repository and GitHub content, GitHub issues for follow-up work, and sequential execution of the proposed first-release procedure. This extends the original local-only endpoint to a public GitHub release and distribution through the existing `magicsih/homebrew-tap`. Use version 0.1.0 and bundle identifier `io.github.magicsih.leaflit` for Apple Silicon. Do not add Intel support or a new updater as part of this release.

## Sequence

1. Translate maintained repository prose into English while preserving historical evidence and deliberate Unicode test data. Add repository language instructions. Preserve existing commit history.
2. Create and verify the public `magicsih/leaflit` repository and origin. Publish the approved source history, then register evidence-backed follow-up issues in English.
3. Check the remaining file-drop and external-link flows in the actual macOS app. Investigate whether post-close memory retention blocks safe reading; record unresolved optimization work as issues rather than claim it fixed.
4. Re-run the approved independent L3 development checks on the fixed candidate. Carry forward the three completed UI review rounds where product paths have not changed. Packaging verification is separate from a UI redesign review round.
5. Reuse the registered Developer ID identity and Apple notarization authorization. Sign nested code, enable hardened runtime, notarize, staple, verify Gatekeeper and launch the signed app. Preserve credential values and existing identities.
6. Prepare an English GitHub release, publish the exact verified archive and its checksum, and verify an unauthenticated download.
7. Add an English cask to the existing tap, validate its version, checksum and architecture requirement, then verify installation and the `leaflit` launcher against the public archive.

## Evidence and limitations

Keep source SHA, executable hash, archive hash, signing identity, notarization status, stapling, Gatekeeper, publication and Homebrew readback distinct. Build output and private credential references stay outside Git. The minimum build target is macOS 14; actual runtime coverage is Apple M3 and macOS 26.6.2. Earlier macOS, Intel and complete spoken VoiceOver navigation remain separate unresolved checks. The initial performance goals remain comparison targets, and memory retention is not classified as a leak without further evidence.

Release records belong under `docs/releases`. Register follow-up acceptance criteria in GitHub issues and link them from the release notes. Do not mark an unexecuted or blocked check passed.
