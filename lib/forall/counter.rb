# frozen_string_literal: true

class Forall
  # This allows the user to control test execution by skipping the current input
  # or labeling the input for reporting at the end of the test
  class Counter
    # @private
    attr_accessor :ok, :no, :skip, :fail, :steps

    # @private
    attr_reader :shrunk, :labels

    def initialize(top: true)
      @ok      = 0
      @no      = 0
      @skip    = 0
      @fail    = 0
      @steps   = 0
      @shrunk  = Counter.new(top: false) if top
      @labels  = Hash.new{|h, k| h[k] = 0 }
      @private = nil
    end

    # @private
    def total
      @ok + @no + @skip + @fail
    end

    # @private
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
