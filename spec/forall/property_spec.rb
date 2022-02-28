# frozen_string_literal: true

describe Forall::Property do
  using Forall::Refinements

  describe "#forall" do
    before do
      @random = Forall::Random.integer(0..100)
      @config = Forall::Config.default
    end

    context "when no counterexample is found" do
      it "reports success" do
        result = Forall::Property.new{|_, _| true }.forall(@random, config: @config)
        expect(result).to               be_a(Forall::Report::Success)
        expect(result.test_count).to    eq(@config.min_tests)
        expect(result.discard_count).to eq(0)
      end
    end

    context "when a counterexample is found" do
      it "reports a failure" do
        result = Forall::Property.new do |integer, _state|
          # This will fail for any odd integers greater than 50
          integer < 50 or integer.even?
        end.forall(@random, config: @config, prng: Random.new(1))

        expect(result).to                be_a(Forall::Report::Counterexample)
        expect(result.discard_count).to  eq(0)
        expect(result.counterexample).to eq(51) # Closest odd value above 50 to @random's origin (0)
      end
    end

    context "when an exception is raised" do
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
