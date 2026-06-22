package main

import (
	"fmt"
	"os/exec"
	"strings"
)

type Container struct {
	Name   string `json:"name"`
	Status string `json:"status"`
	Image  string `json:"image"`
	Ports  string `json:"ports"`
}

func containerCmd(args []string) (interface{}, error) {
	if len(args) < 1 {
		return nil, fmt.Errorf("usage: dashboard-ctl container <list|start|stop> [name]")
	}
	switch args[0] {
	case "list":
		return containerList()
	case "start":
		if len(args) < 2 {
			return nil, fmt.Errorf("usage: dashboard-ctl container start <name>")
		}
		return containerStart(args[1])
	case "stop":
		if len(args) < 2 {
			return nil, fmt.Errorf("usage: dashboard-ctl container stop <name>")
		}
		return containerStop(args[1])
	default:
		return nil, fmt.Errorf("unknown container action: %s", args[0])
	}
}

func containerList() ([]Container, error) {
	out, err := exec.Command("podman", "ps", "-a", "--format", "{{.Names}}|{{.Status}}|{{.Image}}|{{.Ports}}").Output()
	if err != nil {
		return nil, err
	}

	lines := strings.Split(strings.TrimSpace(string(out)), "\n")
	var containers []Container
	for _, l := range lines {
		l = strings.TrimSpace(l)
		if l == "" {
			continue
		}
		parts := strings.SplitN(l, "|", 4)
		if len(parts) < 3 {
			continue
		}
		status := "stopped"
		if strings.HasPrefix(parts[1], "Up") {
			status = "running"
		}
		ports := ""
		if len(parts) > 3 {
			ports = parts[3]
		}
		containers = append(containers, Container{
			Name:   parts[0],
			Status: status,
			Image:  parts[2],
			Ports:  ports,
		})
	}
	if len(containers) == 0 {
		return []Container{}, nil
	}
	return containers, nil
}

func containerStart(name string) (interface{}, error) {
	err := exec.Command("podman", "start", name).Run()
	if err != nil {
		return nil, err
	}
	return okJSON(), nil
}

func containerStop(name string) (interface{}, error) {
	err := exec.Command("podman", "stop", name).Run()
	if err != nil {
		return nil, err
	}
	return okJSON(), nil
}