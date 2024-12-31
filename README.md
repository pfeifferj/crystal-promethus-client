# Prometheus Client for Crystal

A [Prometheus](https://prometheus.io) client library for Crystal following the [official guidelines](https://prometheus.io/docs/instrumenting/writing_clientlibs/).

## Installation

1. Add the dependency to your `shard.yml`:

```yaml
dependencies:
  prometheus:
    github: pfeifferj/prometheus
    version: ~> 0.1.0
```

2. Run `shards install`

## Usage

```crystal
require "prometheus"

# Create metrics
counter = Prometheus.counter("http_requests_total", "Total HTTP requests")
gauge = Prometheus.gauge("cpu_usage", "CPU usage percentage")
histogram = Prometheus.histogram("response_time", "Response time in seconds", [0.1, 0.5, 1.0])
summary = Prometheus.summary("request_size", "Request size in bytes")

# Add labels
labels = Prometheus::LabelSet.new({
  "method" => "GET",
  "handler" => "home"
})
requests = Prometheus.counter("http_requests_total", "Total HTTP requests", labels)

# Use metrics
counter.inc                 # Increment by 1
counter.inc(5)              # Increment by given value
gauge.set(45.2)             # Set to a value
gauge.inc(5)                # Increase by 5
gauge.dec(3)                # Decrease by 3
histogram.observe(0.25)     # Observe a value
summary.observe(1024)       # Observe a value

# Get metrics in Prometheus text format
puts Prometheus.collect
```

## Demo

Check out the [demo application](examples/demo.cr) that showcases all metric types:

```crystal
crystal examples/demo.cr
```

The demo simulates HTTP traffic and demonstrates:

- Counters tracking requests with labels
- Gauges monitoring memory usage
- Histograms measuring response time distributions
- Summaries capturing request size statistics

## Metric Types

### Counter

A counter is a cumulative metric that represents a single monotonically increasing counter whose value can only increase or be reset to zero.

```crystal
counter = Prometheus.counter("http_requests_total", "Total HTTP requests")
counter.inc      # Increment by 1
counter.inc(5)   # Increment by 5
```

### Gauge

A gauge is a metric that represents a single numerical value that can arbitrarily go up and down.

```crystal
gauge = Prometheus.gauge("cpu_usage", "CPU usage percentage")
gauge.set(45.2)  # Set to 45.2
gauge.inc(5)     # Increase by 5
gauge.dec(3)     # Decrease by 3
```

### Histogram

A histogram samples observations (usually things like request durations or response sizes) and counts them in configurable buckets.

```crystal
# Create with custom buckets
histogram = Prometheus.histogram(
  "response_time",
  "Response time in seconds",
  [0.1, 0.5, 1.0, 2.0, 5.0]
)

# Observe values
histogram.observe(0.25)
```

### Summary

A summary captures individual observations from an event or sample stream and summarizes them in a traditional way, with count and sum.

```crystal
summary = Prometheus.summary("request_size", "Request size in bytes")
summary.observe(1024)
```

## Labels

Labels enable Prometheus's dimensional data model. A label set can be attached to any metric:

```crystal
# Create a label set
labels = Prometheus::LabelSet.new({
  "method" => "GET",
  "path" => "/api/users"
})

# Create metric with labels
requests = Prometheus.counter("http_requests_total", "Total HTTP requests", labels)
requests.inc

# Output will include labels:
# http_requests_total{method="GET",path="/api/users"} 1
```

## Registry

The library maintains a default registry that manages all metrics. You can access it directly if needed:

```crystal
# Register a metric manually
Prometheus.register(metric)

# Unregister a metric
Prometheus.unregister("metric_name")

# Clear all metrics
Prometheus.clear

# Get all metrics in Prometheus text format
output = Prometheus.collect
```

## Thread Safety

All metric operations are thread-safe. The library uses mutexes to ensure proper synchronization in concurrent environments.

## Development

Run tests:

```crystal
crystal spec
```

## Contributing

1. Fork it (<https://github.com/pfeifferj/prometheus/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.
