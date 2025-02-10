
# Proxy Server

A little while ago I saw a post on Reddit asking people how they
would solve [this question](challenge.md) in under an hour. I had played around
with Nginx a few years ago and thought this would be a good opportunity to brush
up on it—along with Go too.

## Usage
Before you start, getting the project up and running is pretty simple.

1. **Create your authentication file** - [apache2-utils](https://pkgs.alpinelinux.org/package/edge/main/x86/apache2-utils)
   provides the [htpasswd](https://httpd.apache.org/docs/2.4/programs/htpasswd.html) command to create the `.htpasswd` file. Move this
   file to the `proxy` folder so that Docker can copy it into its build.
2. **Build the container image** - run `docker build -t <your-image-name> .` to
   build the image with your authentication details.
3. **Run it** - run your Docker image, making sure to allow access through the
   port `8080`.

Now you should be able to use the proxy. To use it with [cURL](https://curl.se/), check out the
command below.

```bash
curl -x http://localhost:8080 -u username:password -L <your_url>
```

To view metrics, simply visit `http://localhost:8080/metrics`. A summary of the
metrics will also be displayed on shutdown.
### Common Issues

Note that if you get redirected, cURL will follow the response location
header, but it will fail to retrieve the subsequent response as it does not
store the authentication credentials between redirects. It will most like appear
as a `401` response from Nginx. To fix the issue, add `--location-trusted` as a
flag on your cURL request. This will allow the Nginx instance to hold on to the
credentials for the redirect. 

## How it works

[Nginx](https://nginx.org/) is used for the proxy. The service creates a log of
the bandwidth usage and site analytics. This log is then parsed by a Golang
service, which provides the overall metrics.

There were a lot of considerations that went into this implementation. [Squid
Cache](https://www.squid-cache.org/) or [Apache HTTP
Server](https://httpd.apache.org/) may have also been viable choices,
especially as they have more native support for proxying than Nginx does. Though
Nginx is much easier to setup (biased).

## Areas of improvement

**Metrics aggregation** - when a request is sent for the metrics endpoint,
the Go backend reads the entire log file of the Nginx proxy and calculates the
bandwidth/analytics. This is not ideal for a few reasons. 
1. When the file is being read, writing to the file becomes blocked. Under high
   load this would obviously be pretty bad.
2. The whole file is parsed each request. This repeats a large computation that
   could be saved by just parsing the new log lines since it last read the log
   file.

**Proxy `Connect` method (in the works)** - the proxy `Connect` method more
directly and securely forwards the requests through the proxy server. There are
many benefits to using this method for proxying described [here](https://developer.mozilla.org/en-US/docs/Web/HTTP/Methods/CONNECT).