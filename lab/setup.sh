#!/usr/bin/env bash
# Provision the FR/ShopMagic CVE lab from a fresh `docker compose up -d`.
# Idempotent-ish: safe to re-run; recreates demo data.
set -euo pipefail
cd "$(dirname "$0")"
B=http://localhost:8088
dc(){ docker compose exec -T cli wp "$@"; }

echo "[*] waiting for WP http..."
for i in $(seq 1 40); do c=$(curl -s -o /dev/null -w "%{http_code}" "$B/" || true); [ "$c" = "200" ] || [ "$c" = "302" ] && break; sleep 3; done

if ! dc core is-installed 2>/dev/null; then
  dc core install --url="$B" --title="FR Lab" --admin_user=admin --admin_password=admin123 --admin_email=admin@lab.test --skip-email
fi
dc rewrite structure '/%postname%/' --hard >/dev/null
dc plugin is-installed woocommerce 2>/dev/null || dc plugin install woocommerce
dc plugin activate woocommerce flexible-refund-and-return-order-for-woocommerce shopmagic-for-woocommerce >/dev/null
dc rewrite flush --hard >/dev/null

dc option update woocommerce_default_country "US:CA" >/dev/null
dc option update woocommerce_currency "USD" >/dev/null
dc wc payment_gateway update cod --enabled=true --user=admin >/dev/null 2>&1 || true

# enable default refund form (id=1)
dc db query "UPDATE wp_fr_forms SET enabled=1 WHERE id=1;" >/dev/null

# attacker customer (uid likely 2)
dc user get attacker >/dev/null 2>&1 || dc user create attacker attacker@lab.test --role=customer --user_pass=pass123 >/dev/null
AID=$(dc user get attacker --field=ID)

# product
PID=$(dc wc product create --name="Widget" --type=simple --regular_price=10 --user=admin --porcelain 2>/dev/null | tail -1)

mkorder(){ dc wc shop_order create --user=admin --customer_id=$1 --status=$3 \
  --billing="{\"first_name\":\"T\",\"last_name\":\"T\",\"email\":\"$2\",\"address_1\":\"1 St\",\"city\":\"LA\",\"state\":\"CA\",\"postcode\":\"90001\",\"country\":\"US\",\"phone\":\"1\"}" \
  --line_items="[{\"product_id\":$PID,\"quantity\":1}]" --payment_method=cod --porcelain 2>/dev/null | tail -1; }

OA=$(mkorder $AID attacker@lab.test completed)   # attacker-owned, refundable
OV=$(mkorder 0    victim@lab.test   completed)   # guest victim
OC=$(mkorder $AID attacker@lab.test cancelled)   # attacker-owned, cancelled (B3)

# ShopMagic lists (E2)
LA=$(dc post create --post_type=shopmagic_list --post_status=publish --post_title="Public Newsletter" --porcelain | tail -1)
LB=$(dc post create --post_type=shopmagic_list --post_status=publish --post_title="VIP Internal"      --porcelain | tail -1)

cat > .lab_ids.env <<VARS
AID=$AID
PID=$PID
OA=$OA
OV=$OV
OC=$OC
LA=$LA
LB=$LB
VARS
echo "[+] provisioned: attacker=$AID product=$PID orders(own=$OA victim=$OV cancelled=$OC) lists(pub=$LA vip=$LB)"
echo "[+] versions: WP=$(dc core version) Woo=$(dc plugin get woocommerce --field=version) FR=$(dc plugin get flexible-refund-and-return-order-for-woocommerce --field=version) SM=$(dc plugin get shopmagic-for-woocommerce --field=version)"
