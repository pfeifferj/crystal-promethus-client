require "./types"

# Implementation of Prometheus metric types.
module Prometheus
  # A Counter is a cumulative metric that represents a single monotonically increasing counter
  # whose value can only increase or be reset to zero.
  #
  # Use a Counter for metrics that accumulate values, such as:
  # * Number of requests served
  # * Number of tasks completed
  # * Number of errors
  #
  # Example:
  # ```crystal
  # counter = Counter.new("http_requests_total", "Total HTTP requests")
  # counter.inc      # Increment by 1
  # counter.inc(5)   # Increment by 5
  # ```
  #
  # NOTE: Counter values cannot decrease. Use a Gauge for values that can go up and down.
  class Counter < Metric
    @value : Float64 = 0.0
    @mutex = Mutex.new

    def type : String
      "counter"
    end

    def inc(value : Number = 1)
      raise ArgumentError.new("Counter increment must be positive") if value < 0
      @mutex.synchronize do
        @value += value.to_f64
      end
    end

    def value : Float64
      @mutex.synchronize { @value }
    end

    def collect : Array(Sample)
      [Sample.new(@name, @labels, value)]
    end
  end

  # A Gauge is a metric that represents a single numerical value that can arbitrarily go up and down.
  #
  # Use a Gauge for metrics that can increase and decrease, such as:
  # * Current memory usage
  # * Number of items in a queue
  # * Number of active connections
  #
  # Example:
  # ```crystal
  # gauge = Gauge.new("cpu_usage", "CPU usage percentage")
  # gauge.set(45.2)  # Set to specific value
  # gauge.inc(5)     # Increase by 5
  # gauge.dec(3)     # Decrease by 3
  # ```
  class Gauge < Metric
    @value : Float64 = 0.0
    @mutex = Mutex.new

    def type : String
      "gauge"
    end

    def set(value : Number)
      @mutex.synchronize do
        @value = value.to_f64
      end
    end

    def inc(value : Number = 1)
      @mutex.synchronize do
        @value += value.to_f64
      end
    end

    def dec(value : Number = 1)
      @mutex.synchronize do
        @value -= value.to_f64
      end
    end

    def value : Float64
      @mutex.synchronize { @value }
    end

    def collect : Array(Sample)
      [Sample.new(@name, @labels, value)]
    end
  end

  # A Histogram samples observations (usually things like request durations or response sizes)
  # and counts them in configurable buckets.
  #
  # Use a Histogram to track size distributions, such as:
  # * Request duration
  # * Response sizes
  # * Queue length variations
  #
  # Example:
  # ```crystal
  # # Create with custom buckets
  # histogram = Histogram.new(
  #   "response_time",
  #   "Response time in seconds",
  #   [0.1, 0.5, 1.0, 2.0, 5.0]
  # )
  #
  # # Observe values
  # histogram.observe(0.25)
  # ```
  #
  # Histograms track:
  # * Count per bucket (number of values <= bucket upper bound)
  # * Total sum of all observed values
  # * Count of all observed values
  class Histogram < Metric
    @mutex = Mutex.new
    @sum : Float64 = 0.0
    @count : UInt64 = 0
    @buckets : Hash(Float64, UInt64)

    def initialize(name : String, help : String, buckets : Array(Float64), labels = LabelSet.new)
      super(name, help, labels)
      @buckets = Hash(Float64, UInt64).new(0_u64)
      buckets.sort.each { |upper_bound| @buckets[upper_bound] = 0_u64 }
    end

    def type : String
      "histogram"
    end

    def observe(value : Number)
      value_f64 = value.to_f64
      @mutex.synchronize do
        @sum += value_f64
        @count += 1
        # Update all buckets that have an upper bound greater than or equal to the value
        @buckets.each do |upper_bound, _|
          if value_f64 <= upper_bound
            @buckets[upper_bound] += 1
          end
        end
      end
    end

    def collect : Array(Sample)
      @mutex.synchronize do
        samples = [] of Sample
        
        # Add bucket samples
        @buckets.each do |upper_bound, count|
          bucket_label = @labels.merge(LabelSet.new({"le" => upper_bound.to_s}))
          samples << Sample.new("#{@name}_bucket", bucket_label, count.to_f64)
        end

        # Add +Inf bucket
        inf_label = @labels.merge(LabelSet.new({"le" => "+Inf"}))
        samples << Sample.new("#{@name}_bucket", inf_label, @count.to_f64)

        # Add sum and count metrics
        samples << Sample.new("#{@name}_sum", @labels, @sum)
        samples << Sample.new("#{@name}_count", @labels, @count.to_f64)

        samples
      end
    end
  end

  # A Summary captures individual observations from an event or sample stream
  # and summarizes them with count and sum.
  #
  # Use a Summary for metrics where you need the count and sum, such as:
  # * Request latencies
  # * Request sizes
  # * Response sizes
  #
  # Example:
  # ```crystal
  # summary = Summary.new("request_size", "Request size in bytes")
  # summary.observe(1024)
  # ```
  #
  # Summaries track:
  # * Count of all observed values
  # * Sum of all observed values
  class Summary < Metric
    @mutex = Mutex.new
    @count : UInt64 = 0
    @sum : Float64 = 0.0

    def initialize(name : String, help : String, labels = LabelSet.new)
      super(name, help, labels)
    end

    def type : String
      "summary"
    end

    def observe(value : Number)
      @mutex.synchronize do
        @count += 1
        @sum += value.to_f64
      end
    end

    def collect : Array(Sample)
      @mutex.synchronize do
        [
          Sample.new("#{@name}_sum", @labels, @sum),
          Sample.new("#{@name}_count", @labels, @count.to_f64)
        ]
      end
    end
  end
end
