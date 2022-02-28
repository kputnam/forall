module FunctionMatchers

  # Asserts that a given sequence of numbers closely matches the form:
  #   y = a^x + b
  def be_exponential(threshold = 0.95)
    BeExponential.new(threshold)
  end

  class BeExponential
    def initialize(threshold)
      @threshold = threshold
    end

    def matches?(target)
      target  = target.to_a if Enumerator === target
      @target = target
      return true if target.size < 3

      raise NotImplementedError, "be_exponential is not implemented"
    end

    def failure_message
      "expected #{@target.inspect} to be an exponential sequence"
    end

    def failure_message_when_negated
      "expected #{@target.inspect} to not be an exponential sequence"
    end
  end
end
