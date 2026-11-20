// llama-idle-proxy: reverse proxy in front of llama-server that starts the
// backend on first request and stops it after an idle timeout, so the GPU
// VRAM is only occupied while the model is actually in use.
//
// The proxy listens on --listen (what clients already target, 127.0.0.1:8080)
// and forwards to --backend (127.0.0.1:8081, where llama-server now runs).
// It manages the systemd service --service via `systemctl start/stop`.
package main

import (
	"flag"
	"fmt"
	"log"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os/exec"
	"strings"
	"sync"
	"time"
)

var (
	listenAddr = flag.String("listen", "127.0.0.1:8080", "address to listen on (client-facing)")
	backend    = flag.String("backend", "127.0.0.1:8081", "llama-server backend address")
	svcName    = flag.String("service", "llama-cpp.service", "systemd service to manage")
	idleSec    = flag.Int("idle", 300, "stop backend after this many seconds without requests")
	startupSec = flag.Int("startup", 90, "max seconds to wait for backend readiness")
)

// state is guarded by mu.
var (
	mu          = sync.Mutex{}
	lastRequest = time.Time{}
	inFlight    int64
)

func systemctl(args ...string) error {
	cmd := exec.Command("systemctl", args...)
	out, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("systemctl %v: %v: %s", args, err, strings.TrimSpace(string(out)))
	}
	return nil
}

func svcActive() bool {
	out, err := exec.Command("systemctl", "is-active", *svcName).CombinedOutput()
	if err != nil {
		return false
	}
	return strings.TrimSpace(string(out)) == "active"
}

func probeBackend() bool {
	client := &http.Client{Timeout: 1 * time.Second}
	resp, err := client.Get("http://" + *backend + "/health")
	if err != nil {
		return false
	}
	resp.Body.Close()
	return resp.StatusCode == http.StatusOK
}

// ensureBackend returns nil once the backend is healthy, starting the service
// if necessary. Safe for concurrent callers.
func ensureBackend() error {
	if probeBackend() {
		return nil
	}
	if err := systemctl("start", *svcName); err != nil {
		return err
	}
	log.Printf("started %s, waiting for readiness", *svcName)
	deadline := time.Now().Add(time.Duration(*startupSec) * time.Second)
	for time.Now().Before(deadline) {
		if probeBackend() {
			return nil
		}
		time.Sleep(1 * time.Second)
	}
	return fmt.Errorf("%s not ready after %ds", *svcName, *startupSec)
}

// requestStart marks a request as in-flight and updates lastRequest.
func requestStart() {
	mu.Lock()
	defer mu.Unlock()
	inFlight++
	lastRequest = time.Now()
}

// requestEnd clears the in-flight mark.
func requestEnd() {
	mu.Lock()
	defer mu.Unlock()
	if inFlight > 0 {
		inFlight--
	}
}

// maybeStop stops the backend if nothing is in flight and it has been idle
// long enough. Runs periodically.
func maybeStop() {
	mu.Lock()
	defer mu.Unlock()
	if inFlight > 0 {
		return
	}
	idle := time.Since(lastRequest)
	if idle < time.Duration(*idleSec) * time.Second {
		return
	}
	if !svcActive() {
		return
	}
	log.Printf("idle for %v, stopping %s (freeing VRAM)", idle.Round(time.Second), *svcName)
	if err := systemctl("stop", *svcName); err != nil {
		log.Printf("stop failed: %v", err)
	}
}

func main() {
	flag.Parse()
	log.Printf("llama-idle-proxy: %s -> %s (service=%s idle=%ds)",
		*listenAddr, *backend, *svcName, *idleSec)

	// periodic idle stopper
	go func() {
		tick := time.NewTicker(15 * time.Second)
		for range tick.C {
			maybeStop()
		}
	}()

	backendURL, err := url.Parse("http://" + *backend)
	if err != nil {
		log.Fatalf("invalid backend URL: %v", err)
	}

	proxy := &httputil.ReverseProxy{
		Rewrite: func(r *httputil.ProxyRequest) {
			r.SetURL(backendURL)
		},
		ErrorHandler: func(w http.ResponseWriter, r *http.Request, err error) {
			log.Printf("proxy error: %v", err)
			http.Error(w, "backend error", http.StatusBadGateway)
		},
	}

	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		requestStart()
		defer requestEnd()
		if err := ensureBackend(); err != nil {
			log.Printf("backend not ready: %v", err)
			http.Error(w, "backend not ready", http.StatusServiceUnavailable)
			return
		}
		proxy.ServeHTTP(w, r)
	})

	log.Printf("listening on %s", *listenAddr)
	srv := &http.Server{Addr: *listenAddr, Handler: handler}
	if err := srv.ListenAndServe(); err != nil {
		log.Fatalf("listen: %v", err)
	}
}
