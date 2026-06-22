package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"reflect"
	"strings"
	"text/tabwriter"
)

func main() {
	jsonFlag := flag.Bool("json", false, "Output JSON instead of human-readable text")
	flag.Parse()

	args := flag.Args()
	if len(args) < 1 {
		fmt.Fprintln(os.Stderr, "usage: dashboard-ctl [--json] <subcommand> [args...]")
		os.Exit(1)
	}
	cmd := args[0]
	subArgs := args[1:]

	var out interface{}
	var err error

	switch cmd {
	case "vm":
		out, err = vmCmd(subArgs)
	case "container":
		out, err = containerCmd(subArgs)
	case "service":
		out, err = serviceCmd(subArgs)
	case "network":
		out, err = networkCmd(subArgs)
	case "c2":
		out, err = c2Cmd(subArgs)
	case "tmux":
		out, err = tmuxCmd(subArgs)
	case "poll":
		out, err = pollAll()
	default:
		fmt.Fprintf(os.Stderr, "unknown subcommand: %s\n", cmd)
		os.Exit(1)
	}

	if !isNilValue(out) {
		if *jsonFlag {
			b, merr := json.Marshal(out)
			if merr != nil {
				fmt.Fprintf(os.Stderr, "error marshaling output: %v\n", merr)
				if err != nil {
					fmt.Fprintf(os.Stderr, "error: %v\n", err)
				}
				os.Exit(1)
			}
			fmt.Println(string(b))
		} else {
			renderHuman(out)
		}
	}

	if err != nil {
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		os.Exit(1)
	}
}

func isNilValue(v interface{}) bool {
	if v == nil {
		return true
	}
	rv := reflect.ValueOf(v)
	switch rv.Kind() {
	case reflect.Chan, reflect.Func, reflect.Interface, reflect.Map, reflect.Ptr, reflect.Slice:
		return rv.IsNil()
	}
	return false
}

func pollAll() (map[string]interface{}, error) {
	var parts []string

	vms, err := vmList()
	if err != nil {
		parts = append(parts, fmt.Sprintf("vm: %v", err))
	}
	containers, err := containerList()
	if err != nil {
		parts = append(parts, fmt.Sprintf("container: %v", err))
	}
	services, err := serviceList()
	if err != nil {
		parts = append(parts, fmt.Sprintf("service: %v", err))
	}
	network, err := networkStatus()
	if err != nil {
		parts = append(parts, fmt.Sprintf("network: %v", err))
	}
	c2, err := c2List()
	if err != nil {
		parts = append(parts, fmt.Sprintf("c2: %v", err))
	}
	tmux, err := tmuxList()
	if err != nil {
		parts = append(parts, fmt.Sprintf("tmux: %v", err))
	}

	result := map[string]interface{}{
		"vms":        vms,
		"containers": containers,
		"services":   services,
		"network":    network,
		"c2":         c2,
		"tmux":       tmux,
	}
	if len(parts) > 0 {
		return result, fmt.Errorf("partial failures: %s", strings.Join(parts, "; "))
	}
	return result, nil
}

func okJSON() map[string]bool {
	return map[string]bool{"ok": true}
}

func renderHuman(out interface{}) {
	switch v := out.(type) {
	case nil:
		return
	case []VM:
		if len(v) == 0 {
			fmt.Println("No VMs")
			return
		}
		w := tabwriter.NewWriter(os.Stdout, 0, 0, 2, ' ', 0)
		fmt.Fprintln(w, "NAME\tSTATE\tVCPUS\tMEMORY(MB)")
		for _, x := range v {
			fmt.Fprintf(w, "%s\t%s\t%d\t%d\n", x.Name, x.State, x.VCPUs, x.MemoryMB)
		}
		w.Flush()
	case []Container:
		if len(v) == 0 {
			fmt.Println("No containers")
			return
		}
		w := tabwriter.NewWriter(os.Stdout, 0, 0, 2, ' ', 0)
		fmt.Fprintln(w, "NAME\tSTATUS\tIMAGE\tPORTS")
		for _, x := range v {
			fmt.Fprintf(w, "%s\t%s\t%s\t%s\n", x.Name, x.Status, x.Image, x.Ports)
		}
		w.Flush()
	case []Service:
		if len(v) == 0 {
			fmt.Println("No services")
			return
		}
		w := tabwriter.NewWriter(os.Stdout, 0, 0, 2, ' ', 0)
		fmt.Fprintln(w, "NAME\tTYPE\tSTATUS")
		for _, x := range v {
			fmt.Fprintf(w, "%s\t%s\t%s\n", x.Name, x.Type, x.Status)
		}
		w.Flush()
	case []C2Framework:
		if len(v) == 0 {
			fmt.Println("No C2 frameworks")
			return
		}
		w := tabwriter.NewWriter(os.Stdout, 0, 0, 2, ' ', 0)
		fmt.Fprintln(w, "NAME\tWEB UI\tSTATUS")
		for _, x := range v {
			fmt.Fprintf(w, "%s\t%s\t%s\n", x.Name, x.WebUI, x.Status)
		}
		w.Flush()
	case []TmuxSession:
		if len(v) == 0 {
			fmt.Println("No tmux sessions")
			return
		}
		w := tabwriter.NewWriter(os.Stdout, 0, 0, 2, ' ', 0)
		fmt.Fprintln(w, "SESSION\tWINDOWS\tATTACHED")
		for _, x := range v {
			fmt.Fprintf(w, "%s\t%d\t%v\n", x.Session, x.Windows, x.Attached)
		}
		w.Flush()
	case NetworkStatus:
		renderNetworkStatus(v)
	case map[string]interface{}:
		for _, key := range []string{"vms", "containers", "services", "network", "c2", "tmux"} {
			if val, ok := v[key]; ok {
				fmt.Printf("\n== %s ==\n", strings.ToUpper(key))
				renderHuman(val)
			}
		}
	case map[string]bool:
		if v["ok"] {
			fmt.Println("ok")
		} else {
			fmt.Println("not ok")
		}
	default:
		b, merr := json.MarshalIndent(out, "", "  ")
		if merr != nil {
			fmt.Fprintf(os.Stderr, "error formatting output: %v\n", merr)
			return
		}
		fmt.Println(string(b))
	}
}

func renderNetworkStatus(n NetworkStatus) {
	if len(n.WG) == 0 {
		fmt.Println("WireGuard: no tunnels")
	} else {
		fmt.Println("WireGuard:")
		for _, t := range n.WG {
			fmt.Printf("  %s (%s) %s\n", t.Name, t.Status, t.IP)
			for _, p := range t.Peers {
				fmt.Printf("    %s connected=%v handshake=%s\n", p.Name, p.Connected, p.LatestHandshake)
			}
		}
	}
	fmt.Printf("Nftables: enabled=%v rules=%d\n", n.Nftables.Enabled, n.Nftables.RulesCount)
	fmt.Printf("WiFi: ssid=%s strength=%d connected=%v\n", n.Wifi.SSID, n.Wifi.Strength, n.Wifi.Connected)
	fmt.Printf("Ethernet: ip=%s up=%v\n", n.Ethernet.IP, n.Ethernet.Up)
	fmt.Printf("DNS: %s\n", n.DNS)
}