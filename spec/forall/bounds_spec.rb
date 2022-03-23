# frozen_string_literal: true

describe Forall::Bounds do
  using Forall::Refinements
  include Forall::RSpecHelpers
  include Forall::RSpecHelpers::Bounds
  include Forall::RSpecHelpers::Random

  before do
    @size  = random.integer(0..99)
    @range =
      random.integer(0..500).flat_map do |a|
        random.integer(0..500).map do |b|
          if a < b
            a..b
          else
            b..a
          end
        end
      end.rename("range(0..500)")

    @range_to_f = @range.map{|r| r.map(&:to_f) }.rename("range(0.0..500.0)")
  end

  describe ".singleton" do
    before do
      @value     = random.integer(0..500)
      @singleton = @value.map{|x| bounds.singleton(x) }
    end

    it "bounds do not depend on size" do
      forall(random.sequence(@singleton, @size)) do |singleton, size|
        expect(singleton.range(size)).to eq(singleton.range(0))
      end
    end

    it "lower and upper bounds are equal" do
      forall(random.sequence(@value, @size)) do |value, size|
        expect(bounds.singleton(value).range(size)).to eq(value..value)
      end
    end
  end

  describe ".constant" do
    it "bounds do not depend on size" do
      forall(random.sequence(@range, @size)) do |range, size|
        expect(bounds.constant(range).range(size)).to eq(range)
      end
    end
  end

  describe ".linear" do
    before do
      @origin = random.float(0..1)
    end

    it "bounds grow linearly with size" do
      forall(random.sequence(@range_to_f.filter{|r| r.begin != r.end }, @origin)) do |range, scale|
        origin = range.begin + (scale * (range.end - range.begin))
        linear = bounds.linear(range, origin: origin)

        expect(100.times.map{|size| linear.begin(size) }).to be_linear(0.99)
        expect(100.times.map{|size| linear.end(size)   }).to be_linear(0.99)
      end
    end
  end

  describe ".exponential" do
    before do
      @origin = random.float(0..1)
    end

    pending "bounds grow exponentially with size" do
      forall(random.sequence(@range_to_f.filter{|r| r.begin != r.end }, @origin)) do |range, scale|
        origin      = range.begin + (scale * (range.end - range.begin))
        exponential = bounds.exponential(range, origin: origin)

        expect(100.times.map{|size| exponential.begin(size) }).to be_exponential(0.9)
        expect(100.times.map{|size| exponential.end(size)   }).to be_exponential(0.9)
      end
    end
  end

  describe "#begin" do
    it "returns bounds(size).begin" do
      forall(random.sequence(@range, @size)) do |range, size|
        bounds_ = bounds.linear(range)
        expect(bounds_.begin(size)).to eq(bounds_.range(size).begin)
      end
    end
  end

  describe "#end" do
    it "returns bounds(size).end" do
      forall(random.sequence(@range, @size)) do |range, size|
        bounds_ = bounds.linear(range)
        expect(bounds_.end(size)).to eq(bounds_.range(size).end)
      end
    end
  end

  describe "#origin" do
    it "returns value given to constructor" do
    end
  end

  describe ".coerce" do
    context "when range has mismatched types" do
    end

    context "when range is Integer..Integer" do
    end

    context "when range is Float..Float" do
    end

    context "when range is Date..Date" do
    end

    context "when range is Char..Char" do
    end

    context "when range is Time..Time" do
    end

    context "when range is Range..Range" do
    end

    context "when range is other type" do
    end
  end
end
