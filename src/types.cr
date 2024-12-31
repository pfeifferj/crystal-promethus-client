# Core data model types for the Prometheus client library.
module Prometheus
  # A Label represents a key-value pair used to identify a metric.
  #
  # Labels are used to distinguish different dimensions of a metric. For example,
  # an HTTP request counter might have labels for the method and path.
  #
  # ```crystal
  # label = Label.new("method", "GET")
  # ```
  #
  # Label names must match the regex `[a-zA-Z_][a-zA-Z0-9_]*` and cannot be empty.
  # Label values cannot be empty.
  class Label
    getter name : String
    getter value : String

    def initialize(@name : String, @value : String)
      validate_name
      validate_value
    end

    private def validate_name
      raise ArgumentError.new("Label name cannot be empty") if @name.empty?
      raise ArgumentError.new("Invalid label name: #{@name}") unless @name =~ /^[a-zA-Z_][a-zA-Z0-9_]*$/
    end

    private def validate_value
      raise ArgumentError.new("Label value cannot be empty") if @value.empty?
    end
  end

  # LabelSet represents a collection of labels that uniquely identify a metric.
  #
  # A LabelSet is used to attach multiple labels to a metric, enabling Prometheus's
  # dimensional data model.
  #
  # ```crystal
  # labels = LabelSet.new({
  #   "method" => "GET",
  #   "path" => "/api/users"
  # })
  # ```
  #
  # LabelSets can be merged to combine labels from different sources:
  #
  # ```crystal
  # base_labels = LabelSet.new({"service" => "web"})
  # request_labels = LabelSet.new({"method" => "GET"})
  # combined = base_labels.merge(request_labels)
  # ```
  class LabelSet
    getter labels : Hash(String, String)

    def initialize(@labels = Hash(String, String).new)
    end

    def add(name : String, value : String)
      @labels[name] = value
    end

    def merge(other : LabelSet)
      LabelSet.new(@labels.merge(other.labels))
    end

    def to_s(io : IO)
      return if @labels.empty?
      
      first = true
      io << "{"
      @labels.each do |name, value|
        io << "," unless first
        first = false
        io << "#{name}=\"#{value}\""
      end
      io << "}"
    end
  end

  # Base class for all metric types (Counter, Gauge, Histogram, Summary).
  #
  # This abstract class defines the common interface and behavior for all metrics:
  # * Each metric has a name, help text, and optional labels
  # * Names must match the regex `[a-zA-Z_:][a-zA-Z0-9_:]*`
  # * Each metric type must implement `type` and `collect` methods
  #
  # Metric implementations should be thread-safe and handle concurrent access appropriately.
  abstract class Metric
    getter name : String
    getter help : String
    getter labels : LabelSet

    def initialize(@name : String, @help : String, @labels = LabelSet.new)
      validate_name
    end

    private def validate_name
      raise ArgumentError.new("Metric name cannot be empty") if @name.empty?
      raise ArgumentError.new("Invalid metric name: #{@name}") unless @name =~ /^[a-zA-Z_:][a-zA-Z0-9_:]*$/
    end

    abstract def type : String
    abstract def collect : Array(Sample)
  end

  # Represents a single sample value at a point in time.
  #
  # A Sample combines:
  # * A metric name
  # * A set of labels
  # * A numeric value
  # * An optional timestamp
  #
  # Samples are used to represent the actual data points collected by metrics.
  # The Sample format follows the Prometheus exposition format:
  #
  # ```text
  # metric_name{label="value"} 42
  # # Or with timestamp:
  # metric_name{label="value"} 42 1234567890
  # ```
  class Sample
    getter name : String
    getter labels : LabelSet
    getter value : Float64
    getter timestamp : Int64?

    def initialize(@name : String, @labels : LabelSet, @value : Float64, @timestamp : Int64? = nil)
    end

    def to_s(io : IO)
      io << @name
      io << @labels
      io << " "
      io << @value
      if timestamp = @timestamp
        io << " "
        io << timestamp
      end
    end
  end
end
