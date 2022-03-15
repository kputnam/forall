# frozen_string_literal: true

class Forall
  using Forall::Refinements

  class Random < Proc

    def initialize(name = nil)
      name ||= caller[1][/(?<=`)[^']+/]
      @name  = name
      super()
    end

    def sample(prng: ::Random.new, scale: 0)
      self[prng, scale]
    end

    # This is to tag the class as compatible with Enumerable, but we override
    # many of the definitions from Enumerable that would return an Array to
    # defer calling `#each` and instead return `Random<_>` in O(1) time and
    # space.
    #
    # Be aware the implementation of `#each` below does not terminate, so many
    # Enumerable methods will get stuck in an infinite loop. You can limit how
    # many sample are generated using `#take(n)`, then call Enumerable methods
    # on the result.
    #
    # @group Enumerable
    ###########################################################################
    include Enumerable

    # Generates an infinite stream of random samples. The given block must force
    # termination using `break` or `raise` or some other means.
    #
    # @param      [::Random]
    # @yieldparam [Tree<A>]
    def each(prng: ::Random.new)
      if block_given?
        scale = 0

        while true
          yield self[prng, scale]

          scale += 1
          scale  = 0 if scale > 99
        end
      else
        to_enum(:each, prng: prng)
      end
    end

    # @param      [::Random] prng
    # @yieldparam [Tree<A>]
    def cycle(prng: ::Random.new, &block)
      each(prng, &block)
    end

    # Transform the values generated by this random value generator.
    #
    # @yieldparam  [Tree<A>]
    # @yieldreturn [Tree<B>]
    # @return      [Random<B>]
    def map(&block)
      Random.new("#{@name}.map") do |prng, scale|
        self[prng, scale].map(&block)
      end
    end

    # Use a randomly generated value as an input parameter for randomly
    # generating another value.
    #
    # @yieldparam  [A]
    # @yieldreturn [Random<B>]
    # @return      [Random<B>]
    def flat_map(&block)
      Random.new("#{@name}.flat_map") do |prng, scale|
        tree = self[prng, scale]
        tree.flat_map do |x|
          # This creates the random tree generator
          rand_ = block[x]
          raise TypeError, "block did not return a Random" unless rand_.is_a?(Random)

          # This invokes the random tree generator
          rand_[prng, scale]
        end
      end
    end

    # Generates random values until one satisfies the predicate, but gives up
    # and calls `.discard` if no successful samples are drawn after 100 tries.
    #
    # @yieldparam  [A]
    # @yieldreturn [Boolean]
    # @return      [Random<A>]
    def filter(&block)
      Random.new("#{@name}.filter") do |prng, scale|
        catch(:done) do
          100.times do |n|
            # Remember `x` is a `Tree<A>`, so see `Tree#filter` to understand
            # what's happening here
            x = self[prng, (2*n) + scale]
            x = x.filter(&block)
            throw(:done, x) if x
          end

          Random.discard
        end
      end
    end

    def compact
      filter{|x| !x.nil? }
    end

    def grep(pattern, &block)
      if block_given?
        filter{|x| x =~ pattern }.map(&block)
      else
        filter{|x| x =~ pattern }
      end
    end

    def grep_v(pattern, &block)
      if block_given?
        filter{|x| x !~ pattern }.map(&block)
      else
        filter{|x| x !~ pattern }
      end
    end

    def filter_map(&block)
      map(&block).filter{|x| x }
    end

    def zip(*others)
      Random.sequence(self, *others)
    end

    # @endgroup
    ###########################################################################

    # Apply a randomly generated function to a randomly generated argument.
    #
    #   identity:
    #     Random.constant(lambda{|x| x }).ap(x) == x
    #
    #   homomorphism:
    #     Random.constant(f).ap(Random.constant(x)) == Random.constant(f[x])
    #
    #   interchange:
    #     f.ap(Random.constant(x)) == Random.constant(lambda{|f| f[x]}).ap(f)
    #
    #   composition:
    #     Random.constant(&:<<).ap(Random.constant(f)).ap(Random.constant(g)).ap(x)
    #       == Random.constant(f).ap(Random.constant(g).ap(x))
    #
    # @self   [Random<Proc<A, B>>]
    # @param  [Random<A>]
    # @return [Random<B>]
    def ap(*args)
      Random.new("#{@name}.ap") do |prng, scale|
        fs = self[prng, scale]
        xs = args[prng, scale]

        fs.zip(xs){|f, x| f[x] }
      end
    end

    # @yieldparam  [A]
    # @yieldreturn [Enumerable<A>]
    # @return      [Random<A>]
    def shrink(&block)
      Random.new(@name) do |prng, scale|
        self[prng, scale].expand(&block)
      end
    end

    def rename(name)
      @name = name
      self
    end

    def inspect
      "#{self.class.name[/(?<=::).+$/]}.#{@name}"
    end
  end

  class << Random
    # This is the `unit` operation for the Random applicative algebraic
    # structure. Eg,
    #
    #   random.flat_map{|n| Random.unit(n) }    == n
    #   random.flat_map{|n| Random.unit(f(n)) } == random.map{|n| f(n) }
    #
    # @param  [A] value
    # @return [Random<A>]
    def unit(value)
      Random.new{|_prng, _scale| Tree.leaf(value) }
    end

    alias_method :pure,     :unit
    alias_method :constant, :unit

    def scale
      Random.new{|_, scale| Tree.leaf(scale) }
    end

    def prng
      Random.new{|prng, _| Tree.leaf(prng) }
    end

    # @param  [Enumerable<Random<A>, Random<B>, ...>]
    # @return [Random<Array<A, B, ...>]
    def sequence(*randoms)
      randoms.reduce(pure([])) do |mxs, mx|
        mx.flat_map{|x| mxs.map{|xs| [*xs, x] }}
      end.rename("sequence(#{randoms.inspect[1..-2]})")
    end

    # @group Discrete probability distributions
    ###########################################################################

    # @param  [Float]           p
    # @return [Random<Integer>] either 0 or 1
    def bernoulli(p)
      raise RangeError unless p.between?(0, 1)

      float_(Bounds.constant(0..1))
        .map{|x| x <= p }
        .shrink{|x| (x == 1 && [0]) || [] }
        .rename("bernoulli(#{mean})")
    end

    # @param  [Integer]         n
    # @param  [Float]           p
    # @return [Random<Integer>] between 0 and n
    def binomial(n, p)
      raise "@todo"
    end

    # @return [Random<Integer>]
    def geometric(p)
      raise RangeError, "p must be within 0..1" unless p.between?(0, 1)

      Random.new do |prng, _scale|
        next 0 if p == 1

        q = _uniform_01_positive(prng)
        (Math.log(q) / Math.log(1 - p)).floor
      end
    end

    # @return [Random<Integer>]
    def negative_binomial(r, p)
      raise "@todo"
    end

    # @return [Random<Integer>]
    def hypergeometric(w, b, n)
      raise "@todo"
    end

    # @return [Random<Integer>]
    def poisson(λ)
      raise "@todo"
    end

    # @group Continuous probability distributions
    ###########################################################################

    # @return [Random<Float>]
    def uniform(range)
      float(range).rename("uniform")
    end

    # @return [Random<Float>]
    def normal(μ, s)
      Random.new do |prng, _scale|
        # Choose u1 and u2 from a uniform distribution on the interval (0, 1)
        u1 = prng.rand
        u2 = prng.rand

        # Using the Box-Muller method, z is a random variable with standard
        # normal distribution, N(0, 1).
        z = Math.sqrt(-2 * Math.log(u1)) * Math.cos(2 * Math::PI * u2)

        # N(μ, variance) can be generated from N(0, 1) like so
        μ + (s * z)
      end.rename("normal(#{μ}, #{s})")
    end

    # This is practically 0..1, but no divide by zero or log(0)
    def _uniform_01_positive(prng)
      prng.rand(2.710505431213761e-20..1)
    end

    # @return [Random<Float>]
    def exponential(λ)
      Random.new do |prng, _scale|
        -Math.log(_uniform_01_positive(prng)) / λ
      end.rename("exponential(#{λ})")
    end

    # @param  [Float] lambda_
    # @return [Random<Float>]
    def gamma(α, β)
      raise RangeError, "α must be positive" if α <= 0

      α0 = (α < 1) ? α + 1 : α
      α1 = α0 - (1/3.0)
      α2 = 1 / Math.sqrt(9 * α1)

      Random.new do |prng, scale|
        while true
          while true
            x = normal(0, 1)[prng, scale]
            v = 1 + (α2 * x)
            break if v > 0
          end

          v = x*x*x
          u = _uniform_01_positive(prng)

          if u <= 1 - (0.331 * _square(x*x)) or Math.log(u) < (0.5 * _square(x)) + (α1 * (1 - v + Math.log(v)))
            break if α >= 1

            α1 *= y ** (1/α)
          end
        end

        α1 * v * β
      end.rename("gamma(#{α}, #{β})")
    end

    def _square(x)
      x * x
    end

    # @return [Random<Float>]
    def beta(α, β)
      gamma(α, 1).flat_map do |x|
        gamma(β, 1).map    do |y|
          x / (x + y)
        end
      end.rename("beta(α, β)")
    end

    # @return [Random<Float>]
    def chi_square(n)
      raise "@todo"
    end

    # @return [Random<Float>]
    def student_t(n)
      raise "@todo"
    end

    # @endgroup
    ###########################################################################

    # @return [Random<TrueClass | FalseClass>]
    def boolean
      integer(0..1).map{|x| x == 1 }.rename("boolean")
    end

    # Generates a random number within the given range [inclusive, inclusive].
    #
    # @param  bounds [Bounds<A>]
    # @return        [Random<A>]
    def integer(bounds)
      bounds = Bounds.build(bounds)

      Random.new("integer(#{bounds.inspect})") do |prng, scale|
        numeric_tree(prng.rand(bounds.range(scale).map(&:round)), bounds.origin)
      end
    end

    # Generates a random number within the given range [inclusive, inclusive].
    # This generator does not shrink
    #
    # @param  bounds [Bounds<A>]
    # @return        [Random<A>]
    def integer_(bounds)
      bounds = Bounds.build(bounds)

      Random.new("integer_(#{bounds.inspect})") do |prng, scale|
        Tree.leaf(prng.rand(bounds.range(scale).map(&:round)))
      end
    end

    # Generates a random number within the given range [inclusive, inclusive].
    #
    # @param  bounds [Bounds<A>]
    # @return        [Random<A>]
    def float(bounds)
      bounds = Bounds.build(bounds)

      Random.new("float(#{bounds.inspect})") do |prng, scale|
        numeric_tree(prng.rand(bounds.range(scale).map(&:to_f)), bounds.origin.to_f)
      end
    end

    # Generates a random number within the given range [inclusive, inclusive].
    # This generator does not shrink
    #
    # @param  bounds [Bounds<A>]
    # @return        [Random<A>]
    def float_(bounds)
      bounds = Bounds.build(bounds)

      Random.new("float_(#{bounds.inspect})") do |prng, scale|
        Tree.leaf(prng.rand(bounds.range(scale).map(&:to_f)))
      end
    end

    # @param  bounds [Bounds<Range<Complex>>]
    # @return [Random<Range<Complex>>]
    def complex(bounds)
      raise "@todo"
    end

    # @todo
    # @param  bounds [Bounds<Range<A>>]
    # @return [Random<Range<A>>]
    def range(bounds)
      raise "@todo"
    end

    # @param  items [#[], #length]
    # @param  count [Integer]
    # @return [Random<A> | Random<Array<A>>]
    def choose(items)
      raise ArgumentError, "items cannot be empty" if items.empty?

      integer(Bounds.constant(0..items.length-1)).map{|n| items[n] }.rename("choose(#{items.size} items)")
    end

    # @param  items   [Array<A>]
    # @param  weights [Array<Numeric>]
    # @param  count   [Integer]
    # @return [Random<A>]
    def weighted(items, weights)
      raise ArgumentError "items and weights must have the same size" unless items.size == weights.size

      raise ArgumentError, "items cannot be empty" if items.empty?

      Random.new do |prng, _|
        weights_ = weights.map{|w| prng.rand(1.0) ** (1 / w.to_f) }
        best_w   = 0
        best_k   = -1

        weights_.each_with_index do |w, k|
          if w > best_w
            best_k = k
            best_w = w
          end
        end

        items[best_k]
      end
    end

    # @param  items [Array<A>]
    # @return [Random<Array<A>>]
    def permutation(items)
      Random.new do |prng, _|
        index = (0..items.length-1).to_a.shuffle!

        # @TODO: How should this be shrunk? Possibly the minimal state would be
        # the original array (index = 0..n-1), and each level of the tree could
        # transpose items such that more and more elements are in their original
        # place.
        Tree.leaf(index.map{|k| items[k] })
      end
    end

    # @param  items [Bounds<A>]
    # @param  size  [Bounds<Integer>]
    # @return [Random<Array<A>>]
    def subsequence(items, size)
      raise "@todo"
    end

    # @param  length [Bounds]
    # @param  item   [Random<A>]
    # @return [Random<Array<A>>]
    def array(size, item)
      integer_(size).flat_map do |n|
        Random.new("array(#{length})") do |prng, scale_|
          min = length.begin(scale_)

          Tree.interleave(n.times.map{|_| item[prng, scale_] })
              .filter{|xs| xs.size >= min }
        end
      end.rename("array(#{size.inspect})")
    end

    # @param size  [Bounds<Integer>]
    # @param item  [Random<A>]
    # @return      [Random<Set<A>>]
    def set(size, item)
      integer_(size).flat_map do |n|
        Random.new("set(#{length})") do |prng, scale_|
          min  = length.begin(scale_)
          uniq = {}

          (n + 100).times do
            x = item[prng, scale_]
            uniq[x.value] = x
            break if uniq.size >= n
          end

          discard if uniq.size < n

          # Make sure shrunken sets aren't too small
          Tree.interleave(uniq.values).map(&:to_set)
              .filter{|s| s.size >= min }
        end
      end.rename("set")
    end

    # @param  size  [Bounds<Integer>]
    # @param  key   [Random<K>]
    # @param  val   [Random<V>]
    # @return [Random<Hash<K, V>>]
    def hash(length, pair)
      integer_(length).flat_map do |n|
        Random.new("hash(#{length})") do |prng, size|
          min  = length.begin(size)
          uniq = {}

          (n + 100).times do
            x = pair[prng, size]
            uniq[x.value[0]] = x
            break if uniq.size >= n
          end

          discard if uniq.size < n

          # Make sure shrunken hash tables aren't too small
          Tree.interleave(uniq.values).map(&:to_h)
              .filter{|h| h.size >= min }
        end
      end
    end

    ###########################################################################

    # Generate ASCII binary digit "0" or "1"
    #
    # @return [Random<String>]
    def binit
      integer(Bounds.constant(0..1)).map(&:to_s).rename("binit")
    end

    # Generate ASCII octal digit "0".."7"
    #
    # @return [Random<String>]
    def octit
      interer(Bounds.constant(0..7)).map(&:to_s).rename("octit")
    end

    # Generate ASCII decimal digit "0".."9"
    #
    # @return [Random<String>]
    def digit
      integer(Bounds.constant(0..9)).map(&:to_s).rename("digit")
    end

    # Generate ASCII hexadecimal digit "0".."9", "A".."F"
    #
    # @return [Random<String>]
    def hexit
      choose("0123456789ABCDEF".chars).rename("hexit")
    end

    # Generate ASCII lowercase letter "a".."z"
    #
    # @return [Random<String>]
    def lowercase
      integer(Bounds.constant("a".ord.."z".ord)).map(&:chr).rename("lowercase")
    end

    # Generate ASCII uppercase letter "A".."Z"
    #
    # @return [Random<String>]
    def uppercase
      integer(Bounds.constant("A".ord.."Z".ord)).map(&:chr).rename("uppercase")
    end

    # Generate ASCII letter "a".."z", "A".."Z"
    #
    # @return [Random<String>]
    def alpha
      choose("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ".chars).rename("alpha")
    end

    # Generate ASCII letter or digit "a".."z", "A".."Z", "0".."9"
    #
    # @return [Random<String>]
    def alphanum
      choose("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789".chars).rename("alphanum")
    end

    # Generate an ASCII character "\0".."\127"
    #
    # @return [Random<String>]
    def ascii
      integer(Bounds.constant(0..127)).map{|n| n.chr(Encoding::ASCII) }.rename("ascii")
    end

    # Generate an 8-bit Latin character "\0".."\255"
    #
    # @return [Random<String>]
    def latin
      integer(Bounds.constant(0..127)).map{|n| n.chr(Encoding::ISO_8859_1) }.rename("latin")
    end

    #
    #
    # @return [Random<Integer>]
    def byte
      integer(Bounds.constant(0..255)).map{|n| n.chr(Encoding::ASCII_8BIT) }.rename("byte")
    end

    # Generate a Unicode character, excluding noncharacters and invalid
    # standalone surrogates: "\0".."\1113111" excluding "\55296".."\57343",
    # "\65534".."\65535"
    #
    # @return [Random<String>]
    def utf8
      weighted([55296,   integer(Bounds.constant(0, 55295)),
                8190,    integer(Bounds.constant(57344, 65533)),
                1048576, integer(Bounds.constant(65536, 1114111))])
        .map{|n| n.chr(Encoding::UTF_8) }.rename("utf8")
    end

    #
    #
    # @return [Random<String>]
    def utf8_all
      integer(Bounds.constant(0, 1114111)).map{|n| n.chr(Encoding::UTF_8) }.rename("utf8_all")
    end

  private

    # @!group Helper methods
    ###########################################################################

    def numeric_tree(root, origin)
      if root == origin
        Tree.leaf(origin)
      else
        _numeric_tree(root, origin).prepend_children([Tree.leaf(origin)].each)
      end
    end

    def _numeric_tree(x, origin)
      return Tree.leaf(x) if x == origin

      Tree.new(x, Enumerator.new do |e|
        b = x - origin

        while true
          a = b / 2

          # Due to the finite precision of floating point values, when a is much
          # smaller than a, the difference cannnot be represented precisely and
          # the closest representable value is x. This means a is effectively
          # zero, even though a == 0 is false.
          break if x - a == x

          # Prevent an infinite loop when b == -1, because a = -1/2 == -1
          break if a == b

          e << _numeric_tree(x - a, x - b)
          b = a
        end
      end)
    end

    # @!endgroup
    ###########################################################################
  end

end
