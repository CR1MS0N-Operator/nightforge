package main

import (
	"fmt"
	"os/exec"
	"strings"
)

type Service struct {
	Name   string `json:"name"`
	Type   string `json:"type"`
	Status string `json:"status"`
}

var monitoredServices = []struct {
	Name string
	Type string
}{
	{"hermes-gateway", "user"},
	{"sshd", "system"},
	{"docker", "system"},
	{"libvirtd", "system"},
	{"wg-quick@wg0", "system"},
	{"quickshell", "user"},
}

func serviceCmd(args []string) (interface{}, error) {
	if len(args) < 1 {
		return nil, fmt.Errorf("usage: dashboard-ctl service <list|start|stop> [name]")
	}
	switch args[0] {
	case "list":
		return serviceList()
	case "start":
		if len(args) < 2 {
			return nil, fmt.Errorf("usage: dashboard-ctl service start <name>")
		}
		return serviceStart(args[1])
	case "stop":
		if len(args) < 2 {
			return nil, fmt.Errorf("usage: dashboard-ctl service stop <name>")
		}
		return serviceStop(args[1])
	default:
		return nil, fmt.Errorf("unknown service action: %s", args[0])
	}
}

func serviceList() ([]Service, error) {
	var services []Service
	for _, svc := range monitoredServices {
		status := "inactive"
		if svc.Type == "user" {
			out, err := exec.Command("systemctl", "--user", "is-active", svc.Name).Output()
			if err == nil && strings.TrimSpace(string(out)) == "active" {
				status = "active"
			}
		} else {
			out, err := exec.Command("systemctl", "is-active", svc.Name).Output()
			if err == nil && strings.TrimSpace(string(out)) == "active" {
				status = "active"
			}
		}
		services = append(services, Service{
			Name:   svc.Name,
			Type:   svc.Type,
			Status: status,
		})
	}
	return services, nil
}

func findServiceType(name string) string {
	for _, svc := range monitoredServices {
		if svc.Name == name {
			return svc.Type
		}
	}
	return "system"
}

func serviceStart(name string) (interface{}, error) {
	svcType := findServiceType(name)
	var err error
	if svcType == "user" {
		err = exec.Command("systemctl", "--user", "start", name).Run()
	} else {
		err = exec.Command("sudo", "systemctl", "start", name).Run()
	}
	if err != nil {
		return nil, err
	}
	return okJSON(), nil
}

func serviceStop(name string) (interface{}, error) {
	svcType := findServiceType(name)
	var err error
	if svcType == "user" {
		err = exec.Command("systemctl", "--user", "stop", name).Run()
	} else {
		err = exec.Command("sudo", "systemctl", "stop", name).Run()
	}
	if err != nil {
		return nil, err
	}
	return okJSON(), nil
}