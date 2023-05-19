#!/bin/sh
set -o errexit -o nounset -o pipefail

echo -n "Enter passphrase:"
read -s PASSWORD

CHAIN_ID=${CHAIN_ID:-Furyunderverse}
USER=${USER:-tupt}
MONIKER=${MONIKER:-node001}
# PASSWORD=${PASSWORD:-$1}
rm -rf .furyd/

furyd init --chain-id "$CHAIN_ID" "$MONIKER"

(echo "$PASSWORD"; echo "$PASSWORD") | furyd keys add $USER

# hardcode the validator account for this instance
(echo "$PASSWORD") | furyd add-genesis-account $USER "100000000000000fury"

# submit a genesis validator tx
## Workraround for https://github.com/cosmos/cosmos-sdk/issues/8251
(echo "$PASSWORD"; echo "$PASSWORD") | furyd gentx $USER "250000000fury" --chain-id="$CHAIN_ID" --amount="250000000fury" -y

furyd collect-gentxs


