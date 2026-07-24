#!/usr/bin/env bash
# run-audit.sh — Main entry point for LMDS V6.0 audit
# Usage: ./run-audit.sh /path/to/lmds-repo [agent]
#
# agent: all (default) | static | runtime | domain

set -uo pipefail

REPO="${1:-.}"
AGENT="${2:-all}"

if [[ ! -d "$REPO" ]]; then
  echo "❌ Repo not found: $REPO"
  echo "Usage: $0 /path/to/lmds-repo [all|static|runtime|domain]"
  exit 1
fi

# Resolve template root
TEMPLATE_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EVIDENCE="$TEMPLATE_ROOT/06-evidence"

mkdir -p "$EVIDENCE"

echo "============================================================"
echo "🔍 LMDS V6.0 — Inspection Audit"
echo "Repo: $REPO"
echo "Agent: $AGENT"
echo "Template: $TEMPLATE_ROOT"
echo "Evidence: $EVIDENCE"
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "============================================================"
echo ""

run_agent() {
  local name="$1"
  local dir="$2"
  local report="$3"

  echo "▶️  Running Agent: $name"
  echo "   Check scripts: $TEMPLATE_ROOT/$dir/checks/*.sh"
  echo ""

  local out="$EVIDENCE/$report"
  {
    echo "# Agent: $name"
    echo "**Date:** $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "**Repo:** $REPO"
    echo ""
    echo "## Raw output from check scripts"
    echo ""
  } > "$out"

  local total=0 pass=0 fail=0 warn=0
  for check in "$TEMPLATE_ROOT/$dir/checks/"*.sh; do
    if [[ ! -f "$check" ]]; then continue; fi
    total=$((total + 1))
    echo "▶️  $(basename "$check")"
    if bash "$check" "$REPO" 2>&1 | tee -a "$out"; then
      pass=$((pass + 1))
    else
      # Exit code != 0 means fail or warning — record as warn
      warn=$((warn + 1))
    fi
    echo "" >> "$out"
  done

  echo ""
  echo "📊 $name: $pass/$total passed, $warn warning/fail"
  echo ""
}

case "$AGENT" in
  static)
    run_agent "Agent 1 (Static)" "01-static" "static-report.md"
    ;;
  runtime)
    run_agent "Agent 2 (Runtime-GAS)" "02-runtime-gas" "runtime-report.md"
    ;;
  domain)
    run_agent "Agent 3 (Domain-Logic)" "03-domain-logic" "domain-report.md"
    ;;
  docsync)
    run_agent "Agent 5 (Doc-Sync)" "05-doc-sync" "docsync-report.md"
    ;;
  all)
    run_agent "Agent 1 (Static)" "01-static" "static-report.md"
    run_agent "Agent 2 (Runtime-GAS)" "02-runtime-gas" "runtime-report.md"
    run_agent "Agent 3 (Domain-Logic)" "03-domain-logic" "domain-report.md"
    run_agent "Agent 5 (Doc-Sync)" "05-doc-sync" "docsync-report.md"

    echo "============================================================"
    echo "✅ 4 Agent ตรวจเสร็จ (Static + Runtime + Domain + Doc-Sync)"
    echo ""
    echo "📁 Evidence files:"
    ls -la "$EVIDENCE"
    echo ""
    echo "👉 ขั้นต่อไป:"
    echo "   1. ตรวจ 06-evidence/static-report.md"
    echo "   2. ตรวจ 06-evidence/runtime-report.md"
    echo "   3. ตรวจ 06-evidence/domain-report.md"
    echo "   4. ตรวจ 06-evidence/docsync-report.md (LMDS existing checks)"
    echo "   5. ส่งทั้ง 4 report ให้ Agent 4 (Aggregator) ตาม 04-aggregator/agent.md"
    echo "   6. ดู final-report.md เมื่อรวมเสร็จ"
    echo "============================================================"
    ;;
  *)
    echo "❌ Unknown agent: $AGENT"
    echo "Use: all | static | runtime | domain | docsync"
    exit 1
    ;;
esac
