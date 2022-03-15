# frozen_string_literal: true

class Forall
  module Refinements
    refine ::Numeric do
      # Returns -1 if self < 0, 0 if self == 0, or +1 if self > 0
      def signum
        self <=> 0
      end
    end

    refine ::Integer do
      # Counterpart to Float#nan?
      def nan?
        false
      end

      # Counterpart to Float#infinite?
      def infinite?
        false
      end
    end

    refine ::Range do
      # Returns a smaller Range that fits within the given limit Range
      #
      # @param  [Range] limit
      # @return [Range]
      def clamp(limit)
        if limit.include?(self.begin) and limit.include?(self.end)
          self
        else
          self.begin.clamp(limit)..self.end.clamp(limit)
        end
      end

      # It usually makes more sense for `#map` to return the same type as its
      # receiver. The implementation for `Range#map` (from Enumerable) converts
      # to array, then maps over each element.
      #
      # @example
      #   (1..5).map{|x| x * 2} #=> 2..10
      #
      # @yieldparam  [A]
      # @yieldreturn [B]
      # @return      [Range<B>]
      def map(&block)
        Range.new(block[self.begin], block[self.end], exclude_end?)
      end
    end

    refine ::Enumerator do
      # Default implementation (from Enumerable) eagerly evaluates all elements
      #
      # @example
      #   [1, 2, 3].each.map{|x| x + 1 } #=> Enumerator
      #
      # @return  [Enumerator]
      def map(&block)
        Enumerator.new do |e|
          each do |x|
            e << block[x]
          end
        end
      end

      # Default implementation (from Enumerable) eagerly evaluates all elements
      #
      # @example
      #   [1, 2, 3].each.flat_map{|x| [1**x, 2**x, 3**x] } #=> Enumerator
      #
      # @yieldparam  [A]
      # @yieldreturn [Enumerator<A>]
      # @return      [Enumerator<A>]
      def flat_map(&block)
        Enumerator.new{|e| each{|x| block[x].each{|y| e << y }}}
      end

      def as_needed
        Forall::Need.new(self)
      end
    end

    refine ::Enumerator::Chain do
      # There's no means to directly access the enumerators that comprise this
      # chain of enumerators, so we just have to assume that each component is
      # already an instance of `Need`
      def as_needed
        self
      end
    end
  end

  class Need < Enumerator
    def initialize(enum)
      @enum  = enum
      @cache = []
      super(){|e| }
    end

    def as_needed
      self
    end

    def each(&block)
      return self unless block_given?

      if @enum
        # This is written to allow each { .. } to stop early. The next call to
        # each will use the cached items at the start, then resume iteration of
        # the underlying enum.
        @cache.each do |item|
          block[item]
        end

        while true
          begin
            item_  = @enum.next
            @cache << item_
            @enum.feed(block[item_])
          rescue StopIteration
            @enum.rewind
            @enum = nil
            return $!.result
          end
        end
      end

      @cache.each{|item| block[item] }
    end

    def size
      @enum.size
    end
  end
end
