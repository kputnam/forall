# frozen_string_literal: true

module FunctionMatchers
  # Asserts that a given sequence of numbers closely matches the form:
  #   y = ax + b
  def be_linear(threshold = 0.95)
    BeLinear.new(threshold)
  end

  # Asserts that a given sequence of numbers closely matches the form:
  #   y = a^x + b
  def be_exponential(threshold = 0.95)
    BeExponential.new(threshold)
  end

  # @private
  class BeLinear
    def initialize(threshold)
      @threshold = threshold
    end

    def matches?(target)
      target = target.to_a if target.is_a?(Enumerator)
      return nil if target.size < 3

      @target = target
      n  = target.size
      xs = n.times.to_a
      ys = target

      num = ((n * n.times.sum{|i| xs[i]*ys[i] }) - (xs.sum * ys.sum))
      stdev_x = Math.sqrt((n * n.times.sum{|i| xs[i]*xs[i] }) - (xs.sum * xs.sum))
      stdev_y = Math.sqrt((n * n.times.sum{|i| ys[i]*ys[i] }) - (ys.sum * ys.sum))

      return false if stdev_y.zero?

      @r = num / (stdev_x * stdev_y)
      @r.abs.between?(@threshold, 1.0 + (1.0 - @threshold))
    end

    def failure_message
      "expected #{@target.inspect} to be a linear sequence, but correlation is #{@r}"
    end

    def failure_message_when_negated
      "expected #{@target.inspect} to not be a linear sequence, but correlation is #{@r}"
    end
  end

  # @private
  class BeExponential
    def initialize(threshold)
      @threshold = threshold
    end

    def matches?(target)
      target  = target.to_a if target.is_a?(Enumerator)
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
