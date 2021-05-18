# frozen_string_literal: true

describe Forall::Matchers do
  before do
    @dsl = Object.new
    @dsl.extend(Forall::Matchers)
  end

  describe "sampled" do
    context "when given a block" do
      it "returns Forall::Input::Some" do
        expect(@dsl.sampled{|_| }).to be_a(Forall::Input::Some)
      end
    end

    context "when given a lambda" do
      it "returns Forall::Input::Some" do
        expect(@dsl.sampled(lambda{|_| })).to be_a(Forall::Input::Some)
      end
    end

    context "when given an Enumerable" do
      it "returns Forall::Input::Some" do
        expect(@dsl.sampled(%w[a b c])).to be_a(Forall::Input::Some)
      end
    end

    context "when given no argument or block" do
      it "raises an error" do
        expect{ @dsl.sampled }.to raise_error(ArgumentError)
      end
    end
  end

  describe "exhaustive" do
    it "requires an Enumerable argument" do
      expect{ @dsl.exhaustive }.to      raise_error(ArgumentError)
      expect{ @dsl.exhaustive(100) }.to raise_error(TypeError)
    end

    it "returns Forall::Input::All" do
      expect(@dsl.exhaustive(%w[a b c])).to be_a(Forall::Input::All)
    end
  end

  describe "forall" do
    it "requires an input" do
      expect{ @dsl.forall }.to      raise_error(ArgumentError)
      expect{ @dsl.forall(100) }.to raise_error(TypeError)
    end

    it "returns Forall::Matchers::ForallMatcher" do
      expect(@dsl.forall(%w[a b c])).to be_a(Forall::Matchers::ForallMatcher)
    end
  end
end
