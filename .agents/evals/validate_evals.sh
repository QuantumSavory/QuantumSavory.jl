#!/usr/bin/env bash

set -eu

usage() {
    cat <<'EOF'
Usage: validate_evals.sh [EVAL_DIR]

Validate that each eval entry in EVAL_DIR has exactly three files:
<name>-Q.md, <name>-A.md, and <name>.yaml.

If EVAL_DIR is omitted, the script validates the directory containing itself.
EOF
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
    usage
    exit 0
fi

if [ "$#" -gt 1 ]; then
    usage >&2
    exit 2
fi

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
eval_dir=${1:-"$script_dir"}
script_name=${0##*/}

if [ ! -d "$eval_dir" ]; then
    printf 'error: eval directory not found: %s\n' "$eval_dir" >&2
    exit 1
fi

declare -A have_q have_a have_yaml
errors=0

while IFS= read -r -d '' path; do
    file=${path##*/}

    if [ "$file" = "$script_name" ]; then
        continue
    fi

    if [ "$file" = "README.md" ]; then
        continue
    fi

    if [ -d "$path" ]; then
        printf 'stray directory: %s\n' "$file" >&2
        errors=1
        continue
    fi

    case $file in
        *-Q.md)
            stem=${file%-Q.md}
            have_q["$stem"]=1
            ;;
        *-A.md)
            stem=${file%-A.md}
            have_a["$stem"]=1
            ;;
        *.yaml)
            stem=${file%.yaml}
            have_yaml["$stem"]=1
            ;;
        *)
            printf 'stray file: %s\n' "$file" >&2
            errors=1
            ;;
    esac
done < <(find "$eval_dir" -mindepth 1 -maxdepth 1 \( -type f -o -type d \) -print0)

all_stems=$(
    {
        for stem in "${!have_q[@]}"; do printf '%s\n' "$stem"; done
        for stem in "${!have_a[@]}"; do printf '%s\n' "$stem"; done
        for stem in "${!have_yaml[@]}"; do printf '%s\n' "$stem"; done
    } | sort -u
)

while IFS= read -r stem; do
    [ -n "$stem" ] || continue
    [ "${have_q[$stem]+set}" = set ] || { printf 'missing file: %s-Q.md\n' "$stem" >&2; errors=1; }
    [ "${have_a[$stem]+set}" = set ] || { printf 'missing file: %s-A.md\n' "$stem" >&2; errors=1; }
    [ "${have_yaml[$stem]+set}" = set ] || { printf 'missing file: %s.yaml\n' "$stem" >&2; errors=1; }
done <<EOF
$all_stems
EOF

if [ "$errors" -ne 0 ]; then
    exit 1
fi

printf 'validated %s\n' "$eval_dir"
