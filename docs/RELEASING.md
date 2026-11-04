# Releasing

Releases are fully automated:

1. Merge PRs into `main` with Conventional Commit titles (`feat:` bumps the minor version,
   `fix:` bumps the patch while we're pre-1.0).
2. [release-please](https://github.com/googleapis/release-please) keeps a **release PR** open
   that bumps `version.txt` and updates `CHANGELOG.md`.
3. Merging the release PR creates a **draft** GitHub release and tag. The `macos` job in
   [`release.yml`](../.github/workflows/release.yml) then:
   - builds a universal `Possum.app`
   - signs the helper and the app with a **Developer ID Application** certificate (hardened runtime, secure timestamp)
   - packs and signs a DMG, then notarizes it with `notarytool` using an App Store Connect API key
   - staples the DMG and the app, then checks both with `spctl`
   - uploads `Possum-x.y.z.dmg`, `Possum-x.y.z.zip` and `SHA256SUMS.txt`, then **publishes** the release.

If any step fails, the release stays a private draft. To retry after fixing the cause, run
the **Release** workflow manually with the tag (e.g. `v0.1.0`).

### Signed dry run

To check signing and notarization without publishing anything, run the **Release** workflow
manually with an empty tag:

```bash
gh workflow run release.yml --repo Magwest1/possum --ref main
```

The notarized DMG and ZIP are attached to the run as an artifact for 7 days.

## One-time setup

### 1. GitHub environment `release`

The signing job runs in the `release` environment, which only `main` can deploy to. Add these
**environment secrets** under *Settings › Environments › release*. Never commit them.

| Secret | What it is | How to produce it |
| --- | --- | --- |
| `MACOS_CERTIFICATE_P12` | Developer ID Application certificate and private key, base64 | Export from Keychain Access as `.p12`, then `base64 -i cert.p12 \| pbcopy` |
| `MACOS_CERTIFICATE_PASSWORD` | Password you set when exporting the `.p12` | — |
| `APPLE_API_KEY_P8` | App Store Connect API key (`AuthKey_XXXX.p8`), base64 | App Store Connect › Users and Access › Integrations › Keys, role *Developer*. Then `base64 -i AuthKey_XXXX.p8 \| pbcopy` |
| `APPLE_API_KEY_ID` | Key ID of that API key | Shown next to the key |
| `APPLE_API_ISSUER` | Issuer ID (UUID) | Shown at the top of the Keys page |

These are the same names the folio app uses, so you can reuse the same values.

The easiest way is the setup script. It checks that the `.p12` contains a Developer ID
Application identity and that Apple accepts the API key, then uploads all five secrets.
It prompts for the `.p12` password and the issuer ID and never prints them:

```bash
scripts/setup-release-secrets.sh ~/path/to/DeveloperID.p12 ~/path/to/AuthKey_XXXX.p8
```

Or set them manually with the GitHub CLI (it reads each value from stdin, so it never lands in your shell history):

```bash
base64 -i DeveloperID.p12 | gh secret set MACOS_CERTIFICATE_P12 --env release --repo Magwest1/possum
gh secret set MACOS_CERTIFICATE_PASSWORD --env release --repo Magwest1/possum
base64 -i AuthKey_XXXX.p8 | gh secret set APPLE_API_KEY_P8 --env release --repo Magwest1/possum
gh secret set APPLE_API_KEY_ID --env release --repo Magwest1/possum
gh secret set APPLE_API_ISSUER --env release --repo Magwest1/possum
```

Delete the local `.p12` and base64 copies afterwards.

### 2. Repository settings

- *Settings › Actions › General › Workflow permissions*: **Read and write**, and
  **Allow GitHub Actions to create and approve pull requests** (release-please needs both).

## Signing locally

```bash
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" scripts/build-app.sh
```

The helper pins its client to the same team ID it was signed with, so the app and the helper
must always be signed by the same team.
