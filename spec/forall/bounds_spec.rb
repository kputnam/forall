# frozen_string_literal: true

describe Forall::Bounds do
  using Forall::Refinements
  include Forall::RSpecHelpers
  include Forall::RSpecHelpers::Bounds

  before do
    @size  = Forall::Random.integer(0..99)
    @range =
      Forall::Random.integer(0..500).flat_map do |a|
        Forall::Random.integer(0..500).map do |b|
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
      @value     = Forall::Random.integer(0..500)
      @singleton = @value.map{|x| Forall::Bounds.singleton(x) }
    end

    it "bounds do not depend on size" do
      forall(Forall::Random.sequence(@singleton, @size)) do |singleton, size|
        expect(singleton.range(size)).to eq(singleton.range(0))
      end
    end

    it "lower and upper bounds are equal" do
      forall(Forall::Random.sequence(@value, @size)) do |value, size|
        expect(Forall::Bounds.singleton(value).range(size)).to eq(value..value)
      end
    end
  end

  describe ".constant" do
    it "bounds do not depend on size" do
      forall(Forall::Random.sequence(@range, @size)) do |range, size|
        expect(Forall::Bounds.constant(range).range(size)).to eq(range)
      end
    end
  end

  describe ".linear" do
    before do
      @origin = Forall::Random.float(0..1)
    end

    it "bounds grow linearly with size" do
      forall(Forall::Random.sequence(@range_to_f.filter{|r| r.begin != r.end }, @origin)) do |range, scale|
        origin = range.begin + (scale * (range.end - range.begin))
        linear = Forall::Bounds.linear(range, origin: origin)

        expect(100.times.map{|size| linear.begin(size) }).to be_linear(0.99)
        expect(100.times.map{|size| linear.end(size)   }).to be_linear(0.99)
      end
    end
  end

  describe ".exponential" do
    before do
      @origin = Forall::Random.float(0..1)
    end

    pending "bounds grow exponentially with size" do
      forall(Forall::Random.sequence(@range_to_f.filter{|r| r.begin != r.end }, @origin)) do |range, scale|
        origin      = range.begin + (scale * (range.end - range.begin))
        exponential = Forall::Bounds.exponential(range, origin: origin)

        expect(100.times.map{|size| exponential.begin(size) }).to be_exponential(0.9)
        expect(100.times.map{|size| exponential.end(size)   }).to be_exponential(0.9)
      end
    end
  end

  describe "#begin" do
    it "returns bounds(size).begin" do
      forall(Forall::Random.sequence(@range, @size)) do |range, size|
        bounds = Forall::Bounds.linear(range)
        expect(bounds.begin(size)).to eq(bounds.range(size).begin)
      end
    end
  end

  describe "#end" do
    it "returns bounds(size).end" do
      forall(Forall::Random.sequence(@range, @size)) do |range, size|
        bounds = Forall::Bounds.linear(range)
        expect(bounds.end(size)).to eq(bounds.range(size).end)
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
