# frozen_string_literal: true

class Forall
  class Shrink
    def boolean(x)
      x ? [false] : []
    end

    def integer(x, range = 0..2**64-1)
    end

    def float(x, range = 0..Float::MAX)
    end

    def string
      # TODO
    end

    def date
      # TODO
    end

    def time
      # TODO
    end

    def datetime
      # TODO
    end

    def range(x, range = nil, width: nil)
    end

    def sample(items, count: nil)
    end

    alias_method :choose, :sample

    def permutation(x, size: nil)
    end

    def array(xs, size: nil)
    end

    def hash(x, size: nil)
    end

    def set(x, size: nil)
    end
  end
end
