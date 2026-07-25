#!/usr/bin/env bash
# Check 5 — Internal Doc Links Resolve
# ตรวจว่าทุก [text](file.md) ใน docs ชี้ไฟล์ที่มีอยู่จริง
#
# Returns:
#   0 = pass
#   1 = fail

set -euo pipefail
cd "$(dirname "$0")/../../.."

echo "📋 Check 5: Internal Doc Links Resolve"

failures=0
total_links=0

# Use grep + find to check links
while IFS= read -r file; do
  # [V6.0.075] Skip links inside backtick code spans (e.g. `[link](file.md)` as example text)
  # Strip backtick code spans before searching for links
  clean_content=$(sed 's/`[^`]*`//g' "$file")

  # Find markdown links like [text](path.md) or [text](./path.md)
  while IFS= read -r link; do
    [[ -z "$link" ]] && continue
    total_links=$((total_links+1))

    # Strip anchor
    target="${link%%#*}"

    # Skip external links
    [[ "$target" =~ ^https?:// ]] && continue
    [[ -z "$target" ]] && continue

    # [V6.0.075] Skip URL-encoded Thai filenames (%20) — check both encoded + decoded
    if [[ "$target" == *"%20"* ]]; then
      decoded_target=$(printf '%b' "${target//%/\\x}")
      dir=$(dirname "$file")
      full_path_decoded="$dir/$decoded_target"
      full_path_encoded="$dir/$target"
      if [[ -f "$full_path_decoded" || -f "$full_path_encoded" ]]; then
        continue
      fi
    fi

    # Resolve relative to file's directory
    dir=$(dirname "$file")
    full_path="$dir/$target"

    if [[ ! -f "$full_path" ]]; then
      echo "  ❌ $file: link '$target' does not resolve"
      failures=$((failures+1))
    fi
  done < <(echo "$clean_content" | grep -oP '\[[^\]]+\]\(\K[^)]+\.md[^)]*' || true)
done < <(find . -name "*.md" -not -path "./node_modules/*")

if [[ $failures -eq 0 ]]; then
  echo "  ✅ All $total_links internal links resolve"
  exit 0
else
  echo "  ❌ $failures broken links (out of $total_links)"
  exit 1
fi
