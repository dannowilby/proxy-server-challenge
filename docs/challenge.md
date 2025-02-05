# Requirements

1. Implement a proxy server that supports basic authentication via
   username/password
2. Track and report bandwidth usage and most visited sites through two
   interfaces:
    * Real-time metrics endpoint (`GET /metrics`)
    * Final summary when the server shuts down

## Core func.

* The server should be able to handle HTTP/HTTPS traffic
* Should support the usage pattern: `curl -x http://proxy_server:proxy_port --proxy-user username:password -L <http://url>`.
* `/metrics` should return the following JSON.
```json
{
    "bandwidth_usage": "125MB",
    "top_sites": [
        { "url": "example.com", "visits": 10 },
        { "url": "google.com", "visits": 5 }
    ]
}
```
* When shut down gracefully, output total bandwidth and most visisted sites