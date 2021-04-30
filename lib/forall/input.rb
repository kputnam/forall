# frozen_string_literal: true

class Forall
  class Input
    class << self
      # @param value [Proc | Enumerable]
      def build(value = nil, &block)
        if Input === value
          value
        elsif Enumerable === value
          # This includes Range
          All.new(value)
        elsif Proc === value
          Some.new(value)
        elsif block_given?
          Some.new(block)
        else
          raise TypeError, "argument must be a Proc or Enumerable"
        end
      end

      # @param value [Enumerable]
      def exhaustive(value = nil, &block)
        if Enumerable === value
          All.new(value)
        else
          raise TypeError, "argument must be Enumerable"
        end
      end

      # @param value [Proc | Array | Enumerator | ... | Enumerable]
      def sampled(value = nil, &block)
        if block_given?
          Some.new(block)
        elsif Proc === value
          Some.new(value)
        elsif Range === value or value.respond_to?(:sample)
          Some.new(lambda{|rnd| rnd.sample(value) })
        elsif value.respond_to?(:to_a)
          array = value.to_a
          Some.new(lambda{|rnd| rnd.sample(array) })
        else
          raise TypeError, "argument must be a Proc or respond_to?(:sample) or respond_to?(:to_a)"
        end
      end
    end

    def shrink(value = nil, &block)
      if block_given?
        @shrink = block
        self
      else
        @shrink
      end
    end

    # Exhaustive list of possible input values
    class All < Input
      def initialize(items)
        @items  = items
        @shrink = nil
      end

      def exhaustive?
        true
      end

      def sample(random, count: nil)
        random.sample(@items, count: count)
      end

      def each(random, *args)
        @items.each{|input| yield input }
      end

      def size
        @items.size
      end
    end

    # Randomized sample of possible input values
    class Some < Input
      def initialize(block)
        @block  = block
        @shrink = nil
      end

      def exhaustive?
        false
      end

      def sample(random, count: nil)
        if count.nil?
          @block.call(random)
        else
          count.times.map { @block.call(random) }
        end
      end

      def each(random, *args)
        while true
          yield @block.call(random, *args)
        end
      end
    end
  end
end
