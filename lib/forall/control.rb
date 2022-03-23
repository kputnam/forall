# frozen_string_literal: true

# :nodoc:
class Forall
  # This class provides Forall::Property a way to interact with the test runner
  # as its testing the property.
  #
  class Control
    # @return [Hash<String, Float>]
    attr_reader :required

    # @return [Hash<String, Boolean>]
    attr_reader :coverage

    def initialize
      @required = {}
      @coverage = {}
      @location = {}
    end

    # Reset the coverage information for the next test case
    def clear
      @required.clear
      @coverage.clear

      # Don't reset @location because `caller` isn't cheap and the call sites
      # _probably_ don't change from one iteration to the next
      self
    end

    # Skip the current test case (e.g., the randomly sampled value doesn't meet
    # preconditions required by the property). This method does not return
    # control to the caller.
    def discard
      throw :discard, true
    end

    # Used to summarize the test cases by classifying them into groups. For
    # example, `classify("even", x.even?)` and `classify("odd", x.odd?)` will
    # provide diagnostic information at the end of the test that shows how
    # many test cases were even or odd.
    #
    def classify(label, bool)
      cover(0.0, label, bool)
    end

    # Require some percentage of tests to be covered by the label, otherwise the
    # property will fail with Result::GaveUp.
    #
    # @param [Float]    minimum
    # @param [String]   label
    # @param [Boolean]  covered
    def cover(minimum, label, covered)
      raise ArgumentError, "coverage must be a Float within 0..1" \
        unless minimum.is_a?(Float) and minimum.between?(0, 1)

      @required[label] = minimum
      @coverage[label] = covered
      @location[label] ||= caller

      self
    end
  end
end
