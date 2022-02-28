# frozen_string_literal: true

class Forall
  using Forall::Refinements

  module RspecDsl
    def forall(input, &block)
      config =
        if input.is_a?(Array)
          Config.default do |c|
            # TODO: What if input is empty?
            c.min_tests    = input.size
            c.max_discards = 0
            c.max_shrinks  = 0
          end
        else
          Config.default
        end

      prop =
        if block.arity == 1
          Property.new do |x, state|
            @state = state
            block[x]
          end
        elsif block.arity > 1
          Property.new do |x, state|
            @state = state
            block[*x]
          end
        else
          raise ArgumentError
        end

      result = prop.forall(input, config: config)
      @state = nil

      case result
      when Report::Success
      when Report::Counterexample
        case result.reason
        when RSpec::Expectations::ExpectationNotMetError, nil
          raise RSpec::Expectations::ExpectationNotMetError,
            "Counterexample: #{result.counterexample.inspect}",
            result.reason&.backtrace

        when Exception
          raise RSpec::Expectations::ExpectationNotMetError,
            "Exception (#{result.reason}) on test #{result.counterexample.inspect}",
            result.reason&.backtrace
        end
      when Report::TooManyDiscards
        raise 
      when Report::CoverageInsufficient
        raise
      when Report::CoverageInsignificant
        raise
      end
    end

    def classify(*args, &block)
      @state.classify(*args, &block)
    end

    def discard(*args, &block)
      @state.discard(*args, &block)
    end

    def cover(*args, &block)
      @state.cover(*args, &block)
    end
  end
end
