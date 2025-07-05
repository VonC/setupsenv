package main

import (
	"bytes"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"os"
	"os/exec"
	"strconv"
	"strings"
)

// targetProxyURL is the base URL of the actual Go module proxy we want to use.
const targetProxyURL = "https://goproxy.io"

// commonBrowserHeaders are sent with every curl request to bypass bot detection services like Cloudflare.
// This is a more comprehensive set to better mimic a real browser.
var commonBrowserHeaders = []string{
	"User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36",
	"Accept-Language: en-US,en;q=0.9",
	"Sec-Ch-Ua: \"Chromium\";v=\"128\", \"Not;A=Brand\";v=\"24\"",
	"Sec-Ch-Ua-Mobile: ?0",
	"Sec-Ch-Ua-Platform: \"Windows\"",
	"Sec-Fetch-Dest: document",
	"Sec-Fetch-Mode: navigate",
	"Sec-Fetch-Site: none",
	"Sec-Fetch-User: ?1",
	"Upgrade-Insecure-Requests: 1",
}

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
	fullTargetURL := targetURL.String()

	log.Printf("Proxying request via curl: %s\n", fullTargetURL)

	// Route to the appropriate handler based on file type.
	if strings.HasSuffix(fullTargetURL, ".zip") {
		handleBinaryDownload(w, fullTargetURL, "application/zip")
	} else {
		// Handles .info, .mod, and list responses
		handleTextDownload(w, fullTargetURL)
	}
}

// handleTextDownload handles fetching text-based content like .mod, .info, or version lists.
func handleTextDownload(w http.ResponseWriter, url string) {
	// Create a temporary file to store the downloaded content.
	tmpFile, err := os.CreateTemp("", "goproxy-*.txt")
	if err != nil {
		log.Printf("Failed to create temporary file: %v", err)
		http.Error(w, "Failed to create temporary file", http.StatusInternalServerError)
		return
	}
	defer os.Remove(tmpFile.Name())
	defer tmpFile.Close()

	// Build the curl command arguments with browser headers.
	// Add -v to get verbose output on stderr for debugging.
	args := []string{"-s", "-L", "-v", "-w", "%{http_code}", "-o", tmpFile.Name()}
	for _, h := range commonBrowserHeaders {
		args = append(args, "-H", h)
	}
	// Add a specific Accept header for text/html content.
	args = append(args, "-H", "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9")
	args = append(args, url)

	cmd := exec.Command("curl.exe", args...)
	var stdoutBuf, stderrBuf bytes.Buffer
	cmd.Stdout = &stdoutBuf
	cmd.Stderr = &stderrBuf

	if err := cmd.Run(); err != nil {
		log.Printf("Failed to execute curl command: %v\nStderr: %s", err, stderrBuf.String())
		http.Error(w, "Failed to execute curl", http.StatusInternalServerError)
		return
	}

	// The status code is now the only thing in stdout.
	statusCodeStr := strings.TrimSpace(stdoutBuf.String())
	statusCode, err := strconv.Atoi(statusCodeStr)
	if err != nil {
		log.Printf("Could not parse status code from curl stdout ('%s'): %v", statusCodeStr, err)
		http.Error(w, "Could not parse status code from curl", http.StatusBadGateway)
		return
	}

	log.Printf("curl (text) finished with status code: %d", statusCode)

	// If the download failed, forward the error status code.
	if statusCode != http.StatusOK {
		// Log verbose output on 403 Forbidden
		if statusCode == http.StatusForbidden {
			log.Printf("==== CURL VERBOSE OUTPUT ON 403 FORBIDDEN (TEXT) ====\n%s\n============================================", stderrBuf.String())
		}
		w.WriteHeader(statusCode)
		return
	}

	// If the status is OK, stream the body from the temp file.
	if _, err := tmpFile.Seek(0, 0); err != nil {
		log.Printf("Failed to seek temp file: %v", err)
		http.Error(w, "Failed to seek temp file", http.StatusInternalServerError)
		return
	}
	if _, err := io.Copy(w, tmpFile); err != nil {
		log.Printf("Error copying text response body from curl: %v", err)
	}
}

// handleBinaryDownload handles fetching binary .zip files.
func handleBinaryDownload(w http.ResponseWriter, url string, contentType string) {
	// Create a temporary file to store the downloaded zip.
	tmpFile, err := os.CreateTemp("", "goproxy-*.zip")
	if err != nil {
		log.Printf("Failed to create temporary file: %v", err)
		http.Error(w, "Failed to create temporary file", http.StatusInternalServerError)
		return
	}
	defer os.Remove(tmpFile.Name())
	defer tmpFile.Close()

	// Build the curl command arguments with browser headers.
	// Add -v to get verbose output on stderr for debugging.
	args := []string{"-s", "-L", "-v", "-w", "%{http_code}", "-o", tmpFile.Name()}
	for _, h := range commonBrowserHeaders {
		args = append(args, "-H", h)
	}
	// Add a comprehensive Accept header to mimic a browser for binary files as well.
	args = append(args, "-H", "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9")
	args = append(args, url)

	cmd := exec.Command("curl.exe", args...)
	var stdoutBuf, stderrBuf bytes.Buffer
	cmd.Stdout = &stdoutBuf
	cmd.Stderr = &stderrBuf

	if err := cmd.Run(); err != nil {
		log.Printf("Failed to execute curl command for zip: %v\nStderr: %s", err, stderrBuf.String())
		http.Error(w, "Failed to execute curl for zip", http.StatusInternalServerError)
		return
	}

	statusCodeStr := strings.TrimSpace(stdoutBuf.String())
	statusCode, err := strconv.Atoi(statusCodeStr)
	if err != nil {
		log.Printf("Could not parse status code from curl stdout ('%s'): %v", statusCodeStr, err)
		http.Error(w, "Could not parse status code from curl", http.StatusBadGateway)
		return
	}

	log.Printf("curl (zip) finished with status code: %d", statusCode)

	// If the download failed, forward the error status code.
	if statusCode != http.StatusOK {
		// Log verbose output on 403 Forbidden
		if statusCode == http.StatusForbidden {
			log.Printf("==== CURL VERBOSE OUTPUT ON 403 FORBIDDEN (ZIP) ====\n%s\n============================================", stderrBuf.String())
		}
		w.WriteHeader(statusCode)
		return
	}

	fileInfo, err := tmpFile.Stat()
	if err != nil {
		log.Printf("Failed to get temp file stats: %v", err)
		http.Error(w, "Failed to get temp file stats", http.StatusInternalServerError)
		return
	}

	// Set headers for the zip file response.
	w.Header().Set("Content-Type", contentType)
	w.Header().Set("Content-Length", strconv.FormatInt(fileInfo.Size(), 10))
	w.WriteHeader(http.StatusOK)

	if _, err := tmpFile.Seek(0, 0); err != nil {
		log.Printf("Failed to seek temp file: %v", err)
		http.Error(w, "Failed to seek temp file", http.StatusInternalServerError)
		return
	}

	if _, err := io.Copy(w, tmpFile); err != nil {
		log.Printf("Error copying zip file response body: %v", err)
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
