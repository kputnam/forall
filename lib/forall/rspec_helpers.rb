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
    %w[singleton constant linear exponential].each do |m|
      class_eval(<<-RUBY, __FILE__, __LINE__ + 1)
        def #{m}(*args, **kwargs, &block)
          Forall::Random.#{m}(*args, **kwargs, &block)
        end
      RUBY
    end
  end

  module RSpecHelpers::Random
    %w[sequence bernoulli binomial geometric negative_binomial hypergeometric
    poisson uniform normal exponential gamma beta chi_square student_t integer
    boolean integer integer_ float float_ complex range choose weighted
    permutation subsequence array hash set binit octit digit hexit lowercase
    uppercase alpha alphanum ascii latin byte utf8 utf8_all].each do |m|
      class_eval(<<-RUBY, __FILE__, __LINE__ + 1)
        def #{m}(*args, **kwargs, &block)
          Forall::Random.#{m}(*args, **kwargs, &block)
        end
      RUBY
    end
  end
end
