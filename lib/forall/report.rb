# frozen_string_literal: true

require "term/ansicolor"

class Forall
  using Forall::Refinements

  # TODO
  class Report
    include Term::ANSIColor

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
        raise NoMethodError, "undefined method `#{k}' for #{inspect}"\
          unless respond_to?(k)

        instance_variable_set("@#{k}", v)
      end
    end

    def render_coverage(indent: "")
      parts = "·▏▎▍▌▋▊▉█"
      bar_width = 50
      lbl_width = @coverage.required.keys.map(&:length).max

      satisfied_   = @coverage.satisfied(@test_count, @config.significance_level).to_set
      unsatisfied_ = @coverage.unsatisfied(@test_count, @config.significance_level).to_set

      # TODO: Maybe labels should be printed in the order they were declared
      @coverage.required.sort.map do |label, minimum|
        score = @coverage.coverage[label].to_f / @test_count

        whole = (score * bar_width).floor
        fract = (score * bar_width) - whole # 0 <= fract < 1
        zeros = bar_width - whole - fract.ceil

        w = parts[-1] * whole
        z = parts[0]  * zeros
        f = fract.zero? ? "" : parts[1 + ((parts.length-1)*fract).floor]

        if satisfied_.member?(label)
          color = :white
          icon  = "✓"
        elsif unsatisfied_.member?(label)
          color = :red
          icon  = "✗"
        else
          color = :yellow
          icon  = "✗"
        end

        if minimum.zero?
          send(color, "%s%#{lbl_width}s: %2.f%% %s%s%ss" %
            [indent, label, score*100, w, f, z])
        else
          send(color, "%s%#{lbl_width}s: %2.f%% %s%s%s %s %2.f%%" %
            [indent, label, score*100, w, f, z, icon, minimum*100])
        end
      end.join("\n")
    end
  end

  class Report::Success < Report
    def render
      green("✓") << " passed #{test_count} tests"
    end
  end

  class Report::TooManyDiscards < Report
    def backtrace
      @backtrace&.grep_v(%r{/lib/forall/[^/]+.rb:})
    end

    def render
      yellow("⚐ gave up after #{discard_count} discards, passed #{test_count} tests")
    end
  end

  class Report::CoverageInsufficient < Report
    def backtrace
      @backtrace&.grep_v(%r{/lib/forall/[^/]+.rb:})
    end

    def render
      yellow("✗ label coverage was not reached after #{test_count} tests") \
        << "\n" << render_coverage(indent: "  ")
    end
  end

  class Report::CoverageInsignificant < Report
    def backtrace
      @backtrace&.grep_v(%r{/lib/forall/[^/]+.rb:})
    end

    def render
      yellow("⚐ label coverage did not reach statistical significance, passed #{test_count} tests") \
        << "\n" << render_coverage("  ")
    end
  end

  class Report::Counterexample < Report
    # @return [Exception]
    attr_reader :reason

    # @return [Object]
    attr_reader :counterexample

    # @return [Integer]
    attr_reader :shrink_count

    def render
      red("✗ failed after #{test_count} tests")
    end

    def backtrace
      @reason.backtrace.grep_v(%r{/lib/forall/[^/]+.rb:})
    end
  end
end
