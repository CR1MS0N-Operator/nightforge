package main

import (
	"encoding/json"
	"fmt"
	"os"
)

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintln(os.Stderr, "usage: dashboard-ctl <subcommand> [args...]")
		os.Exit(1)
	}
	cmd := os.Args[1]
	args := os.Args[2:]

	var out interface{}
	var err error

	switch cmd {
	case "vm":
		out, err = vmCmd(args)
	case "container":
		out, err = containerCmd(args)
	case "service":
		out, err = serviceCmd(args)
	case "network":
		out, err = networkCmd(args)
	case "c2":
		out, err = c2Cmd(args)
	case "tmux":
		out, err = tmuxCmd(args)
	case "poll":
		out, err = pollAll()
	default:
		fmt.Fprintf(os.Stderr, "unknown subcommand: %s\n", cmd)
		os.Exit(1)
	}

	if err != nil {
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		os.Exit(1)
	}

	b, _ := json.Marshal(out)
	fmt.Println(string(b))
}

func pollAll() (map[string]interface{}, error) {
	vms, _ := vmList()
	containers, _ := containerList()
	services, _ := serviceList()
	network, _ := networkStatus()
	c2, _ := c2List()
	tmux, _ := tmuxList()

	return map[string]interface{}{
		"vms":        vms,
		"containers": containers,
		"services":   services,
		"network":    network,
		"c2":         c2,
		"tmux":       tmux,
	}, nil
}

func okJSON() map[string]bool {
	return map[string]bool{"ok": true}
}