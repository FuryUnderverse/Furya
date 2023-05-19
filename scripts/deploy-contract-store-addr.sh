#!/bin/sh
set -o errexit -o nounset -o pipefail

contract_path=$1
label=$2
init=${3:-{\}}
code_id=${5:-}
CHAIN_ID=${CHAIN_ID:-Furyunderverse}
PASSPHRASE=${4:-123456789}

if [ -z $code_id ]
then 
    store_ret=$(echo $PASSPHRASE | furyad tx wasm store $contract_path --from $USER --gas="auto" --gas-adjustment="1.2" --chain-id=$CHAIN_ID -y)
    echo $store_ret
    code_id=$(echo $store_ret | jq -r '.logs[0].events[0].attributes[] | select(.key | contains("code_id")).value')
fi 

echo "init value: $init"

# echo "furyad tx wasm instantiate $code_id '$init' --from $USER --label '$label' --gas auto --gas-adjustment 1.2 --chain-id=$CHAIN_ID -y"
# quote string with "" with escape content inside which contains " characters
(echo $PASSPHRASE;echo $PASSPHRASE) | furyad tx wasm instantiate $code_id "$init" --from $USER --label "$label" --gas auto --gas-adjustment 1.2 --chain-id=$CHAIN_ID -y
contract_address=$(furyad query wasm list-contract-by-code $code_id | grep address | awk '{print $(NF)}')

echo "$contract_address" 2>&1 | tee ../address.txt
