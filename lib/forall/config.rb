# frozen_string_literal: true

class Forall
  using Forall::Refinements

  # 
  class Config
    # Check the property this many times, unless `stop_early?` is enabled, in
    # which case fewer tests may be run (the outcome won't change)
    #
    # @return [Integer]
    attr_reader :min_tests

    # Number of discarded test cases before giving up on checking the property
    #
    # @return [Integer]
    attr_reader :max_discards

    # Maximum number of test cases to run in search of a minimal counterexample
    #
    # @return [Integer]
    attr_reader :max_shrinks

    # Number of times to re-run a test case before deciding that it passes. This
    # can be useful if your property could pass or fail non-deterministically.
    #
    # @return [Integer]
    attr_reader :min_retries

    # Stop testing as soon as we determine label coverage is adequate or
    # inadequate.
    #
    # @return [Boolean]
    attr_reader :stop_early

    # TODO
    #
    # @return [Float]
    def significance_level
      return unless defined? @significance_level and !@significance_level.nil?

      if @significance_level <= 0
        # Force alpha to be positive
        2.710505431213761e-20
      else
        @significance_level
      end
    end

    def initialize(**attributes)
      attributes.each do |k, v|
        raise NoMethodError, "undefined attribute `#{k}' for #{inspect}"\
          unless respond_to?(k)

        instance_variable_set("@#{k}", v)
      end
    end
  end

  class << Config
    def default
      new(min_tests: 100, max_discards: 50, max_shrinks: 1000, min_retries: 0, stop_early: false)
    end
  end
end
