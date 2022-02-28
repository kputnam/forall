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
      def clamp(limit)
        if limit.include?(self.begin) and limit.include?(self.end)
          self
        else
          self.begin.clamp(limit)..self.end.clamp(limit)
        end
      end

      # Default implemenntation (from Enumerable) eagerly evaluates all elements
      def map(&block)
        Range.new(block[self.begin], block[self.end], exclude_end?)
      end
    end

    refine ::Enumerator do
      # Default implemenntation (from Enumerable) eagerly evaluates all elements
      def map(&block)
        Enumerator.new do |e|
          each do |x|
            e << block[x]
          end
        end
      end

      # @yieldparam  [A]
      # @yieldreturn [Enumerator<A>]
      # @return      [Enumerator<A>]
      def flat_map(&block)
        Enumerator.new{|e| each{|x| block[x].each{|y| e << y }}}
      end

      def by_need
        Forall::Need.new(self)
      end
    end

    refine ::Enumerator::Chain do
      def by_need
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

    def each(&block)
      return self unless block_given?

      if @enum
        @cache.each do |item_|
          block[item_]
        end

        while true
          begin
            item = @enum.next
            @cache << item
            @enum.feed(block[item])
          rescue StopIteration
            @enum.rewind
            @enum = nil
            return $!.result
          end
        end
      end

      @cache.each{|item_| block[item_] }
    end

    #def map(&block)
    #  super.by_need
    #end

    # @yieldparam  [A]
    # @yieldreturn [Enumerator<A>]
    # @return      [Enumerator<A>]
    #def flat_map(&block)
    #  super.by_need
    #end

    def size
      @enum.size
    end

    def by_need
      self
    end
  end
end
