describe Forall do
  before do
    @rnd = Forall::Random.new(seed: 1234567890)
  end

  describe ".check" do
    context "when input is sampled" do
      context "and property takes one arg" do
        it "yields input" do
          expect do |b|
            Forall.check(Forall::Input.build(&:integer), @rnd){|x| b.to_proc.call(x); true }
          end.to yield_successive_args(*[instance_of(Integer)] * 100)
        end
      end

      context "and property takes two args" do
        it "yields input and counter" do
          expect do |b|
            Forall.check(Forall::Input.build(&:integer), @rnd){|x,n| b.to_proc.call(x, n); true }
          end.to yield_successive_args(*[[instance_of(Integer), instance_of(Forall::Counter)]] * 100)
        end
      end
    end

    context "when input is exhaustive" do
      context "and property takes one arg" do
        it "yields input" do
          expect do |b|
            Forall.check(Forall::Input.build(%w(a b c d e f)), @rnd){|x| b.to_proc.call(x); true }
          end.to yield_successive_args(*%w(a b c d e f))
        end
      end

      context "and property takes two args" do
        it "yields input and counter" do
          expect do |b|
            Forall.check(Forall::Input.build(%w(a b c d e f)), @rnd){|x,n| b.to_proc.call(x, n); true }
          end.to yield_successive_args(
            ["a", instance_of(Forall::Counter)],
            ["b", instance_of(Forall::Counter)],
            ["c", instance_of(Forall::Counter)],
            ["d", instance_of(Forall::Counter)],
            ["e", instance_of(Forall::Counter)],
            ["f", instance_of(Forall::Counter)])
        end
      end
    end

    context "when property takes too few args" do
      it "raises an exception" do
        expect(lambda do
          Forall.check(Forall::Input.build(%w(a b c)), @rnd){|| true }
        end).to raise_error(ArgumentError, /one or two arguments/)
      end
    end

    context "when property takes too many args" do
      it "raises an exception" do
        expect(lambda do
          Forall.check(Forall::Input.build(%w(a b c)), @rnd){|a,b,c| true }
        end).to raise_error(ArgumentError, /one or two arguments/)
      end
    end

    context "when property suceeds" do
      it "returns Forall::Ok" do
        result = Forall.check(Forall::Input.build(&:integer), @rnd){|_| true }
        expect(result).to be_a(Forall::Ok)
        expect(result.counter.ok).to        eq(100)
        expect(result.counter.skip).to      eq(0)
        expect(result.counter.shrunk.ok).to eq(0)
        expect(result.counter.shrunk.no).to eq(0)
      end
    end

    context "when property returns false" do
      context "and input is not shrinkable" do
        it "returns Forall::No" do
          input  = Forall::Input.build(%w(a b c d e f g))
          result = Forall.check(input, @rnd){|x| x !~ /f/ }

          expect(result).to be_a(Forall::No)
          expect(result.counter.ok).to        eq(5)
          expect(result.counter.skip).to      eq(0)
        end

        it "does not search for smaller counterexamples" do
          input  = Forall::Input.build(%w(a b c d e f g))
          result = Forall.check(input, @rnd){|x| x !~ /f/ }

          expect(result.counter.shrunk.ok).to eq(0)
          expect(result.counter.shrunk.no).to eq(0)
          expect(result.counterexample).to    eq("f")
        end
      end

      context "and input is shrinkable" do
        it "returns Forall::No" do
          input = Forall::Input.build(%w(aaa bbb ccc ddd eee fff ggg))
          input.shrink{|x| ([x[1..-1]] unless x.empty?) || [] }
          result = Forall.check(input, @rnd){|x| x !~ /f/ }

          expect(result).to be_a(Forall::No)
          expect(result.counter.ok).to        eq(5)
          expect(result.counter.skip).to      eq(0)
        end

        it "searches for smaller counterexample" do
          input = Forall::Input.build(%w(aaa bbb ccc ddd eee fff ggg))
          input.shrink{|x| ([x[1..-1]] unless x.empty?) || [] }
          result = Forall.check(input, @rnd){|x| x !~ /f/ }

          expect(result.counter.shrunk.no).to eq(2)
          expect(result.counter.shrunk.ok).to eq(1)
          expect(result.counterexample).to    eq("f")
        end
      end
    end

    context "when property raises an exception" do
      context "and input is not shrinkable" do
        it "returns Forall::Fail" do
          input  = Forall::Input.build(%w(a b c d e f g))
          result = Forall.check(input, @rnd){|x| raise "boo" if x =~ /f/; true }

          expect(result).to be_a(Forall::Fail)
          expect(result.counter.ok).to        eq(5)
          expect(result.counter.skip).to      eq(0)
          expect(result.error).to             be_a(RuntimeError)
          expect(result.error.message).to     eq("boo")
        end

        it "does not search for smaller counterexample" do
          input  = Forall::Input.build(%w(a b c d e f g))
          result = Forall.check(input, @rnd){|x| raise "boo" if x =~ /f/; true }

          expect(result.counter.shrunk.ok).to eq(0)
          expect(result.counter.shrunk.no).to eq(0)
          expect(result.counterexample).to    eq("f")
        end
      end

      context "and input is shrinkable" do
        it "returns Forall::No" do
          input = Forall::Input.sampled {|rnd| rnd.array { rnd.choose('a'..'z') }.join }
          input.shrink{|x| ([x[1..-1], x[0..-2]] unless x.empty?) || [] }
          result = Forall.check(input, @rnd){|x| raise "boo" if x =~ /f/; true }

          expect(result).to be_a(Forall::Fail)
          expect(result.counter.ok).to    eq(2)
          expect(result.counter.skip).to  eq(0)
          expect(result.error).to         be_a(RuntimeError)
          expect(result.error.message).to eq("boo")
        end

        it "searches for smaller counterexample" do
          input = Forall::Input.sampled {|rnd| rnd.array { rnd.choose('a'..'z') }.join }
          input.shrink{|x| ([x[1..-1], x[0..-2]] unless x.empty?) || [] }
          result = Forall.check(input, @rnd){|x| raise "boo" if x =~ /f/; true }

          expect(result.counter.shrunk.total).to eq(100)
          expect(result.counter.shrunk.fail).to  eq(76)
          expect(result.counter.shrunk.ok).to    eq(24)
          expect(result.counter.shrunk.no).to    eq(0)
          expect(result.counterexample).to       eq("f")
        end
      end
    end

    context "when property discards too many inputs" do
      it "returns Forall::No" do
        input  = Forall::Input.build((100..999).to_a)
        result = Forall.check(input, @rnd){|x,n| n.skip! }
        expect(result).to be_a(Forall::Vacuous)
        expect(result.counter.ok).to        eq(0)
        expect(result.counter.skip).to      eq(90)
        expect(result.counter.shrunk.no).to eq(0)
        expect(result.counter.shrunk.ok).to eq(0)
      end
    end
  end
end
