package main

import (
	"encoding/json"
	"fmt"
	"os/exec"
	"regexp"
	"strconv"
	"strings"
)

type Mode struct {
	Resolution string  `json:"resolution"`
	Rate       float64 `json:"rate"`
	Preferred  bool    `json:"preferred"`
}

type Output struct {
	Name        string `json:"name"`
	CurrentMode string `json:"current_mode"`
	CurrentRate string `json:"current_rate"`
	BestMode    string `json:"best_mode"`
	BestRate    string `json:"best_rate"`
	Scale       string `json:"current_scale"`
	ScaleRec    string `json:"recommended_scale"`
	NiriConfig  string `json:"niri_config"`
}

func main() {
	raw, err := exec.Command("niri", "msg", "outputs").Output()
	if err != nil {
		fmt.Println(`[{"error":"niri msg outputs failed"}]`)
		return
	}

	lines := strings.Split(string(raw), "\n")
	var outputs []Output
	var current Output
	var modes []Mode
	inModes := false

	for _, line := range lines {
		line = strings.TrimRight(line, "\n\r")
		// Preserve leading whitespace for mode parsing
		if strings.TrimSpace(line) == "" {
			continue
		}

		if strings.HasPrefix(line, "Output") {
			if current.Name != "" {
				current = finalize(current, modes)
				outputs = append(outputs, current)
			}
			current = Output{}
			modes = nil
			inModes = false
			re := regexp.MustCompile(`Output "(.+)"`)
			m := re.FindStringSubmatch(line)
			if len(m) > 1 {
				current.Name = m[1]
			}
			continue
		}

		if strings.Contains(line, "Current mode:") {
			re := regexp.MustCompile(`Current mode:\s*(\d+x\d+)\s*@\s*([\d.]+)`)
			m := re.FindStringSubmatch(line)
			if len(m) > 2 {
				current.CurrentMode = m[1]
				current.CurrentRate = m[2]
			}
		}

		if strings.Contains(line, "Available modes:") {
			inModes = true
			continue
		}

		if inModes && strings.Contains(line, "@") {
			re := regexp.MustCompile(`^\s{4}(\d+x\d+)@([\d.]+)`)
			m := re.FindStringSubmatch(line)
			if len(m) > 2 {
				rate, _ := strconv.ParseFloat(m[2], 64)
				pref := strings.Contains(line, "preferred")
				modes = append(modes, Mode{
					Resolution: m[1],
					Rate:       rate,
					Preferred:  pref,
				})
			}
		}

		if strings.Contains(line, "Scale:") {
			re := regexp.MustCompile(`Scale:\s*([\d.]+)`)
			m := re.FindStringSubmatch(line)
			if len(m) > 1 {
				current.Scale = m[1]
			}
		}
	}
	if current.Name != "" {
		current = finalize(current, modes)
		outputs = append(outputs, current)
	}

	b, _ := json.MarshalIndent(outputs, "", "  ")
	fmt.Println(string(b))
}

func finalize(o Output, modes []Mode) Output {
	// Find native resolution (from preferred or current mode)
	nativeRes := ""
	for _, m := range modes {
		if m.Preferred {
			nativeRes = m.Resolution
			break
		}
	}
	if nativeRes == "" {
		nativeRes = o.CurrentMode
	}

	// Find highest refresh rate at native resolution
	bestRate := 0.0
	for _, m := range modes {
		if m.Resolution == nativeRes && m.Rate > bestRate {
			bestRate = m.Rate
		}
	}

	o.BestMode = nativeRes
	if bestRate > 0 {
		o.BestRate = fmt.Sprintf("%.3f", bestRate)
	} else {
		o.BestRate = o.CurrentRate
	}

	// Recommend scale based on resolution height
	parts := strings.Split(nativeRes, "x")
	if len(parts) == 2 {
		h, _ := strconv.Atoi(parts[1])
		switch {
		case h >= 4320:
			o.ScaleRec = "2.0"
		case h >= 2160:
			o.ScaleRec = "1.5"
		case h >= 1440:
			o.ScaleRec = "1.25"
		default:
			o.ScaleRec = "1.0"
		}
	}

	// Generate niri config block
	cfg := fmt.Sprintf(`output "%s" {
    mode "%s@%s"
    scale %s
    position x=0 y=0
    transform "normal"
}`, o.Name, o.BestMode, o.BestRate, o.ScaleRec)
	o.NiriConfig = cfg

	return o
}
