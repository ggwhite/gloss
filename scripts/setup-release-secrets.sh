#!/bin/bash
# Sets the GitHub secrets the release workflow needs, from this Mac. Nothing secret is printed or kept.
#
#   scripts/setup-release-secrets.sh cert
#       Exports your "Developer ID Application" certificate and key from the login keychain
#       (macOS asks you to allow the export), re-packs only that identity with a random password,
#       and sets MACOS_CERTIFICATE_P12, MACOS_CERTIFICATE_PASSWORD and MACOS_CODESIGN_IDENTITY.
#
#   scripts/setup-release-secrets.sh notary-key /path/to/AuthKey_XXXXXXXXXX.p8 <issuer-id>
#       App Store Connect API key (App Store Connect → Users and Access → Integrations → Keys).
#       Sets NOTARY_KEY_P8, NOTARY_KEY_ID (from the file name) and NOTARY_ISSUER_ID.
#
#   scripts/setup-release-secrets.sh notary-apple-id
#       Apple ID + app-specific password (appleid.apple.com → Sign-In and Security → App-Specific
#       Passwords). Asks for both without echoing; sets NOTARY_APPLE_ID, NOTARY_PASSWORD, NOTARY_TEAM_ID.
#
# Then rebuild the release:  gh workflow run release.yml -f tag=v0.1.0
set -euo pipefail
cd "$(dirname "$0")/.."
REPO="${REPO:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"
OPENSSL=/usr/bin/openssl   # LibreSSL: writes .p12 files that `security import` reads everywhere

identity() {
    security find-identity -v -p codesigning | sed -n 's/.*"\(Developer ID Application: [^"]*\)".*/\1/p' | head -1
}

case "${1:-}" in
cert)
    ID="$(identity)"
    [ -n "$ID" ] || { echo "No \"Developer ID Application\" certificate in the keychain." >&2; exit 1; }
    TMP="$(mktemp -d)"; chmod 700 "$TMP"
    trap 'rm -rf "$TMP"' EXIT
    ALL_PASS="$($OPENSSL rand -hex 24)"
    P12_PASS="$($OPENSSL rand -hex 24)"
    echo "Exporting the keychain identities. macOS will ask to allow it: enter your login password and click Allow."
    security export -k "$HOME/Library/Keychains/login.keychain-db" -t identities -f pkcs12 \
        -P "$ALL_PASS" -o "$TMP/all.p12" >/dev/null
    $OPENSSL pkcs12 -in "$TMP/all.p12" -passin "pass:$ALL_PASS" -nodes -out "$TMP/all.pem" 2>/dev/null
    # Keep only the Developer ID certificate and the private key that matches it.
    python3 - "$TMP" "$OPENSSL" <<'PY'
import re, subprocess, sys, pathlib
tmp, openssl = pathlib.Path(sys.argv[1]), sys.argv[2]
pem = (tmp / "all.pem").read_text()
blocks = re.findall(r"-----BEGIN ([A-Z ]+)-----.*?-----END \1-----\n?", pem, re.S)
texts = [m.group(0) for m in re.finditer(r"-----BEGIN ([A-Z ]+)-----.*?-----END \1-----\n?", pem, re.S)]
def run(args, data):
    return subprocess.run([openssl] + args, input=data.encode(), capture_output=True).stdout.decode()
certs = [t for t in texts if "CERTIFICATE" in t.split("\n")[0]]
keys = [t for t in texts if "PRIVATE KEY" in t.split("\n")[0]]
cert = next(c for c in certs if "Developer ID Application" in run(["x509", "-noout", "-subject"], c))
pub = run(["x509", "-noout", "-pubkey"], cert)
key = next(k for k in keys if run(["pkey", "-pubout"], k) == pub)
(tmp / "cert.pem").write_text(cert)
(tmp / "key.pem").write_text(key)
PY
    security find-certificate -c "Developer ID Certification Authority" -p > "$TMP/ca.pem" 2>/dev/null || true
    CA=(); [ -s "$TMP/ca.pem" ] && CA=(-certfile "$TMP/ca.pem")
    $OPENSSL pkcs12 -export -inkey "$TMP/key.pem" -in "$TMP/cert.pem" ${CA[@]+"${CA[@]}"} \
        -name "$ID" -passout "pass:$P12_PASS" -out "$TMP/dev.p12"
    base64 -i "$TMP/dev.p12" | gh secret set MACOS_CERTIFICATE_P12 -R "$REPO"
    printf '%s' "$P12_PASS" | gh secret set MACOS_CERTIFICATE_PASSWORD -R "$REPO"
    printf '%s' "$ID" | gh secret set MACOS_CODESIGN_IDENTITY -R "$REPO"
    echo "Set MACOS_CERTIFICATE_P12, MACOS_CERTIFICATE_PASSWORD, MACOS_CODESIGN_IDENTITY on $REPO."
    ;;
notary-key)
    P8="${2:?path to AuthKey_XXXXXXXXXX.p8}"; ISSUER="${3:?issuer id}"
    KEY_ID="$(basename "$P8" .p8)"; KEY_ID="${KEY_ID#AuthKey_}"
    base64 -i "$P8" | gh secret set NOTARY_KEY_P8 -R "$REPO"
    printf '%s' "$KEY_ID" | gh secret set NOTARY_KEY_ID -R "$REPO"
    printf '%s' "$ISSUER" | gh secret set NOTARY_ISSUER_ID -R "$REPO"
    echo "Set NOTARY_KEY_P8, NOTARY_KEY_ID ($KEY_ID), NOTARY_ISSUER_ID on $REPO."
    ;;
notary-apple-id)
    TEAM="$(identity | sed -n 's/.*(\([A-Z0-9]*\))$/\1/p')"
    read -r -p "Apple ID email: " APPLE_ID
    read -r -s -p "App-specific password (xxxx-xxxx-xxxx-xxxx): " APP_PW; echo
    printf '%s' "$APPLE_ID" | gh secret set NOTARY_APPLE_ID -R "$REPO"
    printf '%s' "$APP_PW" | gh secret set NOTARY_PASSWORD -R "$REPO"
    printf '%s' "$TEAM" | gh secret set NOTARY_TEAM_ID -R "$REPO"
    echo "Set NOTARY_APPLE_ID, NOTARY_PASSWORD, NOTARY_TEAM_ID ($TEAM) on $REPO."
    ;;
*)
    sed -n '2,20p' "$0"; exit 2 ;;
esac
