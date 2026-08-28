#!/usr/bin/env bash
# ==============================================================================
# compile.sh - Compile .txt rule lists to sing-box .srs binary rule sets
# ==============================================================================
set -euo pipefail

# Locate sing-box executable
SING_BOX="${SING_BOX_BIN:-$(command -v sing-box 2>/dev/null || echo "./sing-box")}"

if [ ! -x "$SING_BOX" ]; then
    echo "Error: sing-box binary not found or not executable at: $SING_BOX" >&2
    exit 1
fi

compile_single_file() {
    local input_file="$1"

    if [[ "$input_file" != *.txt ]]; then
        echo "Warning: Skipping '$input_file' (does not end with .txt)" >&2
        return 0
    fi

    if [ ! -f "$input_file" ]; then
        echo "Warning: File '$input_file' not found" >&2
        return 0
    fi

    local base_name="${input_file%.txt}"
    local json_file="${base_name}.json"
    local srs_file="${base_name}.srs"

    # Convert .txt to sing-box JSON rule format using jq
    jq -R -s -c '
      split("\n")
      | map(select(length > 0 and (startswith("#") | not)))
      | if length == 0 then empty else {
          version: 1,
          rules: [
            {
              (if (.[0] | (test("^([0-9]{1,3}\\.){3}[0-9]{1,3}(/[0-9]{1,2})?$") or (contains(":") and test("^[0-9a-fA-F:]+(/[0-9]{1,3})?$")))) then "ip_cidr" else "domain_suffix" end): .
            }
          ]
        } end
    ' "$input_file" > "$json_file"

    if [ ! -s "$json_file" ]; then
        echo "Info: '$input_file' is empty or contains only comments. Skipping."
        rm -f "$json_file"
        return 0
    fi

    "$SING_BOX" rule-set compile --output "$srs_file" "$json_file"
    rm -f "$json_file"
    echo "✓ Successfully compiled: $srs_file"
}

export -f compile_single_file
export SING_BOX

if [ "$#" -gt 0 ]; then
    # Compile files passed as arguments
    for file in "$@"; do
        compile_single_file "$file"
    done
else
    # Find all .txt files in the current directory and compile in parallel
    find . -maxdepth 1 -name "*.txt" -type f -print0 | xargs -0 -n 1 -P "$(nproc 2>/dev/null || echo 2)" bash -c 'compile_single_file "$@"' _
fi
