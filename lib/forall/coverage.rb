# frozen_string_literal: true

class Forall
  using Forall::Refinements

  # TODO
  class Coverage
    # @return [Hash<String, Float>]
    attr_reader :minimum

    # @return [Hash<String, Numeric>]
    attr_reader :covered

    def initialize(minimum = {}, covered = {})
      @minimum = minimum
      @covered = covered
    end

    def update(control)
      update_minimums(control.minimum)
      update_coverage(control.covered)
      control.reset!
    end

    def update_minimums(minimum)
      minimum.each do |label, value|
        @minimum[label] = value
      end
    end

    def update_coverage(covered)
      covered.each do |label, value|
        @covered[label] ||= 0
        @covered[label]  += 1 if value
      end
    end

    # TODO
    def satisfied?(test_count, confidence_level = nil)
      if confidence_level.nil?
        @minimum.each do |label, minimum|
          return false if @covered.fetch(label, 0) / test_count < minimum
        end
      else
        a = 1 - confidence_level
        n = test_count.to_f
        z = _probit(1 - (a/2))

        zsq = z * z

        @minimum.each do |label, minimum|
          np  = @covered.fetch(label, 0)
          p   = np / n
          mid = 2*np + zsq
          off = z * Math.sqrt(zsq - 1/n + 4*np*(1-p) - (4*p-2)) + 1
          lo  = (mid - off) / (2 * (n + zsq))

          return false if lo < minimum
        end
      end

      true
    end

    # TODO
    def failed?(test_count, confidence_level)
      a = 1 - confidence_level
      n = test_count.to_f
      z = _probit(1 - (a/2))

      zsq = z * z

      @minimum.each do |label, minimum|
        np  = @covered.fetch(label, 0)
        p   = np / n
        mid = 2*np + zsq
        off = z * Math.sqrt(zsq - 1/n + 4*np*(1-p) - (4*p-2)) + 1
        hi  = (mid + off) / (2 * (n + zsq))

        return true if hi < minimum
      end

      false
    end

    # Calculates the standard norrmal random variable for which the cumulative
    # probability is `p`, where `0 <= p <= 1`.
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
