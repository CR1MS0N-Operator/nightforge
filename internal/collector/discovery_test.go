package collector

import "testing"

// TestDiscoverLangfuseUsesCanonicalEndpoint guards the 2026-10-19 fix
// (bead nightforge-aaj): discovery must probe the canonical Langfuse on
// :50598. It used to probe the retired OTel Collector on :31744, so it
// reported "disconnected" while the live instance was reachable.
func TestDiscoverLangfuseUsesCanonicalEndpoint(t *testing.T) {
	if DefaultLangfuseEndpoint != "http://127.0.0.1:50598" {
		t.Errorf("DefaultLangfuseEndpoint = %q, want http://127.0.0.1:50598", DefaultLangfuseEndpoint)
	}

	svc := DiscoverLangfuse("")
	if svc.Address != "http://127.0.0.1:50598" {
		t.Errorf("DiscoverLangfuse(\"\").Address = %q, want http://127.0.0.1:50598", svc.Address)
	}
}

// TestHostPort covers the endpoint shapes a configured Langfuse endpoint can
// take. A port is required: without one there is nothing to dial.
func TestHostPort(t *testing.T) {
	cases := []struct {
		name     string
		in       string
		wantHost string
		wantPort string
		wantErr  bool
	}{
		{"http url", "http://127.0.0.1:50598", "127.0.0.1", "50598", false},
		{"https url", "https://127.0.0.1:50598", "127.0.0.1", "50598", false},
		{"bare host port", "127.0.0.1:50598", "127.0.0.1", "50598", false},
		{"url with path", "http://127.0.0.1:50598/api/public/otel", "127.0.0.1", "50598", false},
		{"url with trailing slash", "http://127.0.0.1:50598/", "127.0.0.1", "50598", false},
		{"missing port", "http://127.0.0.1", "", "", true},
		{"empty port", "http://127.0.0.1:", "", "", true},
	}

	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			host, port, err := hostPort(c.in)
			if c.wantErr {
				if err == nil {
					t.Fatalf("hostPort(%q) = (%q, %q, nil), want an error", c.in, host, port)
				}
				return
			}
			if err != nil {
				t.Fatalf("hostPort(%q) error: %v", c.in, err)
			}
			if host != c.wantHost || port != c.wantPort {
				t.Errorf("hostPort(%q) = (%q, %q), want (%q, %q)", c.in, host, port, c.wantHost, c.wantPort)
			}
		})
	}
}
