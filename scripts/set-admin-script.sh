#!/bin/sh

PASS=${PASS:-12345678}

(echo "$PASS") |furyad tx gov submit-proposal set-contract-admin furya1qxxlalvsdjd07p07y3rc5fu6ll8k4tmet0g6yh furya18hr8jggl3xnrutfujy2jwpeu0l76azprlvgrwt --title "update contract admin" --description "description" --from $USER --chain-id $CHAIN_ID -y && (echo "$PASS") | furyad tx gov vote 4 yes --from $USER --chain-id $CHAIN_ID -y