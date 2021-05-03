# frozen_string_literal: true

class Forall
  class Counter
    attr_accessor :ok, :no, :skip, :fail, :steps

    attr_reader :shrunk, :labels

    def initialize(top = true)
      @ok      = 0
      @no      = 0
      @skip    = 0
      @fail    = 0
      @steps   = 0
      @shrunk  = Counter.new(false) if top
      @labels  = Hash.new{|h,k| h[k] = 0 }
      @private = nil
    end

    def total
      @ok + @no + @skip + @fail
    end

    def test
      @ok + @no + @fail
    end

    def skip!
      @skip += 1
      throw :skip, true
    end

    def label!(*names)
      names.each do |x|
        @labels[x] += 1
      end
    end
  end
end
