#!/usr/bin/make -f


all: furyvisor test

build:
	go build -mod=readonly -o build/furyvisor ./cmd/furyvisor

test:
	go test -mod=readonly -race ./...

.PHONY: all build test
