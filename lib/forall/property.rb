# frozen_string_literal: true

class Forall

  # :nodoc:
  class Property < Proc
    # :nodoc:
    class Counterexample < StandardError; end

    def recheck(prng:, scale:)
      # @TODO
    end

    def forall(input, *args, config: Config.default, **kwargs)
      test_count    = 0
      discard_count = 0
      control       = Control.new
      coverage      = Coverage.new

      # @TODO: Need a way for `input` to provide the current value of the random
      # seed, but also need to maintain compatibility with non-Random input.
      input.each(*args, **kwargs) do |test|
        return _too_many_discards(test_count, discard_count, coverage, config) \
          if discard_count > config.max_discards

        return _check_coverage(test_count, discard_count, coverage, config) \
          if test_count >= config.min_tests

        # Repeatedly checking for statistical significance increases the
        # chance of finding it, compared to checking at the end of the
        # experiment. Stopping early increases the chance for making the
        # wrong determination on the coverage.
        if config.stop_early and test_count >= 100 and test_count.modulo(100).zero?
          return _success(test_count, discard_count, coverage, config) \
            if coverage.satisfied?(test_count, config.significance_level)
          return _coverage_insufficient(test_count, discard_count, coverage, config) \
            if coverage.unsatisfied?(test_count, config.significance_level)
        end

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
            shrunk,
            reason,
            test_count,
            discard_count,
            shrink_count,
            coverage,
            config)
        end
      end
    end

  private

    def _success(test_count, discard_count, coverage, config)
      Report::Success.new(
        config:        config,
        test_count:    test_count,
        discard_count: discard_count,
        coverage:      coverage)
    end

    def _counterexample(test, reason, test_count, discard_count, shrink_count, coverage, config)
      Report::Counterexample.new(
        counterexample: test,
        config:         config,
        reason:         reason,
        coverage:       coverage,
        test_count:     test_count,
        shrink_count:   shrink_count,
        discard_count:  discard_count)
    end

    def _too_many_discards(test_count, discard_count, coverage, config)
      Report::TooManyDiscards.new(
        config:        config,
        coverage:      coverage,
        backtrace:     caller,
        test_count:    test_count,
        discard_count: discard_count)
    end

    def _coverage_insufficient(test_count, discard_count, coverage, config)
      Report::CoverageInsufficient.new(
        config:        config,
        coverage:      coverage,
        backtrace:     caller,
        test_count:    test_count,
        discard_count: discard_count)
    end

    def _coverage_insignificant(test_count, discard_count, coverage, config)
      Report::CoverageInsignificant.new(
        config:        config,
        coverage:      coverage,
        backtrace:     caller,
        test_count:    test_count,
        discard_count: discard_count)
    end

    def _check_coverage(test_count, discard_count, coverage, config)
      if config.significance_level.nil?
        # We can't make any claims about statistical significance
        if coverage.satisfied?(test_count)
          _success(test_count, discard_count, coverage, config)
        else
          _coverage_insufficient(test_count, discard_count, coverage, config)
        end

      elsif coverage.satisfied?(test_count, config.significance_level)
        # We're certain coverage is sufficient
        _success(test_count, discard_count, coverage, config)

      elsif coverage.unsatfied?(test_count, config.significance_level)
        # We're certain coverage is insufficient
        _coverage_insufficient(test_count, discard_count, coverage, config)

      else
        # We can't be sure the result wasn't due to sampling error
        _coverage_insignificant(test_count, discard_count, coverage, config)
      end
    end

    # @param  [Tree<A>]   tree
    # @param  [Exception] reason
    # @param  [Config]    config
    #
    # @return [A, Exception, Integer]
    def _shrink(tree, reason, config)
      control      = Control.new
      shrink_count = 0

      # TODO: When all subtree descendants are smaller than their next sibling
      # subtree's descendants, we can be sure that a counterexample found in the
      # first subtree will be smaller than any found in later sibling trees.
      #
      # Yet we may fail to find the minimal counterexample because subtrees
      # are pruned when their root is not a counterexample, even though one
      # of its descendants could be.
      while shrink_count < config.max_shrinks
        stop = true

        tree.children.each do |shrunk|
          # TODO: How many discards should be allowed when shrinking? If this
          # is not capped, we can get caught in an infinite loop here.
          catch(:discard) do
            self[shrunk.value, control] or raise Counterexample
            shrink_count += 1
          end

          break unless shrink_count < config.max_shrinks
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
end
