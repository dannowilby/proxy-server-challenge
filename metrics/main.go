package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"reflect"
	"sort"
	"strconv"
	"strings"
)

const logFilePath = "/var/log/squid/access.log"

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

		// Extract URL and bytes sent
		parts := strings.Split(line, " ")

		fmt.Println(len(parts))

		if len(parts) < 9 {
			continue
		}

		fmt.Println(parts)
		fmt.Println(reflect.TypeOf(parts[6]))

		url := parts[6] // Request path
		bytesSent, err := strconv.Atoi(parts[6])

		fmt.Println(bytesSent)

		if err != nil {
			fmt.Println(err)
			continue
		}

		totalBandwidth += bytesSent
		siteVisits[url]++
	}

	// Convert bandwidth to MB
	bandwidthMB := float64(totalBandwidth) / (1024 * 1024)

	// Sort sites by visits
	var topSites []Site
	for url, visits := range siteVisits {
		topSites = append(topSites, Site{URL: url, Visits: visits})
	}

	sort.Slice(topSites, func(i, j int) bool {
		return topSites[i].Visits > topSites[j].Visits
	})

	// Keep only top 5
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
	http.HandleFunc("/metrics", metricsHandler)
	fmt.Println("Metrics server running on port 9090...")
	http.ListenAndServe(":9090", nil)
}
