# frozen_string_literal: true

describe Forall::Input do
  describe ".build" do
    context "when given nothing" do
      it "raises an error" do
        expect{ Forall::Input.build }.to raise_error(ArgumentError)
      end
    end

    context "when given an array" do
      it "returns Forall::Input::All" do
        expect(Forall::Input.build(%w[a b c])).to be_exhaustive
      end
    end

    context "when given a block" do
      it "returns Forall::Input::Some" do
        expect(Forall::Input.build{|_| nil }).to_not be_exhaustive
      end
    end

    context "when given an Forall::Input" do
      it "returns the Forall::Input" do
        x = Forall::Input.build(%w[1 2 3])
        expect(Forall::Input.build(x)).to equal(x)
      end
    end
  end
end
