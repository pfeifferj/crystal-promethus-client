require "./spec_helper"

describe Prometheus do
  before_each do
    Prometheus.clear
  end

  describe "Counter" do
    it "increments value" do
      counter = Prometheus.counter("test_counter", "A test counter")
      counter.inc
      counter.value.should eq(1.0)
      counter.inc(2)
      counter.value.should eq(3.0)
    end

    it "prevents negative increments" do
      counter = Prometheus.counter("test_counter", "A test counter")
      expect_raises(ArgumentError) do
        counter.inc(-1)
      end
    end
  end

  describe "Gauge" do
    it "sets value" do
      gauge = Prometheus.gauge("test_gauge", "A test gauge")
      gauge.set(5)
      gauge.value.should eq(5.0)
    end

    it "increments and decrements value" do
      gauge = Prometheus.gauge("test_gauge", "A test gauge")
      gauge.inc(2)
      gauge.value.should eq(2.0)
      gauge.dec(1)
      gauge.value.should eq(1.0)
    end
  end

  describe "Histogram" do
    it "observes values in buckets" do
      buckets = [1.0, 2.0, 5.0]
      histogram = Prometheus.histogram("test_histogram", "A test histogram", buckets)
      
      histogram.observe(1.5)
      histogram.observe(2.5)
      histogram.observe(4.5)

      samples = histogram.collect
      
      # Check bucket counts
      samples.find { |s| s.name == "test_histogram_bucket" && s.labels.labels["le"] == "1.0" }.try(&.value).should eq(0)
      samples.find { |s| s.name == "test_histogram_bucket" && s.labels.labels["le"] == "2.0" }.try(&.value).should eq(1)
      samples.find { |s| s.name == "test_histogram_bucket" && s.labels.labels["le"] == "5.0" }.try(&.value).should eq(3)
      
      # Check sum and count
      samples.find { |s| s.name == "test_histogram_sum" }.try(&.value).should eq(8.5)
      samples.find { |s| s.name == "test_histogram_count" }.try(&.value).should eq(3)
    end
  end

  describe "Summary" do
    it "tracks count and sum" do
      summary = Prometheus.summary("test_summary", "A test summary")
      
      summary.observe(2.0)
      summary.observe(4.0)
      summary.observe(6.0)

      samples = summary.collect
      
      samples.find { |s| s.name == "test_summary_sum" }.try(&.value).should eq(12.0)
      samples.find { |s| s.name == "test_summary_count" }.try(&.value).should eq(3)
    end
  end

  describe "Registry" do
    it "collects metrics in Prometheus text format" do
      counter = Prometheus.counter("test_counter", "A test counter")
      counter.inc(5)

      output = Prometheus.collect
      output.should contain("# HELP test_counter A test counter\n")
      output.should contain("# TYPE test_counter counter\n")
      output.should contain("test_counter 5")
    end

    it "handles labels correctly" do
      labels = Prometheus::LabelSet.new({"handler" => "test"})
      counter = Prometheus.counter("http_requests_total", "Total HTTP requests", labels)
      counter.inc

      output = Prometheus.collect
      output.should contain("http_requests_total{handler=\"test\"} 1")
    end
  end
end
