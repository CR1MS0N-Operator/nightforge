package collector

import (
	"fmt"
	"net"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"time"
)

// DiscoveredService represents a dynamically discovered service.
type DiscoveredService struct {
	Name      string `json:"name"`
	Type      string `json:"type"`
	Status    string `json:"status"` // "connected", "disconnected", "unknown"
	Address   string `json:"address,omitempty"`
	PID       int    `json:"pid,omitempty"`
	StartTime string `json:"start_time,omitempty"`
}

// DiscoverHerdr checks if herdr is running and accessible via its socket.
func DiscoverHerdr(socketPath string) DiscoveredService {
	svc := DiscoveredService{
		Name:   "herdr",
		Type:   "terminal-runtime",
		Status: "disconnected",
	}

	if socketPath == "" {
		home, _ := os.UserHomeDir()
		socketPath = filepath.Join(home, ".local", "share", "herdr", "herdr.sock")
	}

	if _, err := os.Stat(socketPath); err != nil {
		return svc
	}

	conn, err := net.DialTimeout("unix", socketPath, 2*time.Second)
	if err != nil {
		return svc
	}
	defer conn.Close()

	svc.Status = "connected"
	svc.Address = socketPath
	return svc
}

// DefaultLangfuseEndpoint is the canonical Langfuse instance on this
// workstation. The duplicate Langfuse that used to live in
// 10-layer-stack/observability-stack (and the OTel Collector feeding it on
// :31744) was retired on 2026-10-19 — see bead nightforge-aaj. The live
// instance runs outside this repository on :50598.
const DefaultLangfuseEndpoint = "http://127.0.0.1:50598"

// DiscoverLangfuse checks if Langfuse is reachable at the OTLP endpoint.
func DiscoverLangfuse(endpoint string) DiscoveredService {
	svc := DiscoveredService{
		Name:   "langfuse",
		Type:   "tracing",
		Status: "disconnected",
	}

	if endpoint == "" {
		endpoint = DefaultLangfuseEndpoint
	}

	host, port, err := hostPort(endpoint)
	if err != nil {
		return svc
	}

	conn, err := net.DialTimeout("tcp", net.JoinHostPort(host, port), 2*time.Second)
	if err != nil {
		return svc
	}
	defer conn.Close()

	svc.Status = "connected"
	svc.Address = endpoint
	return svc
}

// hostPort extracts the dial host and port from an endpoint URL. It accepts
// a bare host:port as well as a full URL, and rejects anything without a
// port — a Langfuse endpoint always has one.
func hostPort(endpoint string) (string, string, error) {
	raw := endpoint
	if !strings.Contains(raw, "://") {
		raw = "http://" + raw
	}

	u, err := url.Parse(raw)
	if err != nil {
		return "", "", err
	}

	host := u.Hostname()
	if host == "" {
		host = "127.0.0.1"
	}
	port := u.Port()
	if port == "" {
		return "", "", fmt.Errorf("no port in endpoint %q", endpoint)
	}
	return host, port, nil
}

// DiscoverAgents checks which agents are available on the system.
func DiscoverAgents(agents []AgentDef) []DiscoveredService {
	var discovered []DiscoveredService

	for _, agent := range agents {
		svc := DiscoveredService{
			Name:   agent.Name,
			Type:   agent.Type,
			Status: "disconnected",
		}

		// Check if agent binary is in PATH
		if path, err := findBinary(agent.Command); err == nil {
			svc.Address = path
			svc.Status = "available"
		}

		discovered = append(discovered, svc)
	}

	return discovered
}

// AgentDef defines an agent for discovery purposes.
type AgentDef struct {
	Name    string
	Command string
	Type    string
}

// findBinary checks if a binary exists in PATH.
func findBinary(name string) (string, error) {
	// Check common paths
	for _, dir := range []string{"/usr/bin", "/usr/local/bin", filepath.Join(os.Getenv("HOME"), ".local", "bin")} {
		path := filepath.Join(dir, name)
		if info, err := os.Stat(path); err == nil && info.Mode().IsRegular() {
			return path, nil
		}
	}

	// Try exec.LookPath
	if path, err := os.Stat(name); err == nil && path.Mode().IsRegular() {
		return name, nil
	}

	return "", os.ErrNotExist
}

// GetAllDiscoveredServices runs all discovery checks and returns combined results.
func GetAllDiscoveredServices(herdrSocket, langfuseEndpoint string, agentDefs []AgentDef) []DiscoveredService {
	var all []DiscoveredService

	all = append(all, DiscoverHerdr(herdrSocket))
	all = append(all, DiscoverLangfuse(langfuseEndpoint))
	all = append(all, DiscoverAgents(agentDefs)...)

	return all
}
