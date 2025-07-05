package main

import (
	"bufio"
	"bytes"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/textproto"
	"net/url"
	"os/exec"
	"strconv"
	"strings"
)

// targetProxyURL is the base URL of the actual Go module proxy we want to use.
const targetProxyURL = "https://goproxy.io"

// proxyHandler is the core of our proxy. It takes an incoming request,
// shells out to `curl.exe` to perform the fetch, and then reconstructs
// the full HTTP response to send back to the client (the `go` tool).
func proxyHandler(w http.ResponseWriter, r *http.Request) {
	// Construct the full target URL for curl to fetch.
	targetURL, err := url.Parse(targetProxyURL)
	if err != nil {
		log.Printf("Internal error: Failed to parse base proxy URL: %v", err)
		http.Error(w, "Internal proxy configuration error", http.StatusInternalServerError)
		return
	}
	targetURL.Path = r.URL.Path
	targetURL.RawQuery = r.URL.RawQuery

	log.Printf("Proxying request via curl: %s\n", targetURL.String())

	// --- REVISED APPROACH: Execute curl.exe with -i to include headers ---
	// We use `curl` which is known to work in your environment.
	// -s: Silent mode (no progress meter).
	// -L: Follow redirects.
	// -i: Include protocol response headers in the output. This is more reliable
	//     than trying to capture the status code from stderr.
	cmd := exec.Command("curl.exe", "-s", "-L", "-i", targetURL.String())

	var stdoutBuf, stderrBuf bytes.Buffer
	cmd.Stdout = &stdoutBuf
	cmd.Stderr = &stderrBuf

	// Run the curl command.
	err = cmd.Run()
	if err != nil {
		// This indicates an error launching or running curl itself.
		log.Printf("Failed to execute curl command: %v", err)
		log.Printf("Stderr from curl: %s", stderrBuf.String())
		http.Error(w, "Failed to execute curl", http.StatusInternalServerError)
		return
	}

	// The output from curl now contains the full HTTP response (headers and body).
	// We use standard library tools to parse it.
	responseReader := bufio.NewReader(&stdoutBuf)
	tp := textproto.NewReader(responseReader)

	// Read the first line (the status line) e.g., "HTTP/1.1 200 OK"
	statusLine, err := tp.ReadLine()
	if err != nil {
		log.Printf("Could not read status line from curl response: %v", err)
		http.Error(w, "Could not read status line from curl", http.StatusBadGateway)
		return
	}

	// Parse the status code from the status line.
	parts := strings.SplitN(statusLine, " ", 3)
	if len(parts) < 2 {
		log.Printf("Could not parse status line from curl: '%s'", statusLine)
		http.Error(w, "Could not parse status line from curl", http.StatusBadGateway)
		return
	}

	statusCode, err := strconv.Atoi(parts[1])
	if err != nil {
		log.Printf("Could not parse status code from curl status line ('%s'): %v", parts[1], err)
		http.Error(w, "Could not parse status code from curl", http.StatusBadGateway)
		return
	}

	log.Printf("curl finished with status code: %d", statusCode)

	// Read the MIME headers from the curl response.
	mimeHeader, err := tp.ReadMIMEHeader()
	if err != nil {
		log.Printf("Could not read headers from curl response: %v", err)
		http.Error(w, "Could not read headers from curl", http.StatusBadGateway)
		return
	}

	// Copy the parsed headers to our response writer.
	for key, values := range mimeHeader {
		for _, value := range values {
			w.Header().Add(key, value)
		}
	}

	// Write the status code header. This must be done after setting all other headers.
	w.WriteHeader(statusCode)

	// The rest of the buffer is the body. Stream it to the response writer.
	_, err = io.Copy(w, responseReader)
	if err != nil {
		log.Printf("Error copying response body from curl: %v", err)
	}
}

func main() {
	// The address and port for our local proxy server to listen on.
	listenAddr := "127.0.0.1:8888"

	// Register our handler function for all incoming requests.
	http.HandleFunc("/", proxyHandler)

	// Start the server with clearer instructions.
	fmt.Printf("Starting curl-based Go proxy on %s\n", listenAddr)
	fmt.Printf("Forwarding requests to: %s\n\n", targetProxyURL)
	fmt.Println("--- HOW TO USE ---")
	fmt.Println("1. Make sure 'curl.exe' is in your system's PATH.")
	fmt.Println("2. Keep this terminal open to see request logs.")
	fmt.Println("3. Open a NEW terminal.")
	fmt.Println("4. In the new terminal, set GOPROXY to point to this script:")
	fmt.Println("   On Windows: set GOPROXY=http://" + listenAddr)
	fmt.Println("   On macOS/Linux: export GOPROXY=http://" + listenAddr)
	fmt.Println("5. Run your 'go install' or 'go get' command as normal.")
	fmt.Println("---")

	err := http.ListenAndServe(listenAddr, nil)
	if err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}
}
