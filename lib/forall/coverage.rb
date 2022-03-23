# frozen_string_literal: true

# :nodoc:
class Forall
  using Forall::Refinements

  # Provides a way to assert that some minimum proportion of the randomly
  # sampled test cases have some user-defined characteristic. For instance,
  # we can assert that at least 30% of test cases are even numbers:
  #
  #   forall(...){|x| cover(0.30, "even number", x.even?); ... }
  #
  # Because test cases are randomly sampled, there is a chance that label
  # coverage is either achieved or not due only to random chance, rather than
  # the characteristics of the whole population. To address this issue, this
  # class also provides optional statistical hypothesis testing and allows
  # users to specify a significance level.
  class Coverage
    # @return [Hash<String, Float>]
    attr_reader :required

    # @return [Hash<String, Integer>]
    attr_reader :coverage

    def initialize
      @required = {}
      @coverage = {}
    end

    # Increments coverage from the data collected from a single test case
    #
    # @return [void]
    def update(control)
      control.required.each do |label, value|
        @required[label] = value
      end

      control.coverage.each do |label, value|
        @coverage[label] ||= 0
        @coverage[label]  += 1 if value
      end

      control.clear
    end

    # True when all labels have statistically significant coverage that meets or
    # exceeds the required minimum fraction of coverage.
    def satisfied?(test_count, significance_level = nil)
      satisfied(test_count, significance_level).sort == @required.keys.sort
    end

    # True when any labels have statistically significant coverage that does not
    # meet or exceed the required minimum fraction of coverage.
    def unsatisfied?(test_count, significance_level = nil)
      unsatisfied(test_count, significance_level).any?
    end

    # Enumerates all labels that have sufficient coverage. If significance level
    # is not given, this is the complement of `unsatisfied`, and their sum will
    # enumerate all labels.
    #
    # When a significance level is given, enumerates only labels that have
    # sufficient and statistically significant coverage. Labels that do not have
    # statistical significance will not be enumerated by either `satisfied?` or
    # `unsatisfied?`, because there's not enough information to determine which
    # classification applies.
    #
    # Below is a diagram showing three different confidence intervals, A, B, and
    # C. The required coverage level is X. In this diagram, we can be confident
    # that A does not satisfy the requirement, because even its upper bound is
    # less than X. We can also be confident that C does satisfy the requirement,
    # because even its lower bound exceeds X. Lastly, we cannot confidently make
    # a determination about B, but the interval width will shrink as more data
    # is collected.
    #
    #                      *-C-*
    #             *------B------*
    #         *---A---*
    #     0 -------------X----------------------------- 1
    #
    # @return [Enumerator<String>]
    def satisfied(test_count, significance_level = nil)
      if significance_level.nil?
        Enumerator.new do |result|
          @required.each do |label, minimum|
            ratio  = @coverage.fetch(label, 0).to_f / test_count
            result << label if ratio >= minimum
          end
        end
      else
        Enumerator.new do |result|
          # Compute the upper bound of the Wilson score interval.
          n = test_count.to_f
          z = _probit(1 - (significance_level/2))

          zsq = z * z

          @required.each do |label, minimum|
            np  = @coverage.fetch(label, 0)
            p   = np / n
            mid = (2*np) + zsq
            off = (z * Math.sqrt(zsq - (1/n) + (4*np*(1-p)) - ((4*p)-2))) + 1
            low = (mid - off) / (2 * (n + zsq))

            result << label if low >= minimum
          end
        end
      end
    end

    # Enumerates all labels that do not have sufficient coverage. If
    # significance level is not given, this is the complement of `satisfied`,
    # and their sum will enumerate all labels.
    #
    # When a significance level is given, enumerates only labels that have
    # insufficient but statistically significant coverage. Labels that do not have
    # statistical significance will not be enumerated by either `satisfied` or
    # `unsatisfied`, because there's not enough information to determine which
    # classification applies.
    #
    # Below is a diagram showing three different confidence intervals, A, B, and
    # C. The required coverage level is X. In this diagram, we can be confident
    # that A does not satisfy the requirement, because even its upper bound is
    # less than X. We can also be confident that C does satisfy the requirement,
    # because even its lower bound exceeds X. Lastly, we cannot confidently make
    # a determination about B, but the interval width will shrink as more data
    # is collected.
    #
    #                      *-C-*
    #             *------B------*
    #         *---A---*
    #     0 -------------X----------------------------- 1
    #
    # @return [Enumerator<String>]
    def unsatisfied(test_count, significance_level = nil)
      if significance_level.nil?
        Enumerator.new do |result|
          @required.each do |label, minimum|
            ratio  = @coverage.fetch(label, 0).to_f / test_count
            result << label if ratio >= minimum
          end
        end
      else
        Enumerator.new do |result|
          # Compute the lower bound of the Wilson score interval.
          n = test_count.to_f
          z = _probit(1 - (significance_level/2))

          zsq = z * z

          @required.each do |label, minimum|
            np  = @coverage.fetch(label, 0)
            p   = np / n
            mid = (2*np) + zsq
            off = (z * Math.sqrt(zsq - (1/n) + (4*np*(1-p)) - ((4*p)-2))) + 1
            hi  = (mid + off) / (2 * (n + zsq))

            result << label if hi < minimum
          end
        end
      end
    end

  private

    # This approximates the value of a standard normal random variable
    # associated with the given cumulative probability. For example, p(X <
    # -1.96) = 0.025, so _probit(0.025) = -1.96. It is also described as the
    # quantile function for the standard normal distribution.
    #
    # @param [Float]  0 <= p <= 1
    # @return [Float]
    def _probit(p)
      return  Float::NAN       if p <  0
      return -Float::INFINITY  if p == 0
      return  Float::NAN       if p >  1

      # This algorithm is adapted from Peter John Acklam's code for
      # approximating the inverse normal ccumulative distribution function
      #
      # https://web.archive.org/web/20151110174102/http://home.online.no/~pjacklam/notes/invnorm/
      a1 = -3.969683028665376e+01
      a2 =  2.209460984245205e+02
      a3 = -2.759285104469687e+02
      a4 =  1.383577518672690e+02
      a5 = -3.066479806614716e+01
      a6 =  2.506628277459239e+00

      b1 = -5.447609879822406e+01
      b2 =  1.615858368580409e+02
      b3 = -1.556989798598866e+02
      b4 =  6.680131188771972e+01
      b5 = -1.328068155288572e+01

      c1 = -7.784894002430293e-03
      c2 = -3.223964580411365e-01
      c3 = -2.400758277161838e+00
      c4 = -2.549732539343734e+00
      c5 =  4.374664141464968e+00
      c6 =  2.938163982698783e+00

      d1 =  7.784695709041462e-03
      d2 =  3.224671290700398e-01
      d3 =  2.445134137142996e+00
      d4 =  3.754408661907416e+00

      p_lo = 0.02425
      p_hi = 1 - p_lo

      if 0 < p and p < p_lo
        # Approximation for lower region
        q = Math.sqrt(-2*Math.log(p))
        (((((c1*q+c2)*q+c3)*q+c4)*q+c5)*q+c6) / ((((d1*q+d2)*q+d3)*q+d4)*q+1)
      elsif p_hi <  p and p < 1
        # Approximation for upper region
        q = Math.sqrt(-2*Math.log(1-p))
        -(((((c1*q+c2)*q+c3)*q+c4)*q+c5)*q+c6) / ((((d1*q+d2)*q+d3)*q+d4)*q+1)
      elsif p_lo <= p and p <= p_hi
        # Approximation for central region
        q = p - 0.5
        r = q*q
        (((((a1*r+a2)*r+a3)*r+a4)*r+a5)*r+a6)*q / (((((b1*r+b2)*r+b3)*r+b4)*r+b5)*r+1)
      end
    end
  end
end
