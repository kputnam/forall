# frozen_string_literal: true

class Forall
  # This module can be mixed into RSpec to provide more concise syntax
  #
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
  module Matchers
    def forall(input)
      ForallMatcher.new(input)
    end

    def sampled(input = nil, &block)
      Input.sampled(input, &block)
    end

    def exhaustive(input)
      Input.exhaustive(input)
    end

    # @private
    class ForallMatcher
      def initialize(input)
        @input = Input.build(input)
      end

      def check(property = nil, seed: nil, &block)
        property ||= block
        random = Forall::Random.new(seed: seed)
        result = Forall.check(@input, random, nil, &property)

        if defined?(RSpec)
          source = property.binding.source_location.join(":")
          source << " in `block in ...'"

          case result
          when Forall::Ok
            # Pass
          when Forall::Vacuous
            error = ::RSpec::Expectations::ExpectationNotMetError.new(format_message_vacuous(result))
            error.set_backtrace(source)
            raise error
          else
            error =
              if result.is_a?(Forall::No) or result.error.is_a?(RSpec::Expectations::ExpectationNotMetError)
                ::RSpec::Expectations::ExpectationNotMetError.new(format_message_no(result))
              else
                ::RSpec::Expectations::ExpectationNotMetError.new(format_message_fail(result))
              end

            error.set_backtrace(source)
            raise error
          end
        end || result
      end

      # Assigns a classification label to a random input
      def label(_name)
        raise
      end

      # # Declares at least `pct` of inputs should have the given label, or a test
      # # will fail.
      def cover(_name, _pct = 0.01)
        raise
      end

      # # Skip over this input and choose a new random input
      def skip
        raise
      end

    private

      def pluralize(count, zero, one, many)
        case count
        when 0
          zero
        when 1
          one
        else
          many
        end
      end

      def format_message_vacuous(result)
        "gave up (after %d test%s and %d discarded)\nSeed: %d" %
          [result.counter.test,
           pluralize(result.counter.test, "s", "", "s"),
           result.counter.skip,
           result.seed]
      end

      def format_message_no(result)
        "falsified (after %d test%s%s):\nInput: %s\nSeed:  %d" %
          [result.counter.ok,
           pluralize(result.counter.ok, "s", "", "s"),
           pluralize(result.counter.shrunk.steps, "", " and 1 shrink", " and #{result.counter.shrunk.steps} shrinks"),
           result.counterexample.inspect,
           result.seed]
      end

      def format_message_fail(result)
        "exception %s (after %d test%s%s):\nInput: %s\nSeed: %d" %
          [result.error,
           result.counter.ok,
           pluralize(result.counter.ok, "s", "", "s"),
           pluralize(result.counter.shrunk.steps, "", " and 1 shrink", " and #{result.counter.shrunk.steps} shrinnks"),
           result.counterexample.inspect,
           result.seed]
      end
    end
  end
end
