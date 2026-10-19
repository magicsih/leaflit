# Leaflit 0.3.0 public release

The owner explicitly requested public 0.3.0 distribution on 2026-10-19. This extends the completed local Source-editing endpoint to a public GitHub preview, the existing personal Homebrew tap, public-download and isolated-install execution, and README/Pages readback. Historical local-only plans and reports retain their original scope.

The fixed product source is `f7f6cd9c74e3d601b6a7beca60a65adc3d698851`. Independent complete Release verification and a separate ordinary build already passed on that exact commit. The entire ordinary app and launcher matched the product reviewed in the three Source UI rounds. Reuse that fresh evidence; do not start a fourth redesign review or repeat memory measurements for signing and documentation.

The app is read-first: only explicit Source Save or Save a Copy writes a document. Apple Silicon and macOS 14 remain the build targets. Only Apple M3/macOS 26.6.2 runtime evidence exists. Rich-text Write, Intel, an updater and official Homebrew cask submission are outside this release.

## Distribution checks

1. Reuse the registered Developer ID and notarization authorization, verify public certificate/team identity, sign nested code and the app with hardened runtime, submit once, record Accepted, staple and validate, then run strict signature and Gatekeeper checks.
2. Independently extract and launch the exact final ZIP with owned English fixtures. Check Read/Source, unsaved preview, explicit save, Undo, error-to-source repair, navigation, Mermaid/math and the bundled launcher. Capture real Read and Source screens without reconstructing app UI.
3. Create and read back the annotated fixed `v0.3.0` tag. Upload ZIP, checksum and manifest to a draft English preview. Verify remote asset hashes before publishing the same draft.
4. Download all public assets without authentication; verify bytes, signature, ticket and Gatekeeper; execute the exact downloaded app.
5. Update the personal tap through an English Ready PR. Record syntax, style and the complete online-audit outcome separately. Use Homebrew's actual installer with the published recipe, an isolated app/Caskroom destination and quarantine intact. Execute that installed app and bundled launcher. Preserve the existing user installation, command and receipt.
6. Update public English README, website, metadata and screenshots after the public download exists. Check responsive rendering, exact Pages deployment and live HTTPS/assets independently.

Retain failed attempts and unexecuted coverage. Initial blank inactive Read capture (#29), formula clipboard fidelity (#26), ordinary Source dark appearance (#27), spoken VoiceOver (#4), earlier macOS (#5), Finder drop (#8), true network isolation (#12), icon surfaces (#9), discovery (#16), and memory/startup goals stay separate. A prerelease audit policy failure is not an audit pass. Do not replace `/Applications/Leaflit.app` or terminate the user's existing process to verify distribution.
