package main

import (
	"fmt"
	"os/exec"
	"strconv"
	"strings"
)

type TmuxSession struct {
	Session  string `json:"session"`
	Windows  int    `json:"windows"`
	Attached bool   `json:"attached"`
}

func tmuxCmd(args []string) (interface{}, error) {
	if len(args) < 1 {
		return nil, fmt.Errorf("usage: dashboard-ctl tmux <list>")
	}
	switch args[0] {
	case "list":
		return tmuxList()
	default:
		return nil, fmt.Errorf("unknown tmux action: %s", args[0])
	}
}

func tmuxList() ([]TmuxSession, error) {
	out, err := exec.Command("tmux", "list-sessions", "-F", "#{session_name}|#{session_windows}|#{session_attached}").Output()
	if err != nil {
		return []TmuxSession{}, nil
	}

	lines := strings.Split(strings.TrimSpace(string(out)), "\n")
	var sessions []TmuxSession
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}
		parts := strings.SplitN(line, "|", 3)
		if len(parts) < 3 {
			continue
		}
		windows, _ := strconv.Atoi(parts[1])
		attached := parts[2] == "1"
		sessions = append(sessions, TmuxSession{
			Session:  parts[0],
			Windows:  windows,
			Attached: attached,
		})
	}
	if len(sessions) == 0 {
		return []TmuxSession{}, nil
	}
	return sessions, nil
}
