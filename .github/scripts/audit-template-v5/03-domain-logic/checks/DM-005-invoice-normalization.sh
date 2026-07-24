#!/usr/bin/env bash
# DM-005 — Invoice normalization (Law 21)
# ตรวจว่า invoice number ถูก normalize ก่อน compare/write/hash
# เพราะ Google Sheets แปลง INV2024070100123 → 2.02407E+12 (scientific notation)
#
# Returns: 0 = pass, 1 = fail

set -uo pipefail
REPO="${1:-.}"

echo "📋 DM-005: Invoice number normalization (Law 21)"

# Find all string literals that look like invoice numbers
# Pattern: INV, BILL, INV-XXX, INVXXX, INV20YY
# Then check if function that contains them also has normalizeInvoiceNo_ call

invoice_pattern='["\x27]?(INV|BILL|RECPT)[-_]?[0-9]{8,}'

# Heuristic: scan functions that touch INVOICE column index
violations=0
while IFS= read -r gsfile; do
  if ! grep -qE "$invoice_pattern" "$gsfile"; then continue; fi

  # If file has invoice pattern but never calls normalizeInvoiceNo_, warn
  if ! grep -q "normalizeInvoiceNo" "$gsfile"; then
    echo "  ⚠️  ${gsfile#$REPO/} — has invoice-like literals but no normalizeInvoiceNo_()"
    grep -nE "$invoice_pattern" "$gsfile" | head -3 | sed 's/^/      /'
    violations=$((violations + 1))
  fi
done < <(find "$REPO/src" -name "*.gs" 2>/dev/null)

if [[ "$violations" -eq 0 ]]; then
  echo "  ✅ All invoice handling uses normalizeInvoiceNo_()"
  exit 0
fi

echo ""
echo "  💡 Fix: Wrap invoice literals with normalizeInvoiceNo_() from 14_Utils.gs"
exit 1
