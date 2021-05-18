# frozen_string_literal: true

class Forall
  # This class is not meant to be instantiated directly. It represents possible
  # inputs, either randomly sampled (with replacement) or enumerated fully
  class Input
    class << self
      # @param value [Proc | Enumerable]
      def build(value = nil, &block)
        if block_given?
          raise ArgumentError, "both argument and block cannot be given" \
            unless value.nil?

          Some.new(block)
        else
          case value
          when Input
            value
          when Enumerable
            All.new(value)
          when Proc
            Some.new(value)
          when nil
            raise ArgumentError, "argument or block must be given"
          else
            raise TypeError, "argument must be a Forall::Input, Enumerable, or Proc"
          end
        end
      end

      # @param value [Enumerable]
      def exhaustive(value)
        case value
        when Enumerable
          All.new(value)
        else
          raise TypeError, "argument must be Enumerable"
        end
      end

      # @param value [Proc | Array | Enumerator | ... | Enumerable]
      def sampled(value = nil, &block)
        if block_given?
          raise ArgumentError, "both argument and block cannot be given" \
            unless value.nil?

          Some.new(block)
        elsif value.nil?
          raise ArgumentError, "argument or block must be given"
        elsif value.is_a?(Proc)
          Some.new(value)
        elsif value.is_a?(Range) or value.respond_to?(:sample)
          Some.new(lambda{|rnd| rnd.sample(value) })
        elsif value.respond_to?(:to_a)
          array = value.to_a
          Some.new(lambda{|rnd| rnd.sample(array) })
        else
          raise TypeError, "argument must be a Proc or respond_to?(:sample) or respond_to?(:to_a)"
        end
      end
    end

    def shrink(&block)
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

      def each(_random, &block)
        @items.each{|input| block.call(input) }
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
          count.times.map{ @block.call(random) }
        end
      end

      def each(random, *args)
        yield @block.call(random, *args) while true
      end
    end
  end
end
