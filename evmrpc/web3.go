package evmrpc

import (
	"fmt"
	"runtime"
)

type Web3API struct{}

func (w *Web3API) ClientVersion() string {
	fmt.Printf("[DEBUG]: calling ClientVersion\n")
	name := "Geth" // Sei EVM is backed by go-ethereum
	name += "/" + runtime.GOOS + "-" + runtime.GOARCH
	name += "/" + runtime.Version()
	return name
}
