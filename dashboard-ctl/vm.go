package main

import (
	"encoding/json"
	"fmt"
	"os/exec"
	"strconv"
	"strings"
)

type VM struct {
	Name    string `json:"name"`
	State   string `json:"state"`
	VCPUs   int    `json:"vcpus"`
	MemoryMB int   `json:"memory_mb"`
}

func vmCmd(args []string) (interface{}, error) {
	if len(args) < 1 {
		return nil, fmt.Errorf("usage: dashboard-ctl vm <list|start|shutdown> [name]")
	}
	switch args[0] {
	case "list":
		return vmList()
	case "start":
		if len(args) < 2 {
			return nil, fmt.Errorf("usage: dashboard-ctl vm start <name>")
		}
		return vmStart(args[1])
	case "shutdown":
		if len(args) < 2 {
			return nil, fmt.Errorf("usage: dashboard-ctl vm shutdown <name>")
		}
		return vmShutdown(args[1])
	default:
		return nil, fmt.Errorf("unknown vm action: %s", args[0])
	}
}

func vmList() ([]VM, error) {
	out, err := exec.Command("virsh", "-c", "qemu:///system", "list", "--all", "--name").Output()
	if err != nil {
		return nil, err
	}

	lines := strings.Split(strings.TrimSpace(string(out)), "\n")
	var names []string
	for _, l := range lines {
		l = strings.TrimSpace(l)
		if l != "" {
			names = append(names, l)
		}
	}
	if len(names) == 0 {
		return []VM{}, nil
	}

	var vms []VM
	for _, name := range names {
		state := "stopped"
		if sOut, sErr := exec.Command("virsh", "-c", "qemu:///system", "domstate", name).Output(); sErr == nil {
			state = strings.TrimSpace(string(sOut))
		}

		vcpus := 0
		memoryMB := 0
		if xmlOut, xmlErr := exec.Command("virsh", "-c", "qemu:///system", "dumpxml", name).Output(); xmlErr == nil {
			vcpus, memoryMB = parseVMDumpXML(string(xmlOut))
		}

		vms = append(vms, VM{
			Name:     name,
			State:    state,
			VCPUs:    vcpus,
			MemoryMB: memoryMB,
		})
	}
	return vms, nil
}

func parseVMDumpXML(xml string) (vcpus int, memoryMB int) {
	for _, line := range strings.Split(xml, "\n") {
		line = strings.TrimSpace(line)
		if strings.HasPrefix(line, "<vcpu") {
			start := strings.Index(line, ">")
			end := strings.Index(line, "</vcpu>")
			if start != -1 && end != -1 {
				if n, err := strconv.Atoi(line[start+1 : end]); err == nil {
					vcpus = n
				}
			}
		}
		if strings.HasPrefix(line, "<memory unit='KiB'>") {
			start := strings.Index(line, ">")
			end := strings.Index(line, "</memory>")
			if start != -1 && end != -1 {
				if kib, err := strconv.Atoi(line[start+1 : end]); err == nil {
					memoryMB = kib / 1024
				}
			}
		}
		if strings.HasPrefix(line, "<memory>") && !strings.Contains(line, "unit") {
			start := strings.Index(line, ">")
			end := strings.Index(line, "</memory>")
			if start != -1 && end != -1 {
				if kib, err := strconv.Atoi(line[start+1 : end]); err == nil {
					memoryMB = kib / 1024
				}
			}
		}
	}
	return vcpus, memoryMB
}

func vmStart(name string) (interface{}, error) {
	err := exec.Command("virsh", "-c", "qemu:///system", "start", name).Run()
	if err != nil {
		return nil, err
	}
	return okJSON(), nil
}

func vmShutdown(name string) (interface{}, error) {
	err := exec.Command("virsh", "-c", "qemu:///system", "shutdown", name).Run()
	if err != nil {
		return nil, err
	}
	return okJSON(), nil
}

func init() {
	_ = json.Marshal
	_ = fmt.Fprintf
}