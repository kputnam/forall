# frozen_string_literal: true

describe Forall::Property do
  using Forall::Refinements
  include Forall::RSpecHelpers::Bounds
  include Forall::RSpecHelpers::Random

  describe "#forall" do
    before do
      zero = Forall::Tree.leaf(0) # minimal counterexample
      one  = Forall::Tree.leaf(1) # not a counterexample
      two  = Forall::Tree.leaf(2) # counterexample
      tree = two.prepend_children([one].cycle.lazy.take(1000) + [zero].each)

      @input  = [one].cycle.lazy.take(100) + [tree].cycle
      @config = Forall::Config.default
    end

    it "increments scale parameter after each test" do
      values = []

      # This executes the property, the result is discarded here
      Forall::Property.new{|n, _| values << n }.forall(random.scale)

      expect(values).to eq([*0..99].cycle.take(@config.min_tests))
    end

    context "when no counterexample is found" do
      before do
        property = Forall::Property.new{|_, _| true }
        @result  = property.forall(@input, config: @config)
      end

      it "reports success" do
        expect(@result).to be_a(Forall::Report::Success)
      end

      it "runs all tests" do
        expect(@result.test_count).to eq(@config.min_tests)
      end
    end

    context "when a counterexample is found" do
      before do
        @property = Forall::Property.new{|x, _| x == 1 }
        @config   = Forall::Config.default.update(min_tests: 101)
      end

      it "reports a failure" do
        result = @property.forall(@input, config: @config)
        expect(result).to be_a(Forall::Report::Counterexample)
      end

      it "shrinks the counterexample" do
        result = @property.forall(@input, config: @config.update(max_shrinks: 1001))
        expect(result.shrink_count).to   eq(1001)
        expect(result.counterexample).to eq(0)
      end

      it "doesn't exceed max_shrinks" do
        result = @property.forall(@input, config: @config.update(max_shrinks: 1000))
        expect(result.shrink_count).to   eq(1000)
        expect(result.counterexample).to eq(2)
      end
    end

    context "when an exception is raised" do
      it "reports a failure" do
      end

      it "shrinks the counterexample" do
      end
    end

    context "when max_discards is exceeded" do
    end

    context "when coverage isn't sufficient" do
    end

    context "when coverage is sufficient" do
    end

    context "when test cases are classified" do
    end
  end
end
