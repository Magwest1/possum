#!/usr/bin/env bash
# Uploads the Developer ID signing + notarization secrets to the GitHub
# `release` environment. Run it yourself in a terminal; it prompts for the
# .p12 password and App Store Connect issuer ID and never prints secret values.
#
# Usage: scripts/setup-release-secrets.sh <DeveloperID.p12> <AuthKey_KEYID.p8> [owner/repo]
set -euo pipefail

P12="${1:?usage: $0 <DeveloperID.p12> <AuthKey_KEYID.p8> [owner/repo]}"
P8="${2:?usage: $0 <DeveloperID.p12> <AuthKey_KEYID.p8> [owner/repo]}"
REPO="${3:-Magwest1/possum}"
ENVIRONMENT="release"

test -f "$P12" || { echo "Not found: $P12" >&2; exit 1; }
test -f "$P8" || { echo "Not found: $P8" >&2; exit 1; }
command -v gh >/dev/null || { echo "GitHub CLI (gh) is required" >&2; exit 1; }

key_id="$(basename "$P8" | sed -nE 's/^AuthKey_([A-Z0-9]+)\.p8$/\1/p')"
if [ -z "$key_id" ]; then
  read -r -p "App Store Connect Key ID: " key_id
fi
read -r -s -p "Password for $(basename "$P12"): " p12_password; echo
read -r -p "App Store Connect Issuer ID (UUID, top of the Keys page): " issuer
[[ "$issuer" =~ ^[0-9a-fA-F-]{36}$ ]] || { echo "Issuer ID should be a UUID" >&2; exit 1; }

echo "==> Checking the certificate"
tmp="$(mktemp -d)"
keychain="$tmp/check.keychain-db"
cleanup() { security delete-keychain "$keychain" 2>/dev/null || true; rm -rf "$tmp"; }
trap cleanup EXIT
kc_pass="$(openssl rand -base64 24)"
security create-keychain -p "$kc_pass" "$keychain"
security import "$P12" -k "$keychain" -P "$p12_password" -T /usr/bin/codesign >/dev/null \
  || { echo "Could not import the .p12 (wrong password?)" >&2; exit 1; }
identity="$(security find-identity -v -p codesigning "$keychain" | grep 'Developer ID Application' | head -n 1 || true)"
test -n "$identity" || { echo "No 'Developer ID Application' identity in $P12" >&2; exit 1; }
echo "    found:${identity#*)}"

echo "==> Checking the notarization API key"
xcrun notarytool history --key "$P8" --key-id "$key_id" --issuer "$issuer" --output-format json >/dev/null \
  || { echo "notarytool rejected the API key / key ID / issuer" >&2; exit 1; }
echo "    API key accepted by Apple"

echo "==> Uploading secrets to $REPO (environment: $ENVIRONMENT)"
base64 -i "$P12" | gh secret set MACOS_CERTIFICATE_P12 --env "$ENVIRONMENT" --repo "$REPO"
printf '%s' "$p12_password" | gh secret set MACOS_CERTIFICATE_PASSWORD --env "$ENVIRONMENT" --repo "$REPO"
base64 -i "$P8" | gh secret set APPLE_API_KEY_P8 --env "$ENVIRONMENT" --repo "$REPO"
printf '%s' "$key_id" | gh secret set APPLE_API_KEY_ID --env "$ENVIRONMENT" --repo "$REPO"
printf '%s' "$issuer" | gh secret set APPLE_API_ISSUER --env "$ENVIRONMENT" --repo "$REPO"
unset p12_password

gh secret list --env "$ENVIRONMENT" --repo "$REPO"
echo "==> Done. Trigger a signed dry run with:"
echo "    gh workflow run release.yml --repo $REPO --ref main"
