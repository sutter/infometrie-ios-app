#!/bin/sh
# Compares the live Yacast Swagger with the local contract (Docs/API/openapi.yaml).
#
# Exit codes:
#   0  the live specification is identical to the local contract
#   1  the live specification changed: the changelog is printed
#   2  the check could not run (Swagger unreachable, missing tool)
#
# The live specification is kept in build/api-contract/specs.yaml for review.

set -u

SPEC_URL="${SPEC_URL:-https://hls-test.yacast.fr/swagger/specs.yaml}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOCAL="$ROOT/Docs/API/openapi.yaml"
LIVE_DIR="$ROOT/build/api-contract"
LIVE="$LIVE_DIR/specs.yaml"

version() {
    sed -n 's/^  version: *"\{0,1\}\([^"]*\)"\{0,1\}$/\1/p' "$1" | head -n 1
}

if ! command -v oasdiff >/dev/null 2>&1; then
    echo "oasdiff est introuvable : brew install oasdiff" >&2
    exit 2
fi

mkdir -p "$LIVE_DIR"
if ! curl --silent --show-error --fail --max-time 30 "$SPEC_URL" -o "$LIVE"; then
    echo "Swagger injoignable : $SPEC_URL" >&2
    exit 2
fi

LOCAL_VERSION="$(version "$LOCAL")"
LIVE_VERSION="$(version "$LIVE")"

if cmp -s "$LOCAL" "$LIVE"; then
    echo "API inchangée ($LOCAL_VERSION)."
    exit 0
fi

echo "API modifiée : $LOCAL_VERSION => $LIVE_VERSION"
echo "Spécification en ligne : $LIVE"
echo "SHA-256 : $(shasum -a 256 "$LIVE" | cut -d ' ' -f 1)"
echo

CHANGELOG="$(oasdiff changelog --color never "$LOCAL" "$LIVE")"
if [ -n "$CHANGELOG" ]; then
    echo "$CHANGELOG"
else
    # Descriptions, examples and metadata are outside the changelog.
    echo "Aucun changement de route ou de paramètre. Différences textuelles :"
    diff -u "$LOCAL" "$LIVE"
fi
exit 1
