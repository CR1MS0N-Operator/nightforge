package main

import (
	"crypto/tls"
	"fmt"
	"net/http"
	"net/url"
	"os/exec"
	"strings"
	"time"
)

type C2Framework struct {
	Name   string `json:"name"`
	WebUI  string `json:"web_ui"`
	Status string `json:"status"`
}

var c2Frameworks = []struct {
	Name  string
	WebUI string
}{
	{"mythic", "https://127.0.0.1:7443"},
}

func c2Cmd(args []string) (interface{}, error) {
	if len(args) < 1 {
		return nil, fmt.Errorf("usage: dashboard-ctl c2 <list|start|stop> [name]")
	}
	switch args[0] {
	case "list":
		return c2List()
	case "start":
		if len(args) < 2 {
			return nil, fmt.Errorf("usage: dashboard-ctl c2 start <name>")
		}
		return c2Start(args[1])
	case "stop":
		if len(args) < 2 {
			return nil, fmt.Errorf("usage: dashboard-ctl c2 stop <name>")
		}
		return c2Stop(args[1])
	default:
		return nil, fmt.Errorf("unknown c2 action: %s", args[0])
	}
}


func c2HTTPClient(webUI string) (*http.Client, error) {
	parsed, err := url.Parse(webUI)
	if err != nil {
		return nil, err
	}
	tlsConfig := &tls.Config{}
	switch parsed.Hostname() {
	case "localhost", "127.0.0.1", "::1":
		tlsConfig.InsecureSkipVerify = true
	}
	return &http.Client{
		Timeout:   2 * time.Second,
		Transport: &http.Transport{TLSClientConfig: tlsConfig},
	}, nil
}
func c2List() ([]C2Framework, error) {
	var result []C2Framework
	for _, fw := range c2Frameworks {
		status := "offline"
		client, err := c2HTTPClient(fw.WebUI)
		if err != nil {
			return nil, err
		}
		resp, err := client.Get(fw.WebUI)
		if err == nil {
			resp.Body.Close()
			status = "online"
		}
		result = append(result, C2Framework{
			Name:   fw.Name,
			WebUI:  fw.WebUI,
			Status: status,
		})
	}
	return result, nil
}

func c2Start(name string) (interface{}, error) {
	serviceName := c2ServiceName(name)
	if serviceName == "" {
		return nil, fmt.Errorf("unknown c2 framework: %s", name)
	}
	err := exec.Command("sudo", "systemctl", "start", serviceName).Run()
	if err != nil {
		return nil, err
	}
	return okJSON(), nil
}

func c2Stop(name string) (interface{}, error) {
	serviceName := c2ServiceName(name)
	if serviceName == "" {
		return nil, fmt.Errorf("unknown c2 framework: %s", name)
	}
	err := exec.Command("sudo", "systemctl", "stop", serviceName).Run()
	if err != nil {
		return nil, err
	}
	return okJSON(), nil
}

func c2ServiceName(name string) string {
	name = strings.ToLower(name)
	for _, fw := range c2Frameworks {
		if strings.ToLower(fw.Name) == name {
			return fw.Name
		}
	}
	return ""
}