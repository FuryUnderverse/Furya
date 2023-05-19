#!/bin/sh

if test -n "$1"; then
    # need -R not -r to copy hidden files
    cp -R "$1/.furyd" /root
fi

mkdir -p /root/log
furyd start --rpc.laddr tcp://0.0.0.0:26657 --log_level error
