#!/bin/bash
set -o errexit -o nounset -o pipefail -x

echo "-----------------------"
echo "## Add new wallet to state sync node"
furyd keys add wallet --keyring-backend=test --home=.furyd/state_sync
furyd keys add alice --keyring-backend=test --home=.furyd/state_sync
furyd keys add bob --keyring-backend=test --home=.furyd/state_sync

echo "-----------------------"
echo "## Send fund to state sync account"
furyd tx send $(furyd keys show validator1 -a --keyring-backend=test --home=$HOME/.furyd/validator1) $(furyd keys show wallet -a --keyring-backend=test --home=.furyd/state_sync) 500000fury --keyring-backend=test --home=$HOME/.furyd/validator1 --chain-id=testing --broadcast-mode block --gas 200000 --fees 2fury --node http://localhost:26657 --yes

furyd tx send $(furyd keys show validator1 -a --keyring-backend=test --home=$HOME/.furyd/validator1) $(furyd keys show alice -a --keyring-backend=test --home=.furyd/state_sync) 500000fury --keyring-backend=test --home=$HOME/.furyd/validator1 --chain-id=testing --broadcast-mode block --gas 200000 --fees 2fury --node http://localhost:26657 --yes

furyd tx send $(furyd keys show validator1 -a --keyring-backend=test --home=$HOME/.furyd/validator1) $(furyd keys show bob -a --keyring-backend=test --home=.furyd/state_sync) 500000fury --keyring-backend=test --home=$HOME/.furyd/validator1 --chain-id=testing --broadcast-mode block --gas 200000 --fees 2fury --node http://localhost:26657 --yes

echo "-----------------------"
echo "## Create new contract instance"
INIT='{"purchase_price":{"amount":"100","denom":"fury"},"transfer_price":{"amount":"999","denom":"fury"}}'
TXFLAG=${TX_FLAG:-"--node tcp://localhost:26647 --chain-id=testing --gas-prices 0.0001fury --gas auto --gas-adjustment 1.3 -b block"}

# Instantiate the first contract. This contract was deploy in multinode-local-testnet.sh script
furyd tx wasm instantiate 1 "$INIT" --from=wallet --admin="$(furyd keys show wallet -a --keyring-backend=test --home=.furyd/state_sync)" --keyring-backend=test --home=.furyd/state_sync --label "name service" $TXFLAG -y

CONTRACT=$(furyd query wasm list-contract-by-code 1 -o json | jq -r '.contracts[-1]')
echo "* Contract address: $CONTRACT"

echo "### Query all"
RESP=$(furyd query wasm contract-state all "$CONTRACT" -o json)
echo "$RESP" | jq

# Excecute the first contract.
# Register a name for the wallet's address
echo "-----------------------"
echo "## Execute contract $CONTRACT"
REGISTER='{"register":{"name":"tony"}}'
furyd tx wasm execute $CONTRACT "$REGISTER" --amount 100fury --from=wallet --keyring-backend=test --home=.furyd/state_sync $TXFLAG -y -b block -o json | jq

# Query the first contract.
# Query the owner of the name record
NAME_QUERY='{"resolve_record": {"name": "tony"}}'
furyd query wasm contract-state smart $CONTRACT "$NAME_QUERY" --node "tcp://localhost:26647" --output json
# Owner is the wallet's address

# Excecute the first contract.
# Transfer the ownership of the name record to bob (change the "to" address to bob generated during environment setup)
# get alice's address
ALICE_ADDRESS=$(furyd keys show alice -a --keyring-backend=test --home=.furyd/state_sync)
TRANSFER={'"transfer"':{'"name"':'"tony"','"to"':\"$ALICE_ADDRESS\"}}
furyd tx wasm execute $CONTRACT $TRANSFER --amount 999fury --from=wallet --gas 1500000 --keyring-backend=test --home=.furyd/state_sync $TXFLAG -y

# Query the first contract.
# Query the record owner again to see the new owner address:
NAME_QUERY='{"resolve_record": {"name": "tony"}}'
furyd query wasm contract-state smart $CONTRACT "$NAME_QUERY" --node "tcp://localhost:26647" --output json
# Owner is the alice's address

# Set new first contract admin.
echo "-----------------------"
echo "## Set new admin"
echo "### Query old admin: $(furyd q wasm contract "$CONTRACT" -o json | jq -r '.contract_info.admin')"
echo "### Update contract"
furyd tx wasm set-contract-admin "$CONTRACT" "$(furyd keys show bob -a --keyring-backend=test --home=.furyd/state_sync)" \
  --from wallet -y --keyring-backend=test --home=.furyd/state_sync --chain-id=testing --gas 200000 --fees 2fury -b block -o json | jq
echo "### Query new admin: $(furyd q wasm contract "$CONTRACT" -o json | jq -r '.contract_info.admin')"

# Migrate the second contract. This contract was deploy in multinode-local-testnet.sh script
DEST_ACCOUNT=$(furyd keys show bob -a --keyring-backend=test --home=.furyd/state_sync)
furyd tx wasm migrate "$CONTRACT" 2 "{\"payout\": \"$DEST_ACCOUNT\"}" --from bob \
  --chain-id=testing --keyring-backend=test --home=.furyd/state_sync --gas 1500000 --fees 150fury -b block -y -o json | jq

# balances of bob: 500000 + 100 + 999 - 150 = 500949
echo "### Query destination account: 2"
furyd q bank balances "$DEST_ACCOUNT" -o json | jq

echo "### Query contract meta data: $CONTRACT"
furyd q wasm contract "$CONTRACT" -o json | jq

echo "### Query contract meta history: $CONTRACT"
furyd q wasm contract-history "$CONTRACT" -o json | jq
