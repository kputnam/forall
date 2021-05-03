# frozen_string_literal: true

class Forall
  module Matchers
    # @example:
    #   describe "foo" do
    #     forall([1,2,3]).check                 {|x,c| c.skip if x.even?; (x*2+1).even? }
    #     forall(...).check(seed: 999)          {|x,c| c.skip if x.even?; (x*2+1).even? }
    #     forall(...).check(success_limit: 50)  {|x,c| c.skip if x.even?; (x*2+1).even? }
    #     forall(...).check(discard_limit: 0.10){|x,c| c.skip if x.even?; (x*2+1).even? }
    #     forall(...).check(shrink_limit: 10)   {|x,c| c.skip if x.even?; (x*2+1).even? }
    #
    #     forall(lambda{|rnd, x| rnd.integer(x)}).
    #       check(0..9){|x,_| x.between?(0,9)}
    #   end
    def forall(input)
      ForallMatcher.new(input)
    end

    def sampled(input = nil, &block)
      Input.sampled(input || block)
    end

    def exhaustive(input)
      Input.exhaustive(input)
    end

    class ForallMatcher
      def initialize(input)
        @input = Input.build(input)
      end

      def check(property = nil, seed: nil, &block)
        property ||= block
        random = Forall::Random.new(seed: seed)
        result = Forall.check(@input, random, nil, &property)

        if defined?(RSpec::Expectations)
          case result
          when Forall::Ok
          when Forall::Vacuous
            message = "gave up (after %d test%s and %d discarded)\nSeed: %d" %
              [result.counter.test,
               result.counter.test == 1 ? "" : "s",
               result.counter.skip,
               result.seed]

            error   = ::RSpec::Expectations::ExpectationNotMetError.new(message)
            source  = property.binding.source_location.join(":")
            source << " in `block in ...'"
            error.set_backtrace(source)
            raise ::RSpec::Expectations::ExpectationNotMetError, message

          else
            if Forall::No === result or RSpec::Expectations::ExpectationNotMetError === result.error
              message = "falsified (after %d test%s%s):\nInput: %s\nSeed:  %d" %
                [result.counter.ok,
                 result.counter.ok == 1 ? "" : "s",
                 (result.counter.shrunk.steps == 1 ? "and 1 shrink" :
                  result.counter.shrunk.steps == 0 ? "" : "and #{result.counter.shrinks} shrinks"),
                 result.counterexample.inspect,
                 result.seed]

              error   = ::RSpec::Expectations::ExpectationNotMetError.new(message)
              source  = property.binding.source_location.join(":")
              source << " in `block in ...'"
              error.set_backtrace(source)
              raise error
            else
              message = "exception %s (after %d test%s%s):\nInput: %s\nSeed: %d" %
                [result.error,
                 result.counter.ok,
                 result.counter.ok == 1 ? "" : "s",
                 (result.counter.shrunk.steps == 1 ? "and 1 shrink" :
                  result.counter.shrunk.steps == 0 ? "" : "and #{result.counter.shrinks} shrinks"),
                 result.counterexample.inspect,
                 result.seed]

              error   = ::RSpec::Expectations::ExpectationNotMetError.new(message)
              source  = property.binding.source_location.join(":")
              source << " in `block in ...'"
              error.set_backtrace(source)
              raise error
            end
          end
        else
          result
        end
      end

      # Assigns a classification label to a random input
      # def label(name)
      #   @labels[name] += 1
      # end

      # # Declares at least `pct` of inputs should have the given label, or a test
      # # will fail.
      # def cover(name, pct=0.01)
      #   @cover[name] = pct
      # end

      # # Skip over this input and choose a new random input
      # def skip
      # end
    end
  end
end
