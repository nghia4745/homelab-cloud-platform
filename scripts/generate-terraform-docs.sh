#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
README_FILE="$ROOT_DIR/README.md"
TMP_FILE="$(mktemp)"

modules=(networking iam ecr eks s3)

{
  echo "<!-- BEGIN_TF_DOCS -->"
  echo
  for module in "${modules[@]}"; do
    echo "### modules/${module}"
    echo
    terraform-docs markdown table "$ROOT_DIR/modules/${module}"
    echo
  done
  echo "<!-- END_TF_DOCS -->"
} > "$TMP_FILE"

awk -v new_block_file="$TMP_FILE" '
  BEGIN {
    while ((getline line < new_block_file) > 0) {
      new_block = new_block line "\n"
    }
    close(new_block_file)
    in_block = 0
    replaced = 0
  }
  {
    if ($0 ~ /<!-- BEGIN_TF_DOCS -->/) {
      if (!replaced) {
        printf "%s", new_block
        replaced = 1
      }
      in_block = 1
      next
    }
    if ($0 ~ /<!-- END_TF_DOCS -->/) {
      in_block = 0
      next
    }
    if (!in_block) {
      print
    }
  }
  END {
    if (!replaced) {
      printf "\n%s", new_block
    }
  }
' "$README_FILE" > "$README_FILE.tmp"

mv "$README_FILE.tmp" "$README_FILE"
rm -f "$TMP_FILE"

echo "README module docs updated via terraform-docs."