#!/usr/bin/env bash
#
# run-ictt-demo.sh — ICTT uçtan uca köprü demosu (yeniden üretilebilir)
#
# Senaryo: Fuji C-Chain'de KGAS lock → icm-relayer → Fuji L1'de wKGAS mint.
# Her iki uç da Fuji primary network'te (yerel↔Fuji ICM ÇALIŞMAZ — ayrı P-Chain).
#
# ÖN KOŞULLAR (bir kez, manuel — bkz. docs/tr/03-templateler/ictt-bridge.md):
#   1) Avalanche CLI v1.9.6+ kurulu (WSL/Linux/macOS).
#   2) Deployer key CLI'a import: `avalanche key create deployer --file <hex-key> --force`
#   3) P-Chain'de AVAX: `avalanche key transfer --fuji --key deployer \
#        --c-chain-sender --p-chain-receiver --amount 2 --destination-key deployer`
#   4) kozaTestL1 genesis airdrop deployer-only + warpConfig.requirePrimaryNetworkSigners=true
#   5) Fuji L1 deploy:
#        avalanche blockchain deploy kozaTestL1 --fuji --use-local-machine \
#          --num-nodes 1 --balance 1 --skip-relayer --key deployer \
#          --vmc-L1 --vmc-key deployer
#   6) .env doldurulmuş: PRIVATE_KEY, KOZALAK_TEST_L1_RPC_URL,
#        REMOTE_TELEPORTER_REGISTRY, REMOTE_TOKEN_HOME_BLOCKCHAIN_ID, REMOTE_TOKEN_HOME_ADDRESS
#
# Bu script ön koşullar sağlandıktan sonra akışı otomatikleştirir:
#   relayer başlat → Remote deploy → register → transfer → mint doğrula.
#
set -euo pipefail

cd "$(dirname "$0")/../.."

# --- .env yükle ---
[ -f .env ] || { echo "HATA: .env yok"; exit 1; }
PRIVATE_KEY=$(grep -E "^PRIVATE_KEY=" .env | cut -d= -f2- | tr -d '\r\n ')
L1_RPC=$(grep -E "^KOZALAK_TEST_L1_RPC_URL=" .env | cut -d= -f2- | tr -d '\r\n ')
REMOTE_REGISTRY=$(grep -E "^REMOTE_TELEPORTER_REGISTRY=" .env | cut -d= -f2- | tr -d '\r\n ')
HOME_BID=$(grep -E "^REMOTE_TOKEN_HOME_BLOCKCHAIN_ID=" .env | cut -d= -f2- | tr -d '\r\n ')
HOME_ADDR=$(grep -E "^REMOTE_TOKEN_HOME_ADDRESS=" .env | cut -d= -f2- | tr -d '\r\n ')

FUJI_RPC="${FUJI_RPC:-https://api.avax-test.network/ext/bc/C/rpc}"
KGAS="0x06451DD4Fb8ebFC19870DacC9568f4364D2A2eB0"
DEPLOYER=$(cast wallet address --private-key "$PRIVATE_KEY")
AMOUNT="10000000000000000000"   # 10 token (18 decimals)
RELAYER_BIN=$(find "$HOME/.avalanche-cli" -name icm-relayer -type f 2>/dev/null | head -1)
RELAYER_CFG="$HOME/.avalanche-cli/runs/Fuji/local-relayer/icm-relayer-config.json"

echo "== ICTT demo =="
echo "  Deployer:    $DEPLOYER"
echo "  Home:        $HOME_ADDR (Fuji C-Chain)"
echo "  L1 RPC:      $L1_RPC"
[ "$(cast chain-id --rpc-url "$L1_RPC")" = "9999" ] || { echo "HATA: L1 RPC erişilemez (kozaTestL1 deploy edilmiş mi?)"; exit 1; }

# --- 1) Relayer'ı kalıcı başlat (zaten çalışmıyorsa) ---
# NOT: relayer deployer key kullanır; bu script çalışırken BAŞKA manuel tx gönderme
#      (nonce çakışması). icm-relayer flag'i --config-file'dır (--config DEĞİL).
if ! pgrep -f "icm-relayer --config-file" >/dev/null; then
  echo "[1/5] Relayer başlatılıyor (nohup, kalıcı)..."
  nohup "$RELAYER_BIN" --config-file "$RELAYER_CFG" > "$HOME/koza-relayer.log" 2>&1 &
  sleep 8
else
  echo "[1/5] Relayer zaten çalışıyor."
fi
pgrep -f "icm-relayer --config-file" >/dev/null || { echo "HATA: relayer başlamadı"; exit 1; }

# --- 2) Remote (wKGAS) deploy (yoksa) — forge create, Warp precompile için ---
REMOTE_ADDR=$(grep -E "^REMOTE_ADDRESS=" .env 2>/dev/null | cut -d= -f2- | tr -d '\r\n ' || true)
if [ -z "${REMOTE_ADDR:-}" ] || [ "$(cast code "$REMOTE_ADDR" --rpc-url "$L1_RPC" 2>/dev/null)" = "0x" ]; then
  echo "[2/5] KozaTokenRemote deploy ediliyor (forge create)..."
  REMOTE_ADDR=$(forge create src/templates/ictt-bridge/KozaTokenRemote.sol:KozaTokenRemote \
    --rpc-url "$L1_RPC" --private-key "$PRIVATE_KEY" --broadcast --evm-version cancun \
    --constructor-args "($REMOTE_REGISTRY,$DEPLOYER,1,$HOME_BID,$HOME_ADDR,18)" \
    "Wrapped Koza Gas" "wKGAS" 18 | grep -oE "Deployed to: 0x[0-9a-fA-F]{40}" | awk '{print $3}')
  echo "  Remote: $REMOTE_ADDR"
  grep -q "^REMOTE_ADDRESS=" .env && sed -i "s|^REMOTE_ADDRESS=.*|REMOTE_ADDRESS=$REMOTE_ADDR|" .env || printf 'REMOTE_ADDRESS=%s\n' "$REMOTE_ADDR" >> .env
else
  echo "[2/5] Remote zaten deploy: $REMOTE_ADDR"
fi

# Remote'un blockchain ID'si (register/transfer destination)
REMOTE_BID=$(cast call "$REMOTE_REGISTRY" "getBlockchainID()(bytes32)" --rpc-url "$L1_RPC" 2>/dev/null || true)
[ -n "$REMOTE_BID" ] || { echo "HATA: Remote blockchain ID alınamadı"; exit 1; }

# --- 3) registerWithHome (relayer Fuji C-Chain'e taşır) ---
echo "[3/5] registerWithHome..."
cast send "$REMOTE_ADDR" "registerWithHome((address,uint256))" \
  "(0x0000000000000000000000000000000000000000,0)" \
  --rpc-url "$L1_RPC" --private-key "$PRIVATE_KEY" --gas-limit 500000 >/dev/null
echo "  Register mesajı yayımlandı, relayer taşıyor (bekleniyor)..."
sleep 25

# --- 4) Transfer: Fuji C-Chain KGAS lock → Home.send ---
echo "[4/5] Transfer: $((AMOUNT / 1000000000000000000)) KGAS lock..."
cast send "$KGAS" "approve(address,uint256)" "$HOME_ADDR" "$AMOUNT" \
  --rpc-url "$FUJI_RPC" --private-key "$PRIVATE_KEY" >/dev/null
cast send "$HOME_ADDR" \
  "send((bytes32,address,address,address,uint256,uint256,uint256,address),uint256)" \
  "($REMOTE_BID,$REMOTE_ADDR,$DEPLOYER,0x0000000000000000000000000000000000000000,0,0,350000,0x0000000000000000000000000000000000000000)" \
  "$AMOUNT" --rpc-url "$FUJI_RPC" --private-key "$PRIVATE_KEY" >/dev/null
echo "  Home.send gönderildi, relayer Fuji L1'e taşıyor..."

# --- 5) wKGAS mint doğrula (başarı kriteri: balanceOf > 0) ---
echo "[5/5] wKGAS mint doğrulanıyor (relayer signature aggregation ~1-2 dk)..."
for i in $(seq 1 60); do
  BAL=$(cast call "$REMOTE_ADDR" "balanceOf(address)(uint256)" "$DEPLOYER" --rpc-url "$L1_RPC" 2>/dev/null | grep -oE "^[0-9]+")
  if [ -n "$BAL" ] && [ "$BAL" != "0" ]; then
    echo ""
    echo "✅ BAŞARILI! Fuji L1'de wKGAS mint edildi:"
    echo "   balanceOf($DEPLOYER) = $BAL wei"
    echo "   totalSupply = $(cast call "$REMOTE_ADDR" "totalSupply()(uint256)" --rpc-url "$L1_RPC" | grep -oE '^[0-9]+')"
    exit 0
  fi
  sleep 3
done
echo "⏳ Mint 180s içinde görülmedi — relayer log: ~/koza-relayer.log"
exit 1
