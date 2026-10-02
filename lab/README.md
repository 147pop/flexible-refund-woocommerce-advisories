# Reproduction lab

```bash
# 1) fetch the stock plugin from wp.org (not committed here)
mkdir -p plugins && cd plugins
curl -sL https://downloads.wordpress.org/plugin/flexible-refund-and-return-order-for-woocommerce.2.0.3.zip -o fr.zip && unzip -q fr.zip && rm fr.zip
cd ..
# 2) bring up WordPress 7.1.2 + WooCommerce + plugin, provision demo data
docker compose up -d
./setup.sh
# 3) run each PoC (see ../FR-0x/poc/poc.sh); evidence of our runs is in ../FR-0x/evidence/trace.txt
```
Store: http://localhost:8088 · admin/admin123 · customer attacker/pass123.
FR-04 (PRO) is reproduced by setting `is_super=true` at
`plugins/.../src/Plugin.php:61` (`new Integration(true)`); revert afterwards.
