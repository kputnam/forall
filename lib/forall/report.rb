# frozen_string_literal: true

class Forall
  using Forall::Refinements

  class Report
    # @return [Integer]
    attr_reader :size

    # @return [Integer]
    attr_reader :seed

    # @return [Integer]
    attr_reader :test_count

    # @return [Integer]
    attr_reader :discard_count

    # @return [Coverage]
    attr_reader :coverage

    # @return [Config]
    attr_reader :config

    def initialize(**attributes)
      attributes.each do |k, v|
        raise NoMethodError, "undefined method `#{k}' for #{self.inspect}"\
          unless respond_to?(k)

        instance_variable_set("@#{k}", v)
      end
    end
  end

  class Report::Success < Report
  end

  class Report::TooManyDiscards < Report
  end

  class Report::CoverageInsufficient < Report
  end

  class Report::CoverageInsignificant < Report
  end

  class Report::Counterexample < Report
    # @return [Exception]
    attr_reader :reason

    # @return [Object]
    attr_reader :counterexample

    # @return [Integer]
    attr_reader :shrink_count
  end
end
