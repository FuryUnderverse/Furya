#!/bin/bash
set -ux

# always returns true so set -e doesn't exit if it is not running.
killall furyd || true
rm -rf $HOME/.furyd/
killall screen

# make four fury directories
mkdir $HOME/.furyd
mkdir $HOME/.furyd/validator1
mkdir $HOME/.furyd/validator2
mkdir $HOME/.furyd/validator3

# init all three validators
furyd init --chain-id=testing validator1 --home=$HOME/.furyd/validator1
furyd init --chain-id=testing validator2 --home=$HOME/.furyd/validator2
furyd init --chain-id=testing validator3 --home=$HOME/.furyd/validator3

# create keys for all three validators
furyd keys add validator1 --keyring-backend=test --home=$HOME/.furyd/validator1
furyd keys add validator2 --keyring-backend=test --home=$HOME/.furyd/validator2
furyd keys add validator3 --keyring-backend=test --home=$HOME/.furyd/validator3

update_genesis () {    
    cat $HOME/.furyd/validator1/config/genesis.json | jq "$1" > $HOME/.furyd/validator1/config/tmp_genesis.json && mv $HOME/.furyd/validator1/config/tmp_genesis.json $HOME/.furyd/validator1/config/genesis.json
}

# change staking denom to fury
update_genesis '.app_state["staking"]["params"]["bond_denom"]="fury"'

# create validator node 1
furyd add-genesis-account $(furyd keys show validator1 -a --keyring-backend=test --home=$HOME/.furyd/validator1) 1000000000000fury,1000000000000stake --home=$HOME/.furyd/validator1
furyd gentx validator1 500000000fury --keyring-backend=test --home=$HOME/.furyd/validator1 --chain-id=testing
furyd collect-gentxs --home=$HOME/.furyd/validator1
furyd validate-genesis --home=$HOME/.furyd/validator1

# update staking genesis
update_genesis '.app_state["staking"]["params"]["unbonding_time"]="240s"'

# update crisis variable to fury
update_genesis '.app_state["crisis"]["constant_fee"]["denom"]="fury"'

# udpate gov genesis
update_genesis '.app_state["gov"]["voting_params"]["voting_period"]="60s"'
update_genesis '.app_state["gov"]["deposit_params"]["min_deposit"][0]["denom"]="fury"'

# update mint genesis
update_genesis '.app_state["mint"]["params"]["mint_denom"]="fury"'

# port key (validator1 uses default ports)
# validator1 1317, 9090, 9091, 26658, 26657, 26656, 6060
# validator2 1316, 9088, 9089, 26655, 26654, 26653, 6061
# validator3 1315, 9086, 9087, 26652, 26651, 26650, 6062


# change app.toml values
VALIDATOR1_APP_TOML=$HOME/.furyd/validator1/config/app.toml
VALIDATOR2_APP_TOML=$HOME/.furyd/validator2/config/app.toml
VALIDATOR3_APP_TOML=$HOME/.furyd/validator3/config/app.toml

# change config.toml values
VALIDATOR1_CONFIG=$HOME/.furyd/validator1/config/config.toml
VALIDATOR2_CONFIG=$HOME/.furyd/validator2/config/config.toml
VALIDATOR3_CONFIG=$HOME/.furyd/validator3/config/config.toml

# validator2
sed -i -E 's|tcp://0.0.0.0:1317|tcp://0.0.0.0:1316|g' $VALIDATOR2_APP_TOML
sed -i -E 's|0.0.0.0:9090|0.0.0.0:9088|g' $VALIDATOR2_APP_TOML
sed -i -E 's|0.0.0.0:9091|0.0.0.0:9089|g' $VALIDATOR2_APP_TOML

# validator3
sed -i -E 's|tcp://0.0.0.0:1317|tcp://0.0.0.0:1315|g' $VALIDATOR3_APP_TOML
sed -i -E 's|0.0.0.0:9090|0.0.0.0:9086|g' $VALIDATOR3_APP_TOML
sed -i -E 's|0.0.0.0:9091|0.0.0.0:9087|g' $VALIDATOR3_APP_TOML

# Pruning - comment this configuration if you want to run upgrade script
pruning="custom"
pruning_keep_recent="5"
pruning_keep_every="10"
pruning_interval="10"

sed -i -e "s%^pruning *=.*%pruning = \"$pruning\"%; " $VALIDATOR1_APP_TOML
sed -i -e "s%^pruning-keep-recent *=.*%pruning-keep-recent = \"$pruning_keep_recent\"%; " $VALIDATOR1_APP_TOML
sed -i -e "s%^pruning-keep-every *=.*%pruning-keep-every = \"$pruning_keep_every\"%; " $VALIDATOR1_APP_TOML
sed -i -e "s%^pruning-interval *=.*%pruning-interval = \"$pruning_interval\"%; " $VALIDATOR1_APP_TOML

sed -i -e "s%^pruning *=.*%pruning = \"$pruning\"%; " $VALIDATOR2_APP_TOML
sed -i -e "s%^pruning-keep-recent *=.*%pruning-keep-recent = \"$pruning_keep_recent\"%; " $VALIDATOR2_APP_TOML
sed -i -e "s%^pruning-keep-every *=.*%pruning-keep-every = \"$pruning_keep_every\"%; " $VALIDATOR2_APP_TOML
sed -i -e "s%^pruning-interval *=.*%pruning-interval = \"$pruning_interval\"%; " $VALIDATOR2_APP_TOML

sed -i -e "s%^pruning *=.*%pruning = \"$pruning\"%; " $VALIDATOR3_APP_TOML
sed -i -e "s%^pruning-keep-recent *=.*%pruning-keep-recent = \"$pruning_keep_recent\"%; " $VALIDATOR3_APP_TOML
sed -i -e "s%^pruning-keep-every *=.*%pruning-keep-every = \"$pruning_keep_every\"%; " $VALIDATOR3_APP_TOML
sed -i -e "s%^pruning-interval *=.*%pruning-interval = \"$pruning_interval\"%; " $VALIDATOR3_APP_TOML

# state sync  - comment this configuration if you want to run upgrade script
snapshot_interval="10"
snapshot_keep_recent="2"

sed -i -e "s%^snapshot-interval *=.*%snapshot-interval = \"$snapshot_interval\"%; " $VALIDATOR1_APP_TOML
sed -i -e "s%^snapshot-keep-recent *=.*%snapshot-keep-recent = \"$snapshot_keep_recent\"%; " $VALIDATOR1_APP_TOML

sed -i -e "s%^snapshot-interval *=.*%snapshot-interval = \"$snapshot_interval\"%; " $VALIDATOR2_APP_TOML
sed -i -e "s%^snapshot-keep-recent *=.*%snapshot-keep-recent = \"$snapshot_keep_recent\"%; " $VALIDATOR2_APP_TOML

sed -i -e "s%^snapshot-interval *=.*%snapshot-interval = \"$snapshot_interval\"%; " $VALIDATOR3_APP_TOML
sed -i -e "s%^snapshot-keep-recent *=.*%snapshot-keep-recent = \"$snapshot_keep_recent\"%; " $VALIDATOR3_APP_TOML

# validator1
sed -i -E 's|allow_duplicate_ip = false|allow_duplicate_ip = true|g' $VALIDATOR1_CONFIG

# validator2
sed -i -E 's|tcp://127.0.0.1:26658|tcp://0.0.0.0:26655|g' $VALIDATOR2_CONFIG
sed -i -E 's|tcp://127.0.0.1:26657|tcp://0.0.0.0:26654|g' $VALIDATOR2_CONFIG
sed -i -E 's|tcp://0.0.0.0:26656|tcp://0.0.0.0:26653|g' $VALIDATOR2_CONFIG
sed -i -E 's|tcp://0.0.0.0:26656|tcp://0.0.0.0:26650|g' $VALIDATOR2_CONFIG
sed -i -E 's|allow_duplicate_ip = false|allow_duplicate_ip = true|g' $VALIDATOR2_CONFIG

# validator3
sed -i -E 's|tcp://127.0.0.1:26658|tcp://0.0.0.0:26652|g' $VALIDATOR3_CONFIG
sed -i -E 's|tcp://127.0.0.1:26657|tcp://0.0.0.0:26651|g' $VALIDATOR3_CONFIG
sed -i -E 's|tcp://0.0.0.0:26656|tcp://0.0.0.0:26650|g' $VALIDATOR3_CONFIG
sed -i -E 's|tcp://0.0.0.0:26656|tcp://0.0.0.0:26650|g' $VALIDATOR3_CONFIG
sed -i -E 's|allow_duplicate_ip = false|allow_duplicate_ip = true|g' $VALIDATOR3_CONFIG

# copy validator1 genesis file to validator2-3
cp $HOME/.furyd/validator1/config/genesis.json $HOME/.furyd/validator2/config/genesis.json
cp $HOME/.furyd/validator1/config/genesis.json $HOME/.furyd/validator3/config/genesis.json

# copy tendermint node id of validator1 to persistent peers of validator2-3
sed -i -E "s|persistent_peers = \"\"|persistent_peers = \"$(furyd tendermint show-node-id --home=$HOME/.furyd/validator1)@localhost:26656\"|g" $VALIDATOR2_CONFIG
sed -i -E "s|persistent_peers = \"\"|persistent_peers = \"$(furyd tendermint show-node-id --home=$HOME/.furyd/validator1)@localhost:26656\"|g" $VALIDATOR3_CONFIG

# start all three validators
screen -S validator1 -d -m furyd start --home=$HOME/.furyd/validator1 --minimum-gas-prices=0.00001fury
screen -S validator2 -d -m furyd start --home=$HOME/.furyd/validator2 --minimum-gas-prices=0.00001fury
screen -S validator3 -d -m furyd start --home=$HOME/.furyd/validator3 --minimum-gas-prices=0.00001fury

# send fury from first validator to second validator
echo "Waiting 7 seconds to send funds to validators 2 and 3..."
sleep 7

furyd tx send $(furyd keys show validator1 -a --keyring-backend=test --home=$HOME/.furyd/validator1) $(furyd keys show validator2 -a --keyring-backend=test --home=$HOME/.furyd/validator2) 5000000000fury --keyring-backend=test --home=$HOME/.furyd/validator1 --chain-id=testing --broadcast-mode block --gas 200000 --fees 2fury --node http://localhost:26657 --yes
furyd tx send $(furyd keys show validator1 -a --keyring-backend=test --home=$HOME/.furyd/validator1) $(furyd keys show validator3 -a --keyring-backend=test --home=$HOME/.furyd/validator3) 4000000000fury --keyring-backend=test --home=$HOME/.furyd/validator1 --chain-id=testing --broadcast-mode block --gas 200000 --fees 2fury --node http://localhost:26657 --yes

# create second & third validator
furyd tx staking create-validator --amount=500000000fury --from=validator2 --pubkey=$(furyd tendermint show-validator --home=$HOME/.furyd/validator2) --moniker="validator2" --chain-id="testing" --commission-rate="0.1" --commission-max-rate="0.2" --commission-max-change-rate="0.05" --min-self-delegation="500000000" --keyring-backend=test --home=$HOME/.furyd/validator2 --broadcast-mode block --gas 200000 --fees 2fury --node http://localhost:26657 --yes
furyd tx staking create-validator --amount=400000000fury --from=validator3 --pubkey=$(furyd tendermint show-validator --home=$HOME/.furyd/validator3) --moniker="validator3" --chain-id="testing" --commission-rate="0.1" --commission-max-rate="0.2" --commission-max-change-rate="0.05" --min-self-delegation="400000000" --keyring-backend=test --home=$HOME/.furyd/validator3 --broadcast-mode block --gas 200000 --fees 2fury --node http://localhost:26657 --yes

echo "All 3 Validators are up and running!"

echo "-----------------------"
echo "## Add new CosmWasm contract"
RESP=$(furyd tx wasm store scripts/wasm_file/cw_nameservice-aarch64.wasm \
--from=validator1 --keyring-backend=test --home=$HOME/.furyd/validator1 --gas 1500000 --fees 150fury --chain-id="testing" -y --node=http://localhost:26657 -b block -o json)

# first contract with code id = 1
CODE_ID=$(echo "$RESP" | jq -r '.logs[0].events[1].attributes[-1].value')
CODE_HASH=$(echo "$RESP" | jq -r '.logs[0].events[1].attributes[-2].value')
echo "* Code id: $CODE_ID"
echo "* Code checksum: $CODE_HASH"

echo "-----------------------"
echo "## Migrate contract"
echo "### Upload new code"
RESP=$(furyd tx wasm store scripts/wasm_file/burner.wasm \
  --from=validator1 --keyring-backend=test --home=$HOME/.furyd/validator1 --node=http://localhost:26657 --gas 1500000 --fees 150fury --chain-id="testing" -y -b block -o json)

# second contract with code id = 2
CODE_ID=$(echo "$RESP" | jq -r '.logs[0].events[1].attributes[-1].value')
CODE_HASH=$(echo "$RESP" | jq -r '.logs[0].events[1].attributes[-2].value')
echo "* Code id: $CODE_ID"
echo "* Code checksum: $CODE_HASH"