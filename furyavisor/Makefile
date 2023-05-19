#!/usr/bin/make -f


all: furyavisor test

build:
	go build -mod=readonly -o build/furyavisor ./cmd/furyavisor

test:
	go test -mod=readonly -race ./...

.PHONY: all build test
