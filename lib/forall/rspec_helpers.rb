# frozen_string_literal: true

class Forall
  using Forall::Refinements

  # TODO
  module RSpecHelpers
    # TODO
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
          Property.new do |x, control|
            @_control = control
            block[x]
          end
        elsif block.arity > 1
          Property.new do |x, control|
            @_control = control
            block[*x]
          end
        else
          raise ArgumentError
        end

      report = prop.forall(input, config: config)
      @_control = nil

      case report
      when Report::Success
        # Do nothing
      when Report::Counterexample
        case report.reason
        when Forall::Property::Counterexample, RSpec::Expectations::ExpectationNotMetError
          raise RSpec::Expectations::ExpectationNotMetError, report.render, report.backtrace
        else
          raise RSpec::Expectations::ExpectationNotMetError, report.render, report.backtrace, cause: report.reason
        end

      when Report::TooManyDiscards, Report::CoverageInsufficient, Report::CoverageInsignificant
        raise RSpec::Expectations::ExpectationNotMetError, report.render, report.backtrace
      end
    end

    %w[discard classify cover].each do |m|
      class_eval(<<-RUBY, __FILE__, __LINE__ + 1)
        def #{m}(*args, **kwargs, &block)
          @_control.#{m}(*args, **kwargs, &block)
        end
      RUBY
    end
  end

  # TODO
  module RSpecHelpers::Bounds
    # @example
    #   bounds(50){|scale| ... }    #=> Forall::Bounds.new(50){|scale| ... }
    #   bounds.linear(1..10)        #=> Forall::Bounds.linear(1..10)
    #   bounds                      #=> Forall::Bounds
    #
    def bounds(*args, **kwargs, &block)
      if block_given?
        Forall::Bounds.new(*args, **kwargs, &block)
      elsif args.empty? and kwargs.empty?
        Forall::Bounds
      else
        raise ArgumentError, "no block given"
      end
    end
  end

  module RSpecHelpers::Random
    # @example
    #   random{|prng, scale| ... }  #=> Forall::Random.new{|prng, scale| ... }
    #   random.integer(1..10)       #=> Forall::Random.integer(1..10)
    #   random                      #=> Forall::Random
    #
    def random(&block)
      if block_given?
        Forall::Random.new(&block)
      else
        Forall::Random
      end
    end
  end
end
