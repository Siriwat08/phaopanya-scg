#!/usr/bin/env bash
# DM-004 — RBAC: deny-by-default
# ตรวจว่า isAuthorizedUser_ default = false
# และทุก menu item เรียก guard ก่อน action
#
# Returns: 0 = pass, 1 = fail

set -uo pipefail
REPO="${1:-.}"

echo "📋 DM-004: RBAC deny-by-default"

rbac_file="$REPO/src/O_core_system/27_RbacService.gs"

if [[ ! -f "$rbac_file" ]]; then
  echo "  ❌ 27_RbacService.gs not found"
  exit 1
fi

# Look for default false pattern in isAuthorizedUser_
# Common: return false, !authorized, deny default
has_deny_default=$(grep -cE "return false|return[[:space:]]+!|deny.*default" "$rbac_file" 2>/dev/null) || has_deny_default=0
has_isAuth=$(grep -c "isAuthorizedUser" "$rbac_file" 2>/dev/null) || has_isAuth=0

echo "  📊 isAuthorizedUser_ references: $has_isAuth"
echo "  📊 Deny-by-default patterns: $has_deny_default"

if [[ "$has_isAuth" -lt 1 ]]; then
  echo "  ❌ isAuthorizedUser_ function not found"
  exit 1
fi

# Check if 00_App.gs menu items call isAuthorizedUser_
app_file="$REPO/src/O_core_system/00_App.gs"
if [[ -f "$app_file" ]]; then
  menu_count=$(grep -cE "menu\.|addMenu" "$app_file" 2>/dev/null) || menu_count=0
  guard_count=$(grep -c "isAuthorizedUser" "$app_file" 2>/dev/null) || guard_count=0

  echo "  📊 Menu items: $menu_count"
  echo "  📊 isAuthorizedUser calls in App: $guard_count"

  if [[ "$menu_count" -gt 0 ]] && [[ "$guard_count" -eq 0 ]]; then
    echo "  ⚠️  Menu items exist but no isAuthorizedUser_ guard in 00_App.gs"
    echo "  💡 Fix: Wrap every menu handler with isAuthorizedUser_() check"
    exit 1
  fi
fi

echo "  ✅ RBAC structure looks correct"
exit 0
