# frozen_string_literal: true

class Forall

  # @TODO
  class Property < Proc

    # TODO
    class Counterexample < StandardError; end

    def recheck(random, seed, size, config: Config.default)
      # @TODO
    end

    # @return [Report]
    def forall(random, config: Config.default, prng: ::Random.new)
      size          = 0
      test_count    = 0
      discard_count = 0
      control       = Control.new
      coverage      = Coverage.new

      while true
        return _too_many_discards(test_count, discard_count, coverage, prng.seed, config) \
          if discard_count > config.max_discards

        return _check_coverage(test_count, discard_count, coverage, prng.seed, config) \
          if test_count >= config.min_tests

        # TODO
        if config.stop_early and test_count >= 100 and test_count.modulo(100).zero?
          return _success(test_count, discard_count, coverage, prng.seed, config) \
            if coverage.satisfied?(test_count, config.confidence)
          return _coverage_insufficient(test_count, discard_count, coverage, prng.seed, config) \
            if coverage.failed?(test_count, config.confidence)
        end

        test  = random.run(prng, size)
        size += 1
        size  = 0 if size > 99

        begin
          catch(:discard) do
            discard_count += 1

            self[test.value, control] or raise Counterexample

            coverage.update(control)
            test_count    += 1
            discard_count -= 1
          end
        rescue Exception => reason
          test_count    += 1
          discard_count -= 1

          shrunk, reason, shrink_count = _shrink(test, reason, config)

          return _counterexample(
            size,
            shrunk,
            reason,
            test_count,
            discard_count,
            shrink_count,
            coverage,
            prng.seed,
            config)
        end
      end
    end

  private

    def _success(test_count, discard_count, coverage, seed, config)
      Report::Success.new(
        seed:           seed,
        config:         config,
        test_count:     test_count,
        discard_count:  discard_count,
        coverage:       coverage)
    end

    def _counterexample(size, test, reason, test_count, discard_count, shrink_count, coverage, seed, config)
      Report::Counterexample.new(
        size:           size,
        seed:           seed,
        counterexample: test,
        config:         config,
        reason:         reason,
        coverage:       coverage,
        test_count:     test_count,
        shrink_count:   shrink_count,
        discard_count:  discard_count)
    end

    def _too_many_discards(test_count, discard_count, coverage, seed, config)
      Report::TooManyDiscards.new(
        seed:           seed,
        config:         config,
        coverage:       coverage,
        test_count:     test_count,
        discard_count:  discard_count)
    end

    def _coverage_insufficient(test_count, discard_count, coverage, seed, config)
      Report::CoverageInsufficient.new(
        seed:           seed,
        config:         config,
        coverage:       coverage,
        test_count:     test_count,
        discard_count:  discard_count)
    end

    def _coverage_insignificant(test_count, discard_count, coverage, seed, config)
      Report::CoverageInsufficient.new(
        seed:           seed,
        config:         config,
        coverage:       coverage,
        test_count:     test_count,
        discard_count:  discard_count)
    end

    def _check_coverage(test_count, discard_count, coverage, seed, config)
      if config.confidence.nil?
        # We can't make any claims about statistical significance 
        if coverage.satisfied?(test_count)
          _success(test_count, discard_count, coverage, seed, config)
        else
          _coverage_insufficient(test_count, discard_count, coverage, seed, config)
        end

      elsif coverage.satisfied?(test_count, config.confidence)
        # We're certain coverage is sufficient
        _success(test_count, discard_count, coverage, seed, config)

      elsif coverage.failed?(test_count, config.confidence)
        # We're certain coverage is insufficient
        _coverage_insufficient(test_count, discard_count, coverage, seed, config)

      else
        # We can't be sure the result wasn't due to sampling error
        _coverage_insignificant(test_count, discard_count, coverage, seed, config)
      end
    end

    # @param
    # @return [A, Exception, Integer]
    def _shrink(tree, reason, config)
      control      = Control.new
      shrink_count = 0

      while shrink_count < config.max_shrinks
        stop = true

        tree.children.each do |shrunk|
          # TODO: This could result in an infinite loop if the shrink tree is
          # infinite and the property discards all the shrunken tests
          catch(:discard) do
            self[shrunk.value, control] or raise Counterexample
            shrink_count += 1
          end
        rescue Exception => reason_
          reason        = reason_
          tree          = shrunk
          shrink_count += 1
          stop          = false
          break         # Continue at `while`
        end

        break if stop
      end

      [tree.value, reason, shrink_count]
    end
  end

  # TODO: Rename
  class Property::Control
    # @return [Hash<String, Float>]
    attr_reader :minimum

    # @return [Hash<String, Boolean>]
    attr_reader :covered

    def initialize
      @minimum = {}
      @covered = {}
    end

    def reset!
      @minimum = {}
      @covered = {}
    end

    def discard
      throw :discard, true
    end

    def classify(label, bool = true)
      cover(label, 0.0, bool)
    end

    # Require some percentage of tests to be covered by the label, otherwise the
    # property will fail with Result::GaveUp.
    #
    # @param [String]   label
    # @param [Float]    minimum
    # @param [Boolean]  covered
    def cover(label, minimum, covered = true)
      raise RangeError, "coverage must be a Float within 0..1" \
        unless minimum.is_a?(Float) and minimum.between?(0, 1)

      @minimum[label] = minimum
      @covered[label] = covered
    end
  end
end
