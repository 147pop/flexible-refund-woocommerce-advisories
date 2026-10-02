# Security advisories — Flexible Refund and Return Order for WooCommerce (WP Desk)

Independent security research. Four vulnerabilities in the WordPress plugin **Flexible Refund and
Return Order for WooCommerce** by WP Desk, verified against the current wp.org release.

- **Researcher:** 147pop
- **Contact:** GitHub: https://github.com/147pop
- **Vendor:** WP Desk (notified 2026-10-02)
- **Disclosure:** coordinated; CVE assignment requested via VulDB (CNA)
- **Lab:** WordPress 7.1.2 · WooCommerce 11.1.2 · Flexible Refund 2.0.3 (free) — reproducible Docker lab

| ID | Advisory | Class (CWE) | Privileges | CVSS 3.1 |
|----|----------|-------------|------------|----------|
| FR-01 | [IDOR — create refund request on others' orders](FR-01-idor-create-refund-request/) | Broken Access Control (862) | Customer | 4.3 |
| FR-02 | [CSRF — force approved refund](FR-02-csrf-create-refund/) | CSRF (352) | Unauth (victim=admin) | 6.5 |
| FR-03 | [Refund request on cancelled/refunded/trashed order](FR-03-missing-status-check/) | Incorrect Authorization (863) | Customer | 4.3 |
| FR-04 | [PRO — unauth cancel any refund request](FR-04-pro-unauth-cancel/) | Missing Authorization (862) | Unauthenticated | 6.5 |

Each folder contains: `README.md` (the advisory + PoC), `evidence/trace.txt` (real HTTP
request/response + database before/after from the lab), and `poc/` (concise, parameterized PoC).

## Reproducing

All findings reproduce in a Docker lab (WordPress + WooCommerce + the stock plugin from wp.org).
Set up and run:

```bash
cd lab
# fetch the stock plugin, then:
docker compose up -d && ./setup.sh
# run the PoC for each finding: ../FR-0x/poc/poc.sh
```

See [`lab/README.md`](lab/README.md) for the full steps. Each finding's `evidence/trace.txt`
records the exact HTTP request/response and database state change from our own run.

## Timeline

- **2026-10-02** — findings discovered and verified
- **2026-10-02** — vendor (WP Desk) notified
- **[pending]** — VulDB submission + CVE request
- **[pending]** — public disclosure / CVE published

## Disclaimer

Published for defensive and coordinated-disclosure purposes. Use only against systems you own or
are authorized to test.
