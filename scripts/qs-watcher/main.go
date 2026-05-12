package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"syscall"
	"time"
)

var homeDir string

func init() {
	homeDir, _ = os.UserHomeDir()
}

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintln(os.Stderr, "Usage: qs-watcher daemon|fetch <type>|watch <type>")
		os.Exit(1)
	}
	switch os.Args[1] {
	case "daemon":
		runDaemon()
	case "fetch":
		if len(os.Args) < 3 {
			fmt.Fprintln(os.Stderr, "Usage: qs-watcher fetch <type>")
			os.Exit(1)
		}
		runFetch(os.Args[2])
	case "watch":
		if len(os.Args) < 3 {
			fmt.Fprintln(os.Stderr, "Usage: qs-watcher watch <type>")
			os.Exit(1)
		}
		runWatch(os.Args[2])
	default:
		fmt.Fprintf(os.Stderr, "Unknown command: %s\n", os.Args[1])
		os.Exit(1)
	}
}

// ============================================================
// DAEMON
// ============================================================

type WatchState struct {
	CPU        string `json:"cpu"`
	RAM        string `json:"ram"`
	RAMGB      string `json:"ram_gb"`
	TotalRAMGB string `json:"ram_total_gb"`
	Temp       string `json:"temp"`
	RX         string `json:"rx"`
	TX         string `json:"tx"`
	Volume     string `json:"volume"`
	VolumeIcon string `json:"volume_icon"`
	Muted      string `json:"is_muted"`
	BTStatus   string `json:"bt_status"`
	BTIcon     string `json:"bt_icon"`
	BTDevice   string `json:"bt_device"`
	NetStatus  string `json:"net_status"`
	NetSSID    string `json:"net_ssid"`
	NetIcon    string `json:"net_icon"`
	ETHStatus  string `json:"eth_status"`
	BatPercent string `json:"bat_percent"`
	BatStatus  string `json:"bat_status"`
	BatIcon    string `json:"bat_icon"`
	KBLayout   string `json:"kb_layout"`
}

func runDaemon() {
	state := &WatchState{}
	sig := make(chan os.Signal, 1)
	signal.Notify(sig, syscall.SIGINT, syscall.SIGTERM)

	go func() {
		for {
			fetchSysInfo(state)
			fetchAudio(state)
			fetchBluetooth(state)
			fetchNetwork(state)
			fetchBattery(state)
			fetchKeyboard(state)
			writeState(state)
			time.Sleep(3000 * time.Millisecond)
		}
	}()
	<-sig
}

func writeState(s *WatchState) {
	data, _ := json.Marshal(s)
	os.WriteFile("/tmp/qs_watcher_state.json", data, 0644)
}

// ============================================================
// FETCH SUBCOMMAND
// ============================================================

func runFetch(typ string) {
	switch typ {
	case "sys":
		s := &WatchState{}
		fetchSysInfo(s)
		fmt.Printf("%s|%s|%s|%s|%s|%s\n", s.CPU, s.RAM, s.RAMGB, s.TotalRAMGB, s.Temp, s.RX)
	case "audio":
		s := &WatchState{}
		fetchAudio(s)
		fmt.Printf(`{"volume":"%s","icon":"%s","is_muted":"%s"}`, s.Volume, s.VolumeIcon, s.Muted)
	case "bt":
		if len(os.Args) > 3 && os.Args[3] == "--toggle" {
			toggleBluetooth()
		} else {
			s := &WatchState{}
			fetchBluetooth(s)
			fmt.Printf(`{"status":"%s","icon":"%s","connected":"%s"}`, s.BTStatus, s.BTIcon, s.BTDevice)
		}
	case "network":
		if len(os.Args) > 3 && os.Args[3] == "--toggle" {
			toggleWifi()
		} else {
			s := &WatchState{}
			fetchNetwork(s)
			fmt.Printf(`{"status":"%s","ssid":"%s","icon":"%s","eth_status":"%s"}`, s.NetStatus, s.NetSSID, s.NetIcon, s.ETHStatus)
		}
	case "battery":
		s := &WatchState{}
		fetchBattery(s)
		fmt.Printf(`{"percent":"%s","status":"%s","icon":"%s"}`, s.BatPercent, s.BatStatus, s.BatIcon)
	case "kb":
		s := &WatchState{}
		fetchKeyboard(s)
		fmt.Printf(`{"layout":"%s"}`, s.KBLayout)
	case "connections":
		fmt.Println(fetchConnectionsJSON())
	}
}

// ============================================================
// WATCH SUBCOMMAND
// ============================================================

func runWatch(typ string) {
	switch typ {
	case "audio":
		cmd := exec.Command("pactl", "subscribe")
		stdout, _ := cmd.StdoutPipe()
		cmd.Start()
		defer func() { cmd.Process.Kill(); cmd.Wait() }()
		re := regexp.MustCompile(`(sink|server)`)
		scanner := bufio.NewScanner(stdout)
		for scanner.Scan() {
			if re.MatchString(scanner.Text()) {
				return
			}
		}
	case "bt":
		cmd := exec.Command("dbus-monitor", "--system",
			"type='signal',interface='org.freedesktop.DBus.Properties',member='PropertiesChanged'")
		stdout, _ := cmd.StdoutPipe()
		cmd.Start()
		defer func() { cmd.Process.Kill(); cmd.Wait() }()
		re := regexp.MustCompile(`(string "Connected"|string "Powered"|arg0='org\.bluez\.)`)
		scanner := bufio.NewScanner(stdout)
		for scanner.Scan() {
			if re.MatchString(scanner.Text()) {
				return
			}
		}
	case "network":
		cmd := exec.Command("nmcli", "monitor")
		stdout, _ := cmd.StdoutPipe()
		stderr, _ := cmd.StderrPipe()
		cmd.Start()
		defer func() { cmd.Process.Kill(); cmd.Wait() }()
		go func() { bufio.NewScanner(stderr) }()
		re := regexp.MustCompile(`(?i)(connected|disconnected|enabled|disabled|activated|deactivated)`)
		scanner := bufio.NewScanner(stdout)
		for scanner.Scan() {
			if re.MatchString(scanner.Text()) {
				return
			}
		}
	case "battery":
		powerDir := "/sys/class/power_supply"
		entries, err := os.ReadDir(powerDir)
		if err != nil {
			time.Sleep(30 * time.Second)
			return
		}
		var watchPaths []string
		for _, e := range entries {
			if strings.HasPrefix(e.Name(), "BAT") {
				uevent := filepath.Join(powerDir, e.Name(), "uevent")
				if _, err := os.Stat(uevent); err == nil {
					watchPaths = append(watchPaths, uevent)
				}
			}
		}
		if len(watchPaths) == 0 {
			cmd := exec.Command("udevadm", "monitor", "--subsystem-match=power_supply")
			stdout, _ := cmd.StdoutPipe()
			cmd.Start()
			defer func() { cmd.Process.Kill(); cmd.Wait() }()
			scanner := bufio.NewScanner(stdout)
			for scanner.Scan() {
				return
			}
			return
		}
		wp := watchPaths[0]
		lastMod := getModTime(wp)
		for {
			time.Sleep(500 * time.Millisecond)
			if getModTime(wp) != lastMod {
				return
			}
		}
	case "kb":
		hyprSig := os.Getenv("HYPRLAND_INSTANCE_SIGNATURE")
		if hyprSig != "" {
			runtimeDir := os.Getenv("XDG_RUNTIME_DIR")
			sockPath := filepath.Join(runtimeDir, "hypr", hyprSig, ".socket2.sock")
			if _, err := os.Stat(sockPath); err == nil {
				cmd := exec.Command("socat", "-U", "-", fmt.Sprintf("UNIX-CONNECT:%s", sockPath))
				stdout, _ := cmd.StdoutPipe()
				cmd.Start()
				defer func() { cmd.Process.Kill(); cmd.Wait() }()
				scanner := bufio.NewScanner(stdout)
				for scanner.Scan() {
					if strings.Contains(scanner.Text(), "activelayout>>") {
						return
					}
				}
				return
			}
		}
		time.Sleep(5 * time.Second)
	}
}

func getModTime(path string) time.Time {
	info, err := os.Stat(path)
	if err != nil {
		return time.Time{}
	}
	return info.ModTime()
}

// ============================================================
// SYS INFO — PURE GO (read /proc directly, NO subprocesses)
// ============================================================

func fetchSysInfo(s *WatchState) {
	cpu1, total1 := readCPUStats()
	rx1, tx1 := readNetStats()
	time.Sleep(300 * time.Millisecond)
	cpu2, total2 := readCPUStats()
	rx2, tx2 := readNetStats()

	diffTotal := total2 - total1
	diffIdle := (cpu2 - cpu1)
	cpuUsage := 0
	if diffTotal > 0 {
		cpuUsage = (diffTotal - diffIdle) * 100 / diffTotal
	}
	if cpuUsage < 0 {
		cpuUsage = 0
	}
	if cpuUsage > 100 {
		cpuUsage = 100
	}

	totalMem, availMem := readMemInfo()
	usedMem := totalMem - availMem
	ramPct := 0
	if totalMem > 0 {
		ramPct = usedMem * 100 / totalMem
	}
	ramGb := fmt.Sprintf("%.1f", float64(usedMem)/1024.0/1024.0)
	ramTotalGb := fmt.Sprintf("%.1f", float64(totalMem)/1024.0/1024.0)
	temp := readTemp()

	s.CPU = strconv.Itoa(cpuUsage)
	s.RAM = strconv.Itoa(ramPct)
	s.RAMGB = ramGb
	s.TotalRAMGB = ramTotalGb
	s.Temp = strconv.Itoa(temp)
	s.RX = strconv.Itoa(rx2 - rx1)
	s.TX = strconv.Itoa(tx2 - tx1)
}

func readCPUStats() (idle, total int) {
	data, err := os.ReadFile("/proc/stat")
	if err != nil {
		return 0, 0
	}
	for _, line := range strings.Split(string(data), "\n") {
		if !strings.HasPrefix(line, "cpu ") {
			break
		}
		fields := strings.Fields(line)
		if len(fields) < 9 {
			return 0, 0
		}
		vals := make([]int, len(fields)-1)
		for i := 1; i < len(fields); i++ {
			v, _ := strconv.Atoi(fields[i])
			vals[i-1] = v
		}
		idle = vals[3] + vals[4]
		for _, v := range vals {
			total += v
		}
		return
	}
	return 0, 0
}

func readNetStats() (rx, tx int) {
	data, err := os.ReadFile("/proc/net/dev")
	if err != nil {
		return 0, 0
	}
	for _, line := range strings.Split(string(data), "\n") {
		trimmed := strings.TrimSpace(line)
		if strings.HasPrefix(trimmed, "e") || strings.HasPrefix(trimmed, "w") {
			fields := strings.Fields(trimmed)
			if len(fields) >= 11 {
				colonIdx := strings.Index(fields[0], ":")
				if colonIdx < 0 {
					continue
				}
				r, _ := strconv.Atoi(fields[1])
				t, _ := strconv.Atoi(fields[9])
				rx += r
				tx += t
			}
		}
	}
	return
}

func readMemInfo() (total, available int) {
	data, err := os.ReadFile("/proc/meminfo")
	if err != nil {
		return 0, 0
	}
	for _, line := range strings.Split(string(data), "\n") {
		fields := strings.Fields(line)
		if len(fields) >= 2 {
			val, _ := strconv.Atoi(fields[1])
			if strings.HasPrefix(line, "MemTotal:") {
				total = val
			} else if strings.HasPrefix(line, "MemAvailable:") {
				available = val
			}
		}
	}
	return
}

func readTemp() int {
	hwmonNames := []string{"coretemp", "k10temp", "zenpower", "cpu_thermal", "bcm2835_thermal"}
	entries, err := os.ReadDir("/sys/class/hwmon")
	if err == nil {
		for _, e := range entries {
			nameData, err := os.ReadFile(filepath.Join("/sys/class/hwmon", e.Name(), "name"))
			if err != nil {
				continue
			}
			hwmonName := strings.TrimSpace(string(nameData))
			for _, known := range hwmonNames {
				if hwmonName == known {
					tempData, err := os.ReadFile(filepath.Join("/sys/class/hwmon", e.Name(), "temp1_input"))
					if err == nil {
						raw := strings.TrimSpace(string(tempData))
						val, err := strconv.Atoi(raw)
						if err == nil {
							return val / 1000
						}
					}
				}
			}
		}
	}

	thermalIDs := []string{"x86_pkg_temp", "cpu-thermal", "soc_thermal"}
	entries2, err := os.ReadDir("/sys/class/thermal")
	if err == nil {
		for _, e := range entries2 {
			if !strings.HasPrefix(e.Name(), "thermal_zone") {
				continue
			}
			typeData, err := os.ReadFile(filepath.Join("/sys/class/thermal", e.Name(), "type"))
			if err != nil {
				continue
			}
			zoneType := strings.TrimSpace(string(typeData))
			for _, id := range thermalIDs {
				if zoneType == id {
					tempData, err := os.ReadFile(filepath.Join("/sys/class/thermal", e.Name(), "temp"))
					if err == nil {
						raw := strings.TrimSpace(string(tempData))
						val, err := strconv.Atoi(raw)
						if err == nil {
							if val > 1000 {
								return val / 1000
							}
							return val
						}
					}
				}
			}
		}
	}

	if entries3, err := os.ReadDir("/sys/class/hwmon"); err == nil && len(entries3) > 0 {
		tempData, err := os.ReadFile(filepath.Join("/sys/class/hwmon", entries3[0].Name(), "temp1_input"))
		if err == nil {
			raw := strings.TrimSpace(string(tempData))
			val, err := strconv.Atoi(raw)
			if err == nil {
				return val / 1000
			}
		}
	}

	return 0
}

// ============================================================
// AUDIO (exec wpctl/pamixer)
// ============================================================

func fetchAudio(s *WatchState) {
	vol := getVolume()
	muted := isMuted()
	s.Volume = vol
	s.VolumeIcon = getVolumeIcon(vol, muted)
	s.Muted = muted
}

func getVolume() string {
	out, err := exec.Command("wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@").Output()
	if err == nil {
		parts := strings.Fields(string(out))
		if len(parts) >= 2 {
			f, err := strconv.ParseFloat(parts[1], 64)
			if err == nil {
				return strconv.Itoa(int(f * 100))
			}
		}
	}
	out, err = exec.Command("pamixer", "--get-volume").Output()
	if err == nil {
		return strings.TrimSpace(string(out))
	}
	return "0"
}

func isMuted() string {
	out, err := exec.Command("wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@").Output()
	if err == nil {
		if strings.Contains(string(out), "MUTED") {
			return "true"
		}
		return "false"
	}
	out, err = exec.Command("pamixer", "--get-mute").Output()
	if err == nil && strings.TrimSpace(string(out)) == "true" {
		return "true"
	}
	return "false"
}

func getVolumeIcon(vol string, muted string) string {
	if muted == "true" {
		return "\U000f075f"
	}
	v, _ := strconv.Atoi(vol)
	if v >= 70 {
		return "\U000f057e"
	}
	if v >= 30 {
		return "\U000f0580"
	}
	if v > 0 {
		return "\U000f057f"
	}
	return "\U000f075f"
}

// ============================================================
// BLUETOOTH (exec bluetoothctl)
// ============================================================

func fetchBluetooth(s *WatchState) {
	status := getBtStatus()
	s.BTStatus = status
	s.BTIcon = getBtIcon(status)
	s.BTDevice = getBtConnectedDevice(status)
}

func getBtStatus() string {
	out, err := exec.Command("timeout", "0.5", "bluetoothctl", "show").Output()
	if err == nil && strings.Contains(string(out), "Powered: yes") {
		return "on"
	}
	return "off"
}

func getBtConnectedDevice(status string) string {
	if status != "on" {
		return "Off"
	}
	out, err := exec.Command("timeout", "0.5", "bluetoothctl", "devices", "Connected").Output()
	if err != nil {
		return "Disconnected"
	}
	lines := strings.Split(strings.TrimSpace(string(out)), "\n")
	if len(lines) > 0 && strings.HasPrefix(lines[0], "Device ") {
		parts := strings.SplitN(lines[0], " ", 3)
		if len(parts) >= 3 {
			return parts[2]
		}
	}
	return "Disconnected"
}

func getBtIcon(status string) string {
	if status != "on" {
		return "\U000f00b2"
	}
	out, err := exec.Command("timeout", "0.5", "bluetoothctl", "devices", "Connected").Output()
	if err == nil && strings.Contains(string(out), "Device ") {
		return "\U000f00b1"
	}
	return "\U000f008f"
}

func toggleBluetooth() {
	status := getBtStatus()
	if status == "on" {
		exec.Command("bluetoothctl", "power", "off").Run()
		exec.Command("notify-send", "-u", "low", "-i", "bluetooth-disabled", "Bluetooth", "Disabled").Run()
	} else {
		exec.Command("bluetoothctl", "power", "on").Run()
		exec.Command("notify-send", "-u", "low", "-i", "bluetooth-active", "Bluetooth", "Enabled").Run()
	}
}

// ============================================================
// NETWORK (exec nmcli/iw, read /proc)
// ============================================================

func fetchNetwork(s *WatchState) {
	status, ssid, icon, ethStatus := getNetworkData()
	s.NetStatus = status
	s.NetSSID = ssid
	s.NetIcon = icon
	s.ETHStatus = ethStatus
}

func getNetworkData() (string, string, string, string) {
	activeIface := getDefaultIface()
	ifaceType := getIfaceType(activeIface)

	ethStatus := "Disconnected"

	if ifaceType == "ethernet" {
		return "enabled", "Ethernet", "\U000f0200", "Connected"
	}

	if ifaceType == "wifi" {
		ssid := getWifiSSID()
		signal := getWifiStrength()
		icon := wifiIcon(signal)
		ethDev := getEthConnectedDev()
		if ethDev != "" {
			ethStatus = "Connected"
		}
		return "enabled", ssid, icon, ethStatus
	}

	radio := getWifiRadio()
	wifiDev := getWifiDev()

	if wifiDev == "" {
		return "disabled", "", "\U000f0202", "Disconnected"
	}
	if radio == "disabled" {
		return "disabled", "", "\U000f056e", "Disconnected"
	}
	return "enabled", "", "\U000f056f", "Disconnected"
}

func getDefaultIface() string {
	data, err := os.ReadFile("/proc/net/route")
	if err != nil {
		return ""
	}
	for _, line := range strings.Split(string(data), "\n") {
		fields := strings.Fields(line)
		if len(fields) >= 8 && fields[1] == "00000000" {
			return fields[0]
		}
	}
	return ""
}

func getIfaceType(iface string) string {
	if iface == "" {
		return ""
	}
	out, err := exec.Command("nmcli", "-t", "-f", "DEVICE,TYPE", "d").Output()
	if err != nil {
		return ""
	}
	for _, line := range strings.Split(string(out), "\n") {
		parts := strings.SplitN(line, ":", 3)
		if len(parts) >= 2 && parts[0] == iface {
			return parts[1]
		}
	}
	return ""
}

func getWifiSSID() string {
	out, err := exec.Command("iw", "dev").Output()
	if err == nil {
		for _, line := range strings.Split(string(out), "\n") {
			trimmed := strings.TrimSpace(line)
			if strings.HasPrefix(trimmed, "ssid") {
				return strings.TrimSpace(trimmed[4:])
			}
		}
	}
	out, err = exec.Command("nmcli", "-t", "-f", "NAME,TYPE", "connection", "show", "--active").Output()
	if err == nil {
		for _, line := range strings.Split(string(out), "\n") {
			parts := strings.SplitN(line, ":", 2)
			if len(parts) >= 2 && parts[1] == "802-11-wireless" {
				return parts[0]
			}
		}
	}
	return ""
}

func getWifiStrength() int {
	data, err := os.ReadFile("/proc/net/wireless")
	if err != nil {
		return 0
	}
	lines := strings.Split(string(data), "\n")
	if len(lines) >= 3 {
		fields := strings.Fields(lines[2])
		if len(fields) >= 3 {
			raw := strings.ReplaceAll(fields[2], ".", "")
			val, err := strconv.Atoi(raw)
			if err == nil {
				pct := val * 100 / 70
				if pct > 100 {
					pct = 100
				}
				return pct
			}
		}
	}
	return 0
}

func wifiIcon(signal int) string {
	switch {
	case signal >= 75:
		return "\U000f0528"
	case signal >= 50:
		return "\U000f0525"
	case signal >= 25:
		return "\U000f0522"
	default:
		return "\U000f051f"
	}
}

func getEthConnectedDev() string {
	out, err := exec.Command("nmcli", "-t", "-f", "DEVICE,TYPE,STATE", "d").Output()
	if err != nil {
		return ""
	}
	for _, line := range strings.Split(string(out), "\n") {
		parts := strings.SplitN(line, ":", 3)
		if len(parts) >= 3 && parts[1] == "ethernet" && parts[2] == "connected" && parts[0] != "lo" {
			return parts[0]
		}
	}
	return ""
}

func getWifiRadio() string {
	out, err := exec.Command("nmcli", "radio", "wifi").Output()
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(out))
}

func getWifiDev() string {
	out, err := exec.Command("nmcli", "-t", "-f", "DEVICE,TYPE", "d").Output()
	if err != nil {
		return ""
	}
	for _, line := range strings.Split(string(out), "\n") {
		parts := strings.SplitN(line, ":", 2)
		if len(parts) >= 2 && parts[1] == "wifi" {
			return parts[0]
		}
	}
	return ""
}

func toggleWifi() {
	radio := getWifiRadio()
	if radio == "enabled" {
		exec.Command("nmcli", "radio", "wifi", "off").Run()
		exec.Command("notify-send", "-u", "low", "-i", "network-wireless-disabled", "WiFi", "Disabled").Run()
	} else {
		exec.Command("nmcli", "radio", "wifi", "on").Run()
		exec.Command("notify-send", "-u", "low", "-i", "network-wireless-enabled", "WiFi", "Enabled").Run()
	}
}

// ============================================================
// BATTERY (pure Go — read sysfs)
// ============================================================

func fetchBattery(s *WatchState) {
	percent := readFirstLine("/sys/class/power_supply/BAT1/capacity")
	if percent == "" {
		percent = readFirstGlob("/sys/class/power_supply/BAT*/capacity")
	}
	if percent == "" {
		percent = "100"
	}

	status := readFirstLine("/sys/class/power_supply/BAT1/status")
	if status == "" {
		status = readFirstGlob("/sys/class/power_supply/BAT*/status")
	}
	if status == "" {
		status = "Full"
	}

	s.BatPercent = percent
	s.BatStatus = status
	s.BatIcon = getBatteryIcon(percent, status)
}

func getBatteryIcon(percent string, status string) string {
	p, _ := strconv.Atoi(percent)
	charging := status == "Charging" || status == "Full"
	if charging {
		switch {
		case p >= 90:
			return "\U000f0085"
		case p >= 80:
			return "\U000f008b"
		case p >= 60:
			return "\U000f008a"
		case p >= 40:
			return "\U000f089e"
		case p >= 20:
			return "\U000f0086"
		default:
			return "\U000f089c"
		}
	}
	switch {
	case p >= 90:
		return "\U000f0079"
	case p >= 80:
		return "\U000f0082"
	case p >= 70:
		return "\U000f0081"
	case p >= 60:
		return "\U000f0080"
	case p >= 50:
		return "\U000f007f"
	case p >= 40:
		return "\U000f007e"
	case p >= 30:
		return "\U000f007d"
	case p >= 20:
		return "\U000f007c"
	case p >= 10:
		return "\U000f007b"
	default:
		return "\U000f007a"
	}
}

// ============================================================
// KEYBOARD (exec setxkbmap/localectl)
// ============================================================

func fetchKeyboard(s *WatchState) {
	layout := ""
	out, err := exec.Command("setxkbmap", "-query").Output()
	if err == nil {
		for _, line := range strings.Split(string(out), "\n") {
			if strings.HasPrefix(line, "layout") {
				parts := strings.Fields(line)
				if len(parts) >= 2 {
					layout = parts[len(parts)-1]
				}
				break
			}
		}
	}
	if layout == "" {
		out, err = exec.Command("localectl", "status").Output()
		if err == nil {
			for _, line := range strings.Split(string(out), "\n") {
				if strings.Contains(line, "X11 Layout") {
					parts := strings.SplitN(line, ":", 2)
					if len(parts) >= 2 {
						layout = strings.TrimSpace(parts[1])
					}
					break
				}
			}
		}
	}
	if layout == "" {
		layout = "us"
	}
	s.KBLayout = layout
}

// ============================================================
// CONNECTIONS (exec podman/virsh/lsusb/wg/ss concurrently)
// ============================================================

type ConnectionsData struct {
	Containers string `json:"containers"`
	VMs       string `json:"vms"`
	USB       string `json:"usb"`
	Network   string `json:"network"`
	SSH       string `json:"ssh"`
}

func fetchConnectionsJSON() string {
	type result struct {
		field string
		val   string
	}
	ch := make(chan result, 5)

	go func() {
		ch <- result{"containers", runTruncate("podman", []string{"ps", "--format", "{{.Names}}|{{.Status}}|{{.Ports}}"}, 2000)}
	}()
	go func() { ch <- result{"vms", fetchVMs()} }()
	go func() { ch <- result{"usb", runTruncate("lsusb", nil, 2000)} }()
	go func() { ch <- result{"network", runTruncate("wg", []string{"show"}, 2000)} }()
	go func() { ch <- result{"ssh", fetchSSH()} }()

	data := ConnectionsData{}
	for i := 0; i < 5; i++ {
		r := <-ch
		switch r.field {
		case "containers":
			data.Containers = r.val
		case "vms":
			data.VMs = r.val
		case "usb":
			data.USB = r.val
		case "network":
			data.Network = r.val
		case "ssh":
			data.SSH = r.val
		}
	}
	b, _ := json.Marshal(data)
	return string(b)
}

func fetchVMs() string {
	out, err := exec.Command("virsh", "list", "--all").Output()
	if err != nil {
		return ""
	}
	lines := strings.Split(string(out), "\n")
	var result []string
	for i := 2; i < len(lines) && i < 22; i++ {
		line := strings.TrimSpace(lines[i])
		if line == "" {
			continue
		}
		fields := strings.Fields(line)
		if len(fields) >= 3 {
			result = append(result, fields[1]+"|"+strings.Join(fields[2:], " "))
		} else if len(fields) >= 2 {
			result = append(result, fields[1]+"|unknown")
		}
	}
	r := strings.Join(result, "\n")
	if len(r) > 2000 {
		r = r[:2000]
	}
	return r
}

func fetchSSH() string {
	out, err := exec.Command("ss", "-tlnp").Output()
	if err != nil {
		return ""
	}
	var lines []string
	for _, line := range strings.Split(string(out), "\n") {
		if strings.Contains(line, "sshd") {
			lines = append(lines, line)
		}
	}
	r := strings.Join(lines, "\n")
	if len(r) > 2000 {
		r = r[:2000]
	}
	return r
}

func runTruncate(cmd string, args []string, maxLen int) string {
	var out []byte
	var err error
	if args == nil {
		out, err = exec.Command(cmd).Output()
	} else {
		out, err = exec.Command(cmd, args...).Output()
	}
	if err != nil {
		return ""
	}
	r := string(out)
	if len(r) > maxLen {
		r = r[:maxLen]
	}
	return strings.TrimSpace(r)
}

// ============================================================
// HELPERS
// ============================================================

func readFirstLine(path string) string {
	data, err := os.ReadFile(path)
	if err != nil {
		return ""
	}
	lines := strings.Split(strings.TrimSpace(string(data)), "\n")
	if len(lines) > 0 {
		return strings.TrimSpace(lines[0])
	}
	return ""
}

func readFirstGlob(pattern string) string {
	matches, err := filepath.Glob(pattern)
	if err != nil || len(matches) == 0 {
		return ""
	}
	return readFirstLine(matches[0])
}