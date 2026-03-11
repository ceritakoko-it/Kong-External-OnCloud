#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 3 ]; then
  echo "Usage: $0 <template_dir> <env_file> <output_dir>"
  exit 1
fi

TEMPLATE_DIR="$1"
ENV_FILE="$2"
OUTPUT_DIR="$3"

test -d "$TEMPLATE_DIR" || { echo "Template directory not found: $TEMPLATE_DIR"; exit 1; }
test -f "$ENV_FILE" || { echo "Environment file not found: $ENV_FILE"; exit 1; }

set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

required_vars=(
  CONTROL_PLANE_NAME
  PUBLIC_HOST_PRIMARY
  GET_TOKEN_SERVICE_NAME
  GET_TOKEN_SERVICE_HOST
  ISSUER_URL
  KAOTIM_SERVICE_HOST
  POKEMON_SERVICE_HOST
  REDIS_PARTIAL_NAME
  REDIS_CACHE_PARTIAL_NAME
  VAULT_CONFIG_STORE_ID
)

for var_name in "${required_vars[@]}"; do
  test -n "${!var_name:-}" || { echo "Missing required variable in $ENV_FILE: $var_name"; exit 1; }
done

rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"
cp -R "$TEMPLATE_DIR"/. "$OUTPUT_DIR"/

find "$OUTPUT_DIR" -type f \( -name "*.yaml" -o -name "*.yml" -o -name "*.md" \) -print0 | while IFS= read -r -d '' file; do
  perl -0pe '
    my %repl = (
      "__CONTROL_PLANE_NAME__" => $ENV{"CONTROL_PLANE_NAME"},
      "__PUBLIC_HOST_PRIMARY__" => $ENV{"PUBLIC_HOST_PRIMARY"},
      "__GET_TOKEN_SERVICE_NAME__" => $ENV{"GET_TOKEN_SERVICE_NAME"},
      "__GET_TOKEN_SERVICE_HOST__" => $ENV{"GET_TOKEN_SERVICE_HOST"},
      "__ISSUER_URL__" => $ENV{"ISSUER_URL"},
      "__KAOTIM_SERVICE_HOST__" => $ENV{"KAOTIM_SERVICE_HOST"},
      "__POKEMON_SERVICE_HOST__" => $ENV{"POKEMON_SERVICE_HOST"},
      "__REDIS_PARTIAL_NAME__" => $ENV{"REDIS_PARTIAL_NAME"},
      "__REDIS_CACHE_PARTIAL_NAME__" => $ENV{"REDIS_CACHE_PARTIAL_NAME"},
      "__VAULT_CONFIG_STORE_ID__" => $ENV{"VAULT_CONFIG_STORE_ID"},
      "__OPTIONAL_PUBLIC_HOST_SECONDARY__" => length($ENV{"PUBLIC_HOST_SECONDARY"} // q{}) ? "  - " . $ENV{"PUBLIC_HOST_SECONDARY"} : q{},
    );
    s/(__CONTROL_PLANE_NAME__|__PUBLIC_HOST_PRIMARY__|__GET_TOKEN_SERVICE_NAME__|__GET_TOKEN_SERVICE_HOST__|__ISSUER_URL__|__KAOTIM_SERVICE_HOST__|__POKEMON_SERVICE_HOST__|__REDIS_PARTIAL_NAME__|__REDIS_CACHE_PARTIAL_NAME__|__VAULT_CONFIG_STORE_ID__|__OPTIONAL_PUBLIC_HOST_SECONDARY__)/$repl{$1}/ge;
  ' "$file" > "${file}.tmp"
  mv "${file}.tmp" "$file"
done

if grep -R -n -E '__[A-Z0-9_]+__' "$OUTPUT_DIR" >/dev/null; then
  echo "Unresolved template tokens found in rendered output:"
  grep -R -n -E '__[A-Z0-9_]+__' "$OUTPUT_DIR"
  exit 1
fi

echo "Rendered Kong state to: $OUTPUT_DIR"
