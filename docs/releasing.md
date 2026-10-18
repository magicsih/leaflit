# Releasing Leaflit

Public distribution uses GitHub Releases and `magicsih/homebrew-tap`. The first release is 0.1.0 for Apple Silicon. Publishing a source commit, signing, notarization, release visibility and Homebrew availability are separate states.

## Prepare the candidate

Use English for all maintained documentation and GitHub assets. Record follow-up work as issues. Keep the worktree clean and preserve the exact candidate SHA. Do not rewrite historical commits.

An independent reviewer runs the approved complete checks and normal Release build, sequentially on the shared macOS environment:

```sh
./scripts/verify.sh Release
./scripts/build.sh Release
```

`build/verification.json` and `build/Leaflit-0.1.0/build-info.json` must match the candidate. Packaging rejects failed, incomplete, future-dated or older-than-168-hour evidence. The three original UI review rounds remain historical evidence where product paths are unchanged; a signed-artifact smoke check is a separate distribution check.

## Sign and notarize

Resolve the existing Developer ID and Apple notarization authorization from the local credential catalog. Verify account/team and certificate fingerprint before use. Reuse the registered identity; do not create replacement keys or expose private values. Keep private credential paths and operator evidence outside Git. The packaging script accepts public identity/team values and never reads private keys or passwords.

```sh
python3 scripts/package-release.py prepare \
  --identity "$LEAFLIT_SIGN_IDENTITY" --team-id "$LEAFLIT_TEAM_ID"
```

Preparation creates a new output directory, copies the verified app, bundles the launcher under `Contents/Helpers`, signs nested code before the outer app with hardened runtime, verifies the signature, and creates `build/releases/0.1.0/notarization-upload.zip`. It refuses an existing output directory rather than overwrite a previous candidate.

Submit that upload with the existing Apple API authorization. The following variables refer to the registered key file and its public identifiers; do not put their private contents in commands or logs.

```sh
xcrun notarytool submit build/releases/0.1.0/notarization-upload.zip \
  --key "$APPLE_API_KEY_P8" --key-id "$APPLE_API_KEY_ID" \
  --issuer "$APPLE_API_ISSUER_ID" --output-format json
```

Record the returned submission ID, poll `notarytool info` with the same authorization, and save an Accepted JSON receipt outside Git. A timeout or ambiguous submit response requires history/status readback before another submit. A rejected submission is not a pass; inspect its log and resolve the reported cause.

```sh
python3 scripts/package-release.py finalize \
  --receipt build/releases/0.1.0/notarization-receipt.json
```

Finalization requires Accepted status, verifies the unchanged upload/executable, staples and validates the ticket, runs strict signature verification and Gatekeeper, and creates a separate final ZIP, `SHA256SUMS` and `release-manifest.json`. Do not replace the uploaded archive or mutate the final ZIP. The final archive differs from the pre-stapling upload by design.

## Verify and publish

Extract the final ZIP into an isolated folder and launch that actual signed app. Check rendering, opening a document, the bundled launcher and remaining release-specific file routes. Keep inaccessible or unexecuted behavior explicit.

Create the owner-approved `v0.1.0` tag on the fixed candidate and push it. Create a draft GitHub release with the English notes in `docs/releases/0.1.0.md`, the final ZIP, `SHA256SUMS` and manifest. Confirm the remote tag SHA and uploaded asset hashes, then publish the same draft. Mark this first release as a preview/prerelease.

Download the public assets without authentication and compare their hashes with the verified local artifact. Extract the downloaded app, validate its signature, stapled ticket and Gatekeeper result, then launch it. Release visibility alone does not establish these checks.

## Homebrew

Render `packaging/homebrew/leaflit.rb` with the actual version and final ZIP checksum. Re-read the existing tap's default branch and preserve unrelated changes. Submit the small cask update as an English Ready PR, run its available checks and merge without bypassing repository rules.

Verify the published cask URL/checksum and actual installation:

```sh
brew install --cask magicsih/tap/leaflit
leaflit "path/to/document.md"
```

Before installation, check for an existing Leaflit app or command and preserve unrelated user installations. Keep Gatekeeper/quarantine enabled. Disable unrelated automatic dependency cleanup during a verification install. Confirm the installed app, command symlink, signed executable identity and document-opening behavior. A personal tap is separate from official `homebrew/cask` acceptance; the latter is tracked in issue #6.
