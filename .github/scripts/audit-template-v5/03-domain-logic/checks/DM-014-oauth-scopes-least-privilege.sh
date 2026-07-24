#!/usr/bin/env bash
# DM-014 — SEC-002 OAuth scope least privilege
# v5 FIX: เปลี่ยนจาก awk parser เป็น python -c json.load เพื่อ parse appsscript.json ที่ถูกต้อง
#
# Rule:
#   - appsscript.json ต้องมี oauthScopes array ที่ explicit
#   - ห้ามใช้ forbidden scopes (admin.directory, cloud-platform)
#   - broad scopes (spreadsheets, drive, mail.google.com) = warning (ไม่ block)
#
# Returns: 0 = pass, 1 = fail

set -uo pipefail
REPO="${1:-.}"

echo "📋 DM-014: SEC-002 OAuth scope least privilege"

config="$REPO/appsscript.json"

if [[ ! -f "$config" ]]; then
  echo "  ℹ️  No appsscript.json — skipping"
  exit 0
fi

# v5: Use python3 to parse JSON properly (replaces buggy awk parser)
scopes=$(python3 -c "
import json, sys
try:
    with open('$config') as f:
        data = json.load(f)
    scopes = data.get('oauthScopes', [])
    if not scopes:
        print('MISSING', end='')
    else:
        for s in scopes:
            print(s)
except Exception as e:
    print('ERROR:' + str(e), file=sys.stderr)
    sys.exit(1)
" 2>&1)

if [[ "$scopes" == "MISSING" ]]; then
  echo "  ⚠️  No oauthScopes array in appsscript.json — GAS will request all scopes (overly broad)"
  echo "  💡 Fix: Add explicit oauthScopes array:"
  echo '      "oauthScopes": ['
  echo '        "https://www.googleapis.com/auth/spreadsheets",'
  echo '        "https://www.googleapis.com/auth/userinfo.email",'
  echo '        ...'
  echo '      ]'
  exit 1
fi

if [[ "$scopes" == ERROR:* ]]; then
  echo "  ❌ Failed to parse appsscript.json: $scopes"
  exit 1
fi

total_scopes=$(echo "$scopes" | wc -l | tr -d ' ')
echo "  📊 Total OAuth scopes: $total_scopes"
echo "  📊 Scopes in use:"
echo "$scopes" | sed 's|^|    - |'

# Forbidden scopes (block deploy if found)
FORBIDDEN_PATTERNS=(
  "https://www.googleapis.com/auth/admin.directory"
  "https://www.googleapis.com/auth/cloud-platform"
)

# Broad scopes (warning only — may be necessary)
BROAD_SCOPES=(
  "https://www.googleapis.com/auth/spreadsheets$"
  "https://www.googleapis.com/auth/drive$"
  "https://www.googleapis.com/auth/drive.file$"
  "https://mail.google.com/$"
  "https://www.googleapis.com/auth/gmail.modify$"
  "https://www.googleapis.com/auth/userinfo.profile$"
)

# Check forbidden scopes
forbidden_count=0
while IFS= read -r scope; do
  [[ -z "$scope" ]] && continue
  for pattern in "${FORBIDDEN_PATTERNS[@]}"; do
    if echo "$scope" | grep -qE "^${pattern}"; then
      echo "  ❌ Forbidden scope: $scope"
      forbidden_count=$((forbidden_count + 1))
    fi
  done
done <<< "$scopes"

if [[ "$forbidden_count" -gt 0 ]]; then
  echo ""
  echo "  ❌ Forbidden admin/cloud-platform scopes detected — remove immediately"
  exit 1
fi

# Check broad scopes (warning only)
broad_count=0
while IFS= read -r scope; do
  [[ -z "$scope" ]] && continue
  for pattern in "${BROAD_SCOPES[@]}"; do
    if echo "$scope" | grep -qE "^${pattern}$"; then
      broad_count=$((broad_count + 1))
      break
    fi
  done
done <<< "$scopes"

if [[ "$broad_count" -gt 0 ]]; then
  echo ""
  echo "  ⚠️  $broad_count broad scope(s) in use (may be necessary — review each)"
  echo "  ℹ️  Some broad scopes may be required (e.g. spreadsheets for master data writes)"
  echo "  💡 Consider .readonly alternatives where possible"
  exit 0  # warning only
fi

echo ""
echo "  ✅ OAuth scopes follow least privilege (no forbidden, no broad scopes)"
exit 0
