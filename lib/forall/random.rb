# frozen_string_literal: true

class Forall
  class Random
    def initialize(seed: nil)
      @prng = ::Random.new(seed || ::Random.new_seed)
    end

    # @return [Integer]
    def seed
      @prng.seed
    end

    # @return [TrueClass | FalseClass]
    def boolean
      @prng.rand >= 0.5
    end

    # Returns a randomly chosen integer within the given bounds
    #
    # @param range [Range<Integer>]
    # @return [Integer]
    def integer(range = nil)
      min = range&.min || -2**64-1
      max = range&.max ||  2**64+1
      @prng.rand(min..max)
    end

    # Returns a randomly chosen floating point number
    #
    # @paoram range [Range<Float>]
    # @return [Float]
    def float(range = nil)
      min = range&.min || Float::MIN
      max = range&.max || Float::MAX
      @prng.rand(min..max)
    end

    # Returns a randomly chosen Date within the given bounds
    #
    # @param range [Range<Date>]
    # @return [Date]
    def date(range = nil)
      min = (range&.min || Date.civil(0000, 1, 1)).to_time
      max = (range&.max || Date.civil(9999,12,31)).to_time + 86399
      Time.at(float(min.to_f .. max.to_f)).to_date
    end

    # Returns a randomly chosen Time within the given bounds
    #
    # @param range [Range<Time>]
    # @return [Time]
    def time(range = nil, utc: nil)
      min = range&.min || Time.utc(0000,1,1,0,0,0)
      max = range&.max || Time.utc(9999,12,31,23,59,59)
      rnd = float(min.to_f .. max.to_f)

      if utc or (utc.nil? and (min.utc? or max.utc?))
        Time.at(rnd).utc
      else
        Time.at(rnd)
      end
    end

    # Returns a randomly chosen DateTime within the given bounds
    #
    # @param range [Range<DateTime>]
    # @return [DateTime]
    def datetime(range = nil)
      min = range&.min&.to_time
      max = range&.max&.to_time
      time(min..max).to_datetime
    end

    # Returns a randomly chosen range within the given bounds
    #
    # @param range [Range<Object>]
    # @param width [Integer]
    # @return [Range]
    def range(range, width: nil)
      min = range.min
      max = range.max

      if width.nil?
        case min or max
        when Float
          a = float(range)
          b = float(range)
        when Integer
          a = integer(range)
          b = integer(range)
        when Time
          a = time(range)
          b = time(range)
        when Date
          a = date(range)
          b = date(range)
        when DateTime
          a = datetime(range)
          b = datetime(range)
        else
          a, b = choose(range, count: 2)
        end

        if a < b
          min = a
          max = b
        else
          min = b
          max = a
        end
      else
        # Randomly choose a width within given bounds
        width = choose(width) if Enumerable === width

        case min or max
        when Float
          min = float(min: min, max: max-width)
          max = min+width-1
        when Integer
          min = integer(min: min, max: max-width)
          max = min+width-1
        else
          all = (min..max).to_a
          max = all.size-1

          # Randomly choose element indices
          min = integer(min: 0, max: max-width)
          max = min+width-1

          min = all[min]
          max = all[max]
        end
      end

      min..max
    end

    # Returns a uniformly random chosen element(s) from the given Enumerable
    #
    # @param items [Input::Some | Input::All | Range | Array]
    # @return [Object]
    def sample(items, count: nil)
      case items
      when Input
        items.sample(self, count: count)
      when Range
        method =
          if                           Integer  === (items.min || items.max) then :integer
          elsif                        Float    === (items.min || items.max) then :float
          elsif                        Time     === (items.min || items.max) then :time
          elsif defined?(Date)     and Date     === (items.min || items.max) then :date
          elsif defined?(DateTime) and DateTime === (items.min || items.max) then :datetime
          else
            # NOTE: This is memory inefficient
            items = items.to_a

            if count.nil?
              return items.sample(random: @prng)
            else
              return count.times.map{|_| items.sample(random: @prng) }
            end
          end

        if count.nil?
          send(method, items)
        else
          count.times.map{|_| send(method, items) }
        end
      else
        unless items.respond_to?(:sample)
          # NOTE: This works across many types but is memory inefficient
          items = items.to_a
        end

        if count.nil?
          items.sample(random: @prng)
        else
          # Sample *with* replacement
          count.times.map{|_| items.sample(random: @prng) }
        end
      end
    end

    alias_method :choose, :sample

    # Returns a uniformly random chosen element(s) from the given Enumerable
    #
    # @param items [Array<Object>]
    # @param freqs [Array<Numeric>]
    # @param count [Numeric]
    # @return [Object]
    def weighted(items, freqs, count: nil)
      unless items.size == freqs.size
        raise ArgumentError, "items and frequencies must have same size"
      end

      # This runs in O(n) time where n is the number of possible items. This is
      # not dependent on `count`, the number of requested items.
      if count.nil?
        sum = freqs[0].to_f
        res = items[0]

        (1..items.size - 1).each do |i|
          sum += freqs[i]
          p = freqs[i] / sum
          j = @prng.rand
          res = items[i] if j <= p
        end
      else
        sum = freqs[0, count].sum.to_f
        res = items[0, count]

        (count..items.size).each do |i|
          sum += freqs[i]
          p = count * freqs[i] / sum
          j = @prng.rand
          res[@prng.rand(count)] = items[i] if j <= p
        end
      end

      res
    end

    # @param items [Array<A>]
    # @return [Array<A>]
    def shuffle(items)
      items.shuffle(random: @prng)
    end

    # Generates a random permutation of the given size
    #
    # @param size [Intege]
    # @return [Array<Integer>]
    def permutation(size: nil)
      (0..(size || integer(0..64))-1).to_a.shuffle!(random: @prng)
    end

    # Generates an Array by repeatedly calling a block that returns a random
    # value.
    #
    # @example
    #   rnd.array         {|n| n }          #=> [0,1,2,3,...]
    #   rnd.array(10..50) { integer(0..9) } #=> [8,2,1,1,...]
    #
    # @return Array
    def array(size: nil)
      size ||= integer(0..64)
      size = choose(size) if Range === size
      size.times.map{|n| yield n }
    end

    # Generates a Hash by repeatedly calling a block that returns a random [key,
    # val] pair.
    #
    # @yieldparam [Integer]
    # @yieldreturn [Array<K, V>]
    # @return [Hash<K, V>]
    def hash(size: nil)
      size ||= integer(0..64)
      size = choose(size) if Range === size
      hash = {}

      until hash.size >= size
        k, v = yield(hash.size)
        hash[k] = v
      end

      hash
    end

    def set(size: nil)
      size ||= integer(0..64)
      size = choose(size) if Range === size
      set  = Set.new

      until set.size == size
        set << yield(set.size)
      end

      set
    end
  end
end
