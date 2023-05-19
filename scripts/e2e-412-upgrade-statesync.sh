#!/bin/bash

# setup the network using the old binary

OLD_VERSION=${OLD_VERSION:-"v0.41.1"}
WASM_PATH=${WASM_PATH:-"../furyawasm/package/plus/swapmap/artifacts/swapmap.wasm"}
ARGS="--chain-id testing -y --keyring-backend test --fees 200furya --gas auto --gas-adjustment 1.5 -b block"
NEW_VERSION=${NEW_VERSION:-"v0.41.2"}
VALIDATOR_HOME=${VALIDATOR_HOME:-"$HOME/.furyad/validator1"}
MIGRATE_MSG=${MIGRATE_MSG:-'{}'}
EXECUTE_MSG=${EXECUTE_MSG:-'{"ping":{}}'}
STATE_SYNC_HOME=${STATE_SYNC_HOME:-".furyad/state_sync"}

# kill all running binaries
pkill furyad && sleep 2s

# download current production binary
git clone https://github.com/furyunderverse/furya.git && cd furya/ && git checkout $OLD_VERSION && go get ./... && make install && cd ../ && rm -rf furya/

# setup local network
sh $PWD/scripts/multinode-local-testnet.sh

# deploy new contract
store_ret=$(furyad tx wasm store $WASM_PATH --from validator1 --home $VALIDATOR_HOME $ARGS --output json)
code_id=$(echo $store_ret | jq -r '.logs[0].events[1].attributes[] | select(.key | contains("code_id")).value')
furyad tx wasm instantiate $code_id '{}' --label 'testing' --from validator1 --home $VALIDATOR_HOME -b block --admin $(furyad keys show validator1 --keyring-backend test --home $VALIDATOR_HOME -a) $ARGS
contract_address=$(furyad query wasm list-contract-by-code $code_id --output json | jq -r '.contracts[0]')

echo "contract address: $contract_address"

# # create new upgrade proposal
UPGRADE_HEIGHT=${UPGRADE_HEIGHT:-30}
furyad tx gov submit-proposal software-upgrade $NEW_VERSION --title "foobar" --description "foobar"  --from validator1 --upgrade-height $UPGRADE_HEIGHT --upgrade-info "x" --deposit 10000000furya $ARGS --home $VALIDATOR_HOME
furyad tx gov vote 1 yes --from validator1 --home "$HOME/.furyad/validator1" $ARGS && furyad tx gov vote 1 yes --from validator2 --home "$HOME/.furyad/validator2" $ARGS

# sleep to wait til the proposal passes
echo "Sleep til the proposal passes..."
sleep 3m

# kill all processes when lastest height = UPGRADE_HEIGHT - 1 = 29
pkill furyad && sleep 3s

# install new binary for the upgrade
echo "install new binary"
make install

# re-run all validators. All should run
screen -S validator1 -d -m furyad start --home=$HOME/.furyad/validator1 --minimum-gas-prices=0.00001furya
screen -S validator2 -d -m furyad start --home=$HOME/.furyad/validator2 --minimum-gas-prices=0.00001furya
screen -S validator3 -d -m furyad start --home=$HOME/.furyad/validator3 --minimum-gas-prices=0.00001furya

# sleep a bit for the network to start 
echo "Sleep to wait for the network to start and wait for new snapshot intervals are after the upgrade to take place..."
sleep 1m

# now we setup statesync node
sh $PWD/scripts/state_sync.sh

echo "Sleep 1 min to get statesync done..."
sleep 1m

# add new key so we test sending wasm transaction afters statesync
# create new key
furyad keys add alice --keyring-backend=test --home=$STATE_SYNC_HOME

echo "## Send fund to state sync account"
furyad tx send $(furyad keys show validator1 -a --keyring-backend=test --home=$VALIDATOR_HOME) $(furyad keys show alice -a --keyring-backend=test --home=$STATE_SYNC_HOME) 500000furya --home=$VALIDATOR_HOME --node http://localhost:26657 $ARGS

echo "Sleep 6s to prevent account sequence error"
sleep 6s

# test wasm transaction using statesync node (port 26647)
echo "## Test execute wasm transaction"
furyad tx wasm execute $contract_address $EXECUTE_MSG --from=validator1 --home=$VALIDATOR_HOME --node tcp://localhost:26647 $ARGS