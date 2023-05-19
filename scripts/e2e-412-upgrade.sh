#!/bin/bash

# setup the network using the old binary

OLD_VERSION=${OLD_VERSION:-"v0.41.1"}
WASM_PATH=${WASM_PATH:-"../furywasm/package/plus/swapmap/artifacts/swapmap.wasm"}
ARGS="--chain-id testing -y --keyring-backend test --fees 200fury --gas auto --gas-adjustment 1.5 -b block"
NEW_VERSION=${NEW_VERSION:-"v0.41.2"}
VALIDATOR_HOME=${VALIDATOR_HOME:-"$HOME/.furyd/validator1"}
MIGRATE_MSG=${MIGRATE_MSG:-'{}'}

# kill all running binaries
pkill furyd && sleep 2s

# download current production binary
git clone https://github.com/furyunderverse/fury.git && cd fury/ && git checkout $OLD_VERSION && go get ./... && make install && cd ../ && rm -rf fury/

# setup local network
sh $PWD/scripts/multinode-local-testnet.sh

# deploy new contract
store_ret=$(furyd tx wasm store $WASM_PATH --from validator1 --home $VALIDATOR_HOME $ARGS --output json)
code_id=$(echo $store_ret | jq -r '.logs[0].events[1].attributes[] | select(.key | contains("code_id")).value')
furyd tx wasm instantiate $code_id '{}' --label 'testing' --from validator1 --home $VALIDATOR_HOME -b block --admin $(furyd keys show validator1 --keyring-backend test --home $VALIDATOR_HOME -a) $ARGS
contract_address=$(furyd query wasm list-contract-by-code $code_id --output json | jq -r '.contracts[0]')

echo "contract address: $contract_address"

# # create new upgrade proposal
UPGRADE_HEIGHT=${UPGRADE_HEIGHT:-30}
furyd tx gov submit-proposal software-upgrade $NEW_VERSION --title "foobar" --description "foobar"  --from validator1 --upgrade-height $UPGRADE_HEIGHT --upgrade-info "x" --deposit 10000000fury $ARGS --home $VALIDATOR_HOME
furyd tx gov vote 1 yes --from validator1 --home "$HOME/.furyd/validator1" $ARGS && furyd tx gov vote 1 yes --from validator2 --home "$HOME/.furyd/validator2" $ARGS

# sleep to wait til the proposal passes
echo "Sleep til the proposal passes..."
sleep 3m

# kill all processes when lastest height = UPGRADE_HEIGHT - 1 = 29
pkill furyd && sleep 3s

# install new binary for the upgrade
echo "install new binary"
make install

# re-run all validators. All should run
screen -S validator1 -d -m furyd start --home=$HOME/.furyd/validator1 --minimum-gas-prices=0.00001fury
screen -S validator2 -d -m furyd start --home=$HOME/.furyd/validator2 --minimum-gas-prices=0.00001fury
screen -S validator3 -d -m furyd start --home=$HOME/.furyd/validator3 --minimum-gas-prices=0.00001fury

# sleep a bit for the network to start 
echo "Sleep to wait for the network to start..."
sleep 7s
# test contract migration
echo "Migrate the contract"
store_ret=$(furyd tx wasm store $WASM_PATH --from validator1 --home $VALIDATOR_HOME $ARGS --output json)
new_code_id=$(echo $store_ret | jq -r '.logs[0].events[1].attributes[] | select(.key | contains("code_id")).value')

furyd tx wasm migrate $contract_address $new_code_id $MIGRATE_MSG --from validator1 $ARGS --home $VALIDATOR_HOME

height_before=$(curl --no-progress-meter http://localhost:1317/blocks/latest | jq '.block.header.height | tonumber')

# sleep for 2 mins to make sure the network is still running
sleep 1m

height_after=$(curl --no-progress-meter http://localhost:1317/blocks/latest | jq '.block.header.height | tonumber')

if [ $height_after -gt $height_before ]
then
echo "Test done"
else
echo "Test failed"
fi