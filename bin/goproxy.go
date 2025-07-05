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

	// --- FINAL APPROACH: Handle .zip files and text files separately to prevent corruption ---
	if strings.HasSuffix(fullTargetURL, ".zip") {
		handleBinaryDownload(w, fullTargetURL, "application/zip")
	} else {
		// Handles .info, .mod, and list responses
		handleTextDownload(w, fullTargetURL)
	}
}

// handleTextDownload handles fetching text-based content like .mod, .info, or version lists.
// It saves the body to a temp file to cleanly separate it from the status code.
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

	// Use curl to download the body to the temp file and write the status code to stdout.
	cmd := exec.Command("curl.exe", "-s", "-L", "-w", "%{http_code}", "-o", tmpFile.Name(), url)
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

	// Write the status code header.
	w.WriteHeader(statusCode)

	// If the status is OK, stream the body from the temp file.
	if statusCode == http.StatusOK {
		// Seek to the beginning of the file before copying.
		if _, err := tmpFile.Seek(0, 0); err != nil {
			log.Printf("Failed to seek temp file: %v", err)
			http.Error(w, "Failed to seek temp file", http.StatusInternalServerError)
			return
		}
		if _, err := io.Copy(w, tmpFile); err != nil {
			log.Printf("Error copying text response body from curl: %v", err)
		}
	}
}

// handleBinaryDownload handles fetching binary .zip files by saving them to a temporary file first.
func handleBinaryDownload(w http.ResponseWriter, url string, contentType string) {
	// Create a temporary file to store the downloaded zip.
	tmpFile, err := os.CreateTemp("", "goproxy-*.zip")
	if err != nil {
		log.Printf("Failed to create temporary file: %v", err)
		http.Error(w, "Failed to create temporary file", http.StatusInternalServerError)
		return
	}
	// Ensure cleanup happens even if there's an error.
	defer os.Remove(tmpFile.Name())
	defer tmpFile.Close()

	// Use curl to download the file directly to the temp file path.
	// -o tells curl to write the output to the specified file.
	cmd := exec.Command("curl.exe", "-s", "-L", "-o", tmpFile.Name(), url)
	var stderrBuf bytes.Buffer
	cmd.Stderr = &stderrBuf

	if err := cmd.Run(); err != nil {
		log.Printf("Failed to execute curl command for zip: %v\nStderr: %s", err, stderrBuf.String())
		http.Error(w, "Failed to execute curl for zip", http.StatusInternalServerError)
		return
	}

	// Get file info to set the Content-Length header, which is good practice.
	fileInfo, err := tmpFile.Stat()
	if err != nil {
		log.Printf("Failed to get temp file stats: %v", err)
		http.Error(w, "Failed to get temp file stats", http.StatusInternalServerError)
		return
	}

	// If the file is empty, it's likely an error (e.g., 404), so return Bad Gateway.
	if fileInfo.Size() == 0 {
		log.Printf("Downloaded zip file is empty. URL was likely not found: %s", url)
		http.Error(w, "Upstream proxy returned an empty file", http.StatusBadGateway)
		return
	}

	log.Printf("curl (zip) finished successfully for %s", url)

	// Set headers for the zip file response.
	w.Header().Set("Content-Type", contentType)
	w.Header().Set("Content-Length", strconv.FormatInt(fileInfo.Size(), 10))
	w.WriteHeader(http.StatusOK)

	// Seek to the beginning of the file before copying.
	if _, err := tmpFile.Seek(0, 0); err != nil {
		log.Printf("Failed to seek temp file: %v", err)
		http.Error(w, "Failed to seek temp file", http.StatusInternalServerError)
		return
	}

	// Stream the file from disk to the response writer.
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
