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
	"os/user"
	"path/filepath"
	"strconv"
	"strings"
)

// targetProxyURL is the base URL for the module proxy.
const targetProxyURL = "https://proxy.golang.org"

// logFilePath stores the full path to the current log file.
var logFilePath string

// commonBrowserHeaders are sent with every curl request to bypass bot detection services like Cloudflare.
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
	"Connection: keep-alive",
}

// main is the entry point for the application.
func main() {
	// Set up logging to a file before doing anything else.
	setupLogging()

	// Start the HTTP server. This is a blocking call that will keep the program running.
	startHttpServer()
}

// setupLogging configures the log output to go to a file with rotation.
func setupLogging() {
	usr, err := user.Current()
	if err != nil {
		log.Fatalf("Failed to get current user: %v", err)
	}
	logDir := filepath.Join(usr.HomeDir, "go")
	logFilePath = filepath.Join(logDir, "goproxy.log")

	// Ensure the log directory exists.
	if err := os.MkdirAll(logDir, 0755); err != nil {
		log.Fatalf("Failed to create log directory %s: %v", logDir, err)
	}

	// Rotate existing logs.
	if _, err := os.Stat(logFilePath); err == nil {
		// Keep up to 10 old logs.
		for i := 9; i >= 0; i-- {
			var oldPath, newPath string
			if i == 0 {
				oldPath = logFilePath
			} else {
				oldPath = fmt.Sprintf("%s.%d", logFilePath, i)
			}
			newPath = fmt.Sprintf("%s.%d", logFilePath, i+1)

			if _, err := os.Stat(oldPath); err == nil {
				if i == 9 { // Remove the oldest log
					if err := os.Remove(newPath); err != nil && !os.IsNotExist(err) {
						log.Printf("Warning: could not remove oldest log file %s: %v", newPath, err)
					}
				}
				if err := os.Rename(oldPath, newPath); err != nil {
					log.Printf("Warning: could not rotate log file from %s to %s: %v", oldPath, newPath, err)
				}
			}
		}
	}

	// Create and set the new log file as the output for the log package.
	logFile, err := os.OpenFile(logFilePath, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0644)
	if err != nil {
		log.Fatalf("Failed to open log file %s: %v", logFilePath, err)
	}
	// Redirect all log output to this file.
	log.SetOutput(logFile)
	log.Println("Logging configured.")
}

// startHttpServer initializes and runs the main proxy server.
func startHttpServer() {
	listenAddr := "127.0.0.1:8888"
	http.HandleFunc("/", proxyHandler)
	log.Printf("Starting HTTP server on %s", listenAddr)

	// Start the server with clearer instructions.
	fmt.Printf("Starting curl-based Go proxy on %s\n", listenAddr)
	fmt.Printf("Logging to: %s\n", logFilePath)
	fmt.Printf("Forwarding module requests to: %s\n", targetProxyURL)
	fmt.Printf("Forwarding checksum requests to: https://sum.golang.org\n\n")
	fmt.Println("--- HOW TO USE ---")
	fmt.Println("1. Make sure 'curl.exe' is in your system's PATH.")
	fmt.Println("2. Keep this terminal open to see request logs in real-time, or check the log file.")
	fmt.Println("3. Open a NEW terminal.")
	fmt.Println("4. In the new terminal, set BOTH environment variables:")
	fmt.Println("   On Windows:")
	fmt.Println("   set GOPROXY=http://" + listenAddr)
	fmt.Println("   set GOSUMDB=\"sum.golang.org http://" + listenAddr + "/sum.golang.org\"")
	fmt.Println("   On macOS/Linux:")
	fmt.Println("   export GOPROXY=http://" + listenAddr)
	fmt.Println("   export GOSUMDB=\"sum.golang.org http://" + listenAddr + "/sum.golang.org\"")
	fmt.Println("5. Run your 'go install' or 'go get' command as normal.")
	fmt.Println("---")
	fmt.Println("Press Ctrl+C to stop.")

	if err := http.ListenAndServe(listenAddr, nil); err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}
}

// proxyHandler is the core of our proxy. It now intelligently routes requests
// for both the module proxy (GOPROXY) and the checksum database (GOSUMDB).
func proxyHandler(w http.ResponseWriter, r *http.Request) {
	var targetBase string
	var pathForTarget string

	// --- Route GOSUMDB requests ---
	// Check if the request path is for the checksum database.
	if strings.HasPrefix(r.URL.Path, "/sum.golang.org/") {
		targetBase = "https://sum.golang.org"
		// The path sent to the target should not include the hostname part.
		pathForTarget = strings.TrimPrefix(r.URL.Path, "/sum.golang.org")
	} else {
		// Otherwise, it's a normal module proxy request.
		targetBase = targetProxyURL
		pathForTarget = r.URL.Path
	}

	// Construct the full target URL for curl to fetch.
	targetURL, err := url.Parse(targetBase)
	if err != nil {
		log.Printf("Internal error: Failed to parse base proxy URL: %v", err)
		http.Error(w, "Internal proxy configuration error", http.StatusInternalServerError)
		return
	}
	targetURL.Path = pathForTarget
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
	defer func() {
		if err := os.Remove(tmpFile.Name()); err != nil {
			log.Printf("Warning: failed to remove temporary file %s: %v", tmpFile.Name(), err)
		}
	}()
	defer func() {
		if err := tmpFile.Close(); err != nil {
			log.Printf("Warning: failed to close temporary file %s: %v", tmpFile.Name(), err)
		}
	}()

	// Build the curl command arguments with browser headers.
	// -s: Silent mode (no progress meter).
	// -L: Follow redirects.
	// -v: Verbose output (for debugging headers).
	// -w "%{http_code}": Write the final HTTP status code to stdout.
	// -o <file>: Write the response body content to a file.
	args := []string{"-s", "-L", "-v", "-w", "%{http_code}", "-o", tmpFile.Name()}
	for _, h := range commonBrowserHeaders {
		args = append(args, "-H", h)
	}
	args = append(args, "-H", "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9")
	args = append(args, url)

	cmd := exec.Command("curl.exe", args...)
	var stdoutBuf, stderrBuf bytes.Buffer
	cmd.Stdout = &stdoutBuf // Capture status code here
	cmd.Stderr = &stderrBuf // Capture verbose output here

	// Run the curl command.
	if err := cmd.Run(); err != nil {
		log.Printf("Failed to execute curl command: %v\nStderr: %s", err, stderrBuf.String())
		http.Error(w, "Failed to execute curl", http.StatusInternalServerError)
		return
	}

	// The status code is the only thing written to stdout by the -w flag.
	statusCodeStr := strings.TrimSpace(stdoutBuf.String())
	statusCode, err := strconv.Atoi(statusCodeStr)
	if err != nil {
		log.Printf("Could not parse status code from curl stdout ('%s'): %v", statusCodeStr, err)
		http.Error(w, "Could not parse status code from curl", http.StatusBadGateway)
		return
	}

	log.Printf("curl (text) finished with status code: %d", statusCode)

	// If the download failed, forward the error status code and log verbose output if needed.
	if statusCode != http.StatusOK {
		if statusCode == http.StatusForbidden {
			log.Printf("==== CURL VERBOSE OUTPUT ON 403 FORBIDDEN (TEXT) ====\n%s\n============================================", stderrBuf.String())
		}
		w.WriteHeader(statusCode)
		return
	}

	// If the status is OK, stream the body from the temp file.
	// Seek to the beginning of the file before copying.
	if _, err := tmpFile.Seek(0, 0); err != nil {
		log.Printf("Failed to seek temp file: %v", err)
		http.Error(w, "Failed to seek temp file", http.StatusInternalServerError)
		return
	}
	// Copy the file content to the response writer.
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
	defer func() {
		if err := os.Remove(tmpFile.Name()); err != nil {
			log.Printf("Warning: failed to remove temporary file %s: %v", tmpFile.Name(), err)
		}
	}()
	defer func() {
		if err := tmpFile.Close(); err != nil {
			log.Printf("Warning: failed to close temporary file %s: %v", tmpFile.Name(), err)
		}
	}()

	// Build the curl command arguments with browser headers.
	// -s: Silent mode (no progress meter).
	// -L: Follow redirects.
	// -v: Verbose output (for debugging headers).
	// -w "%{http_code}": Write the final HTTP status code to stdout.
	// -o <file>: Write the response body content to a file.
	args := []string{"-s", "-L", "-v", "-w", "%{http_code}", "-o", tmpFile.Name()}
	for _, h := range commonBrowserHeaders {
		args = append(args, "-H", h)
	}
	args = append(args, "-H", "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9")
	args = append(args, url)

	cmd := exec.Command("curl.exe", args...)
	var stdoutBuf, stderrBuf bytes.Buffer
	cmd.Stdout = &stdoutBuf // Capture status code here
	cmd.Stderr = &stderrBuf // Capture verbose output here

	// Run the curl command.
	if err := cmd.Run(); err != nil {
		log.Printf("Failed to execute curl command for zip: %v\nStderr: %s", err, stderrBuf.String())
		http.Error(w, "Failed to execute curl for zip", http.StatusInternalServerError)
		return
	}

	// The status code is the only thing written to stdout by the -w flag.
	statusCodeStr := strings.TrimSpace(stdoutBuf.String())
	statusCode, err := strconv.Atoi(statusCodeStr)
	if err != nil {
		log.Printf("Could not parse status code from curl stdout ('%s'): %v", statusCodeStr, err)
		http.Error(w, "Could not parse status code from curl", http.StatusBadGateway)
		return
	}

	log.Printf("curl (zip) finished with status code: %d", statusCode)

	// If the download failed, forward the error status code and log verbose output if needed.
	if statusCode != http.StatusOK {
		if statusCode == http.StatusForbidden {
			log.Printf("==== CURL VERBOSE OUTPUT ON 403 FORBIDDEN (ZIP) ====\n%s\n============================================", stderrBuf.String())
		}
		w.WriteHeader(statusCode)
		return
	}

	// Get file info to set the Content-Length header, which is good practice.
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
