package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"sort"
	"strconv"
	"strings"
	"syscall"
)

const logFilePath = "/var/log/nginx/proxy_access.log"

type Metrics struct {
	BandwidthUsage string `json:"bandwidth_usage"`
	TopSites       []Site `json:"top_sites"`
}

type Site struct {
	URL    string `json:"url"`
	Visits int    `json:"visits"`
}

func calculateMetrics() Metrics {
	fmt.Println("Calculating metrics")

	file, err := os.Open(logFilePath)
	if err != nil {
		fmt.Println("Error opening log file:", err)
		return Metrics{BandwidthUsage: "0MB", TopSites: []Site{}}
	}
	defer file.Close()

	var totalBandwidth int
	siteVisits := make(map[string]int)

	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := scanner.Text()

		parts := strings.Split(line, ",")

		if len(parts) < 4 {
			continue
		}

		url := parts[3]
		status, err := strconv.Atoi(parts[1])
		bytesSent, err := strconv.Atoi(parts[2])

		if err != nil {
			fmt.Println(err)
			continue
		}

		// Most likely is a redirect or error status
		// so don't record it in the metrics
		if status != 200 {
			continue
		}

		totalBandwidth += bytesSent
		siteVisits[url]++
	}

	bandwidthMB := float64(totalBandwidth) / (1024 * 1024)

	var topSites []Site
	for url, visits := range siteVisits {
		topSites = append(topSites, Site{URL: url, Visits: visits})
	}

	sort.Slice(topSites, func(i, j int) bool {
		return topSites[i].Visits > topSites[j].Visits
	})

	if len(topSites) > 5 {
		topSites = topSites[:5]
	}

	return Metrics{
		BandwidthUsage: fmt.Sprintf("%.2fMB", bandwidthMB),
		TopSites:       topSites,
	}
}

func metricsHandler(w http.ResponseWriter, r *http.Request) {
	metrics := calculateMetrics()
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(metrics)
}

func main() {

	// Print metrics on graceful shutdown
	sigc := make(chan os.Signal, 1)
	signal.Notify(sigc,
		syscall.SIGHUP,
		syscall.SIGINT,
		syscall.SIGTERM,
		syscall.SIGQUIT)
	go func() {
		_ = <-sigc
		fmt.Println("\n")
		metrics := calculateMetrics()
		data, err := json.MarshalIndent(metrics, "", "  ")
		if err != nil {
			fmt.Println("\nIssue calculating metrics\n")
		}
		fmt.Printf("\n%v\n", string(data))
	}()

	http.HandleFunc("/metrics", metricsHandler)
	fmt.Println("Metrics server running on port 9090...")
	http.ListenAndServe(":9090", nil)
}
