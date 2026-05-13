package main

import (
	"fmt"
	"os/exec"
	"strings"
)

type WGPeer struct {
	Name            string `json:"name"`
	Connected       bool   `json:"connected"`
	LatestHandshake string `json:"latest_handshake"`
}

type WGTunnel struct {
	Name   string    `json:"name"`
	Status string    `json:"status"`
	IP     string    `json:"ip"`
	Peers  []WGPeer `json:"peers"`
}

type NftablesStatus struct {
	Enabled    bool `json:"enabled"`
	RulesCount int  `json:"rules_count"`
}

type WifiStatus struct {
	SSID     string `json:"ssid"`
	Strength int    `json:"strength"`
	Connected bool   `json:"connected"`
}

type EthernetStatus struct {
	IP  string `json:"ip"`
	Up  bool   `json:"up"`
}

type NetworkStatus struct {
	WG        []WGTunnel       `json:"wg"`
	Nftables  NftablesStatus   `json:"nftables"`
	Wifi      WifiStatus       `json:"wifi"`
	Ethernet  EthernetStatus   `json:"ethernet"`
	DNS       string           `json:"dns"`
}

func networkCmd(args []string) (interface{}, error) {
	if len(args) < 1 {
		return nil, fmt.Errorf("usage: dashboard-ctl network <status|wgUp|wgDown|nftablesEnable|nftablesDisable> [args...]")
	}
	switch args[0] {
	case "status":
		return networkStatus()
	case "wgUp":
		if len(args) < 2 {
			return nil, fmt.Errorf("usage: dashboard-ctl network wgUp <name>")
		}
		return wgUp(args[1])
	case "wgDown":
		if len(args) < 2 {
			return nil, fmt.Errorf("usage: dashboard-ctl network wgDown <name>")
		}
		return wgDown(args[1])
	case "nftablesEnable":
		return nftablesEnable()
	case "nftablesDisable":
		return nftablesDisable()
	default:
		return nil, fmt.Errorf("unknown network action: %s", args[0])
	}
}

func networkStatus() (NetworkStatus, error) {
	wg := wgList()
	nf := nftablesCheck()
	wifi := wifiCheck()
	eth := ethernetCheck()
	dns := dnsCheck()

	return NetworkStatus{
		WG:        wg,
		Nftables:  nf,
		Wifi:      wifi,
		Ethernet:  eth,
		DNS:       dns,
	}, nil
}

func wgList() []WGTunnel {
	out, err := exec.Command("sudo", "wg", "show", "interfaces").Output()
	if err != nil {
		return []WGTunnel{}
	}

	ifaceStr := strings.TrimSpace(string(out))
	if ifaceStr == "" {
		return []WGTunnel{}
	}

	ifaces := strings.Fields(ifaceStr)
	var tunnels []WGTunnel
	for _, iface := range ifaces {
		tunnel := parseWGInterface(iface)
		tunnels = append(tunnels, tunnel)
	}
	if len(tunnels) == 0 {
		return []WGTunnel{}
	}
	return tunnels
}

func parseWGInterface(iface string) WGTunnel {
	tunnel := WGTunnel{
		Name:   iface,
		Status: "up",
	}

	out, err := exec.Command("sudo", "wg", "show", iface).Output()
	if err != nil {
		return tunnel
	}

	lines := strings.Split(string(out), "\n")
	var currentPeer string
	var peers []WGPeer

	for _, line := range lines {
		line = strings.TrimSpace(line)
		if strings.HasPrefix(line, "peer: ") {
			currentPeer = strings.TrimPrefix(line, "peer: ")
			peers = append(peers, WGPeer{Name: currentPeer, Connected: false})
		}
		if strings.HasPrefix(line, "latest handshake: ") && currentPeer != "" {
			hs := strings.TrimPrefix(line, "latest handshake: ")
			if hs != "" {
				for i := range peers {
					if peers[i].Name == currentPeer {
						peers[i].Connected = true
						peers[i].LatestHandshake = hs
					}
				}
			}
		}
	}
	if len(peers) == 0 {
		tunnel.Peers = []WGPeer{}
	} else {
		tunnel.Peers = peers
	}
	return tunnel
}

func nftablesCheck() NftablesStatus {
	ns := NftablesStatus{}
	err := exec.Command("sudo", "nft", "list", "ruleset").Run()
	if err != nil {
		ns.Enabled = false
		return ns
	}
	ns.Enabled = true

	out, err := exec.Command("sudo", "nft", "-a", "list", "ruleset").Output()
	if err != nil {
		return ns
	}
	ns.RulesCount = strings.Count(string(out), "handle ")
	return ns
}

func wifiCheck() WifiStatus {
	ws := WifiStatus{}
	out, err := exec.Command("nmcli", "-t", "-f", "ACTIVE,SSID,SIGNAL", "device", "wifi", "list").Output()
	if err != nil {
		return ws
	}

	for _, line := range strings.Split(string(out), "\n") {
		line = strings.TrimSpace(line)
		if strings.HasPrefix(line, "yes:") {
			parts := strings.SplitN(line, ":", 3)
			if len(parts) >= 3 {
				ws.Connected = true
				ws.SSID = parts[1]
				fmt.Sscanf(parts[2], "%d", &ws.Strength)
			}
			break
		}
	}
	return ws
}

func ethernetCheck() EthernetStatus {
	es := EthernetStatus{}
	out, err := exec.Command("ip", "-4", "-br", "addr", "show", "scope", "global").Output()
	if err != nil {
		return es
	}

	wirelessPrefixes := []string{"wl", "wlan"}
	lines := strings.Split(string(out), "\n")
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}
		fields := strings.Fields(line)
		if len(fields) < 3 {
			continue
		}
		iface := fields[0]
		isWireless := false
		for _, p := range wirelessPrefixes {
			if strings.HasPrefix(iface, p) {
				isWireless = true
				break
			}
		}
		if isWireless {
			continue
		}
		state := fields[1]
		ipField := fields[2]
		ip := strings.SplitN(ipField, "/", 2)[0]
		es.Up = state == "UP"
		es.IP = ip
		break
	}
	return es
}

func dnsCheck() string {
	out, err := exec.Command("resolvectl", "dns").Output()
	if err != nil {
		return "system default"
	}

	for _, line := range strings.Split(string(out), "\n") {
		line = strings.TrimSpace(line)
		if line != "" && !strings.HasPrefix(line, "Link") && !strings.HasPrefix(line, "Global") {
			return line
		}
	}
	return "system default"
}

func wgUp(name string) (interface{}, error) {
	err := exec.Command("sudo", "wg-quick", "up", name).Run()
	if err != nil {
		return nil, err
	}
	return okJSON(), nil
}

func wgDown(name string) (interface{}, error) {
	err := exec.Command("sudo", "wg-quick", "down", name).Run()
	if err != nil {
		return nil, err
	}
	return okJSON(), nil
}

func nftablesEnable() (interface{}, error) {
	out, err := exec.Command("cat", "/etc/nftables.conf").Output()
	if err != nil {
		return nil, err
	}
	cmd := exec.Command("sudo", "nft", "-f", "-")
	cmd.Stdin = strings.NewReader(string(out))
	err = cmd.Run()
	if err != nil {
		return nil, err
	}
	return okJSON(), nil
}

func nftablesDisable() (interface{}, error) {
	err := exec.Command("sudo", "nft", "flush", "ruleset").Run()
	if err != nil {
		return nil, err
	}
	return okJSON(), nil
}