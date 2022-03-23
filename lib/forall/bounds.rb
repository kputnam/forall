# frozen_string_literal: true

# :nodoc:
class Forall
  using Forall::Refinements

  # Describes the bounds of a number (integer or float) to generate. The
  # constructor takes a function from an integer `size` (0..99) to a Range
  # representing lower and upper bounds, and an `origin` between these bounds.
  # As `size` approaches 0, the upper and lower bounds approach the `origin`.
  #
  # This class can represent bounds on any data type that can be mapped onto
  # Numeric and back. For instance, `Time` can be converted to a `Float` and
  # then back to `Time`.
  #
  class Bounds
    attr_reader :origin

    # @param origin [Numeric]
    # @param bounds [Proc<Size, Range<Numeric>>]
    def initialize(origin, convert = nil, name: nil, &bounds)
      raise ArgumentError, "no block given"                     unless block_given?
      raise ArgumentError, "block must take exactly 1 argument" unless bounds.arity == 1
      raise TypeError, "block must return a Range"              unless bounds[0].is_a?(Range)

      @origin  = origin
      @bounds  = bounds || singlton_class::ID
      @convert = convert

      name ||= caller[1][/(?<=`)[^']+/]
      @name  = name
    end

    # @return [String]
    def inspect
      if @name =~ /^constant/
        @name[/(?<=\()[^)]+/]
      else
        "#{self.class.name[/(?<=::).+$/]}.#{@name}"
      end
    end

    # @yieldparam  [A]
    # @yieldreturn [B]
    # @return      [Range<B>]
    def map(&block)
      Bounds.new(@origin, block << @convert, &@bounds)
    end

    # @return [Numeric]
    def range(size)
      @bounds[size].map(&@convert)
    end

    # @return [Numeric]
    def begin(size)
      @convert[@bounds[size].begin]
    end

    # @return [Numeric]
    def end(size)
      @convert[@bounds[size].end]
    end

    # @return [Numeric]
    def begin_(size)
      @bounds[size].begin
    end

    def end_(size)
      @bounds[size].end
    end

    def range_(size)
      @bounds[size]
    end
  end

  class << Bounds
    def build(value)
      case value
      when Bounds
        value
      when Range
        constant(value)
      else
        raise TypeError
      end
    end

    # Construct a range which represents a constant single value
    #
    # @param origin [A]
    def singleton(origin)
      range, origin, f = coerce(origin..origin, origin)
      new(origin, f, name: "singleton(#{origin})"){|_size| range }
    end

    # Construct a range which is unaffected by the size parameter
    #
    # @param range  [Range<A>]
    # @param origin [A]
    def constant(range, origin: nil)
      raise ArgumentError, "origin must be bound by #{range.inspect}" \
        unless origin.nil? or range.include?(origin)

      range, origin, f = coerce(range, origin)
      new(f[origin || range.begin], f, name: "constant(#{range})"){|_size| range }
    end

    # Construct a range which scales the upper bound linearly relative to the size parameter
    #
    # @param range  [Range<A>]
    # @param origin [A]
    def linear(range, origin: nil)
      raise ArgumentError, "origin must be bound by #{range.inspect}" \
        unless origin.nil? or range.include?(origin)

      origin         ||= range.begin
      range, origin, f = coerce(range, origin)

      if origin.is_a?(Integer) and range.begin.is_a?(Integer) and range.end.is_a?(Integer)
        new(f[origin], f, name: "linear(#{range}, #{origin})") do |size|
          lo = linear_scale(size, origin, range.begin)
          hi = linear_scale(size, origin, range.end)
          (lo..hi).clamp(range)
        end
      else
        new(f[origin], f, name: "linear(#{range}, #{origin})") do |size|
          lo = linear_scale_frac(size, origin, range.begin)
          hi = linear_scale_frac(size, origin, range.end)
          (lo..hi).clamp(range)
        end
      end
    end

    # Construct a range which scales the upper bound exponentially relative to the size parameter
    #
    # @param range  [Range<A>]
    # @param origin [A]
    def exponential(range, origin: nil)
      raise ArgumentError, "origin must be bound by #{range.inspect}" \
        unless origin.nil? or range.include?(origin)

      origin         ||= range.begin
      range, origin, f = coerce(range, origin)

      new(f[origin], f, name: "exponential(#{range}, #{origin})") do |size|
        lo = exponential_scale(size, origin, range.begin).round
        hi = exponential_scale(size, origin, range.end).round
        (lo..hi).clamp(range)
      end

      # @TODO: Do fractional values need a special case?
    end

  private

    def linear_scale(size, origin, value)
      (((value - origin + (value - origin).signum) * size) / 99) + origin
    end

    def linear_scale_frac(size, origin, value)
      k = value - origin
      ((k * size) / 99) + origin
    end

    def exponential_scale(size, origin, value)
      k = value - origin
      x = size / 99.0

      ((((k.abs + 1) ** x) - 1) * k.signum) + origin
    end

    # Common conversion methods
    ID = lambda{|x| x }
    JD = lambda{|x| Date.jd(x) }

    # @param  [Range<A, A>] range
    # @param  [A]           origin
    def coerce(range, origin)
      hint = range.begin || range.end || origin

      raise TypeError, "range and origin must all be of same type (#{hint.class})" \
        unless (range.begin.nil? or range.begin.instance_of?(hint.class)) \
           and (range.end.nil?   or range.end.instance_of?(hint.class)) \
           and (origin.nil?      or origin.instance_of?(hint.class))

      if hint.is_a?(Numeric)
        [range, origin, ID]
      elsif defined?(Date) and hint.is_a?(Date)
        lo     = range.begin&.jd
        hi     = range.end&.jd
        origin = origin&.jd
        [lo..hi, origin, JD]
      elsif defined?(Time) and hint.is_a?(Time)
        lo     = range.begin&.to_f
        hi     = range.end&.to_f
        origin = origin&.to_f
        [lo..hi, origin, lambda{|x| Time.at(x, in: (lo || hi || origin)&.tz) }]
      elsif hint.is_a?(String)
        # @TODO: This only works for single-character strings
        unless (lo.nil?     or lo.length     == 1) \
           and (hi.nil?     or hi.lengh      == 1) \
           and (origin.nil? or origin.length == 1)
          raise ArgumentError "only single-character Strings supported"
        end

        enc = (lo || hi || origin).encoding
        [lo&.ord..hi&.ord, origin&.ord, lambda{|x| x.chr(enc) }]
      elsif hint.is_a?(Range)
        # @TODO: This should be possible somehow. The size parameter would
        # control the width of the Range and how far its bounds are from the
        # bounds of the origin Range
        raise TypeError, "Bounds<Range<A>> is not implemented"
      else
        # @TODO
        raise TypeError
      end
    end
  end
end
