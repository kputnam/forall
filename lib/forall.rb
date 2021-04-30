# frozen_string_literal: true

class Forall
  autoload :Input,    "forall/input"
  autoload :Random,   "forall/random"
  autoload :Counter,  "forall/counter"
  autoload :Matchers, "forall/matchers"

  # The property was true of all tested inputs
  Ok = Struct.new(:seed, :counter)

  # The property was not true of at least one tested input
  No = Struct.new(:seed, :counter, :counterexample)

  # Couldn't find enough suitable inputs to test
  Vacuous = Struct.new(:seed, :counter)

  # An error occurred while checking the property
  Fail = Struct.new(:seed, :counter, :counterexample, :error)

  # TODO: Is there a way to provide a default implementation of `shrink`? Will
  # it interefere with a user-given implementation?

  Options = Struct.new(
    :max_ok,      # Stop looking for counterexamples after this many inputs pass
    :max_skip,    # Give up if more than this many inputs are skipped
    :max_shrink)  # Number of similar inputs to evaluate when searching for simpler counterexamples

  class << self
    def check(input, random, options = nil, &prop)
      options            ||= Options.new
      options.max_shrink ||= 100

      if input.exhaustive?
        options.max_ok   ||= input.size * 0.90
        options.max_skip ||= input.size * 0.10
      else
        options.max_ok   ||= 100
        options.max_skip ||= options.max_ok * 0.10
      end

      if prop.arity == 1
        _prop = prop
        prop  = lambda{|x,_| _prop.call(x) }
      end

      raise ArgumentError, "property must take one or two arguments" \
        unless prop.arity == 2

      counter = Counter.new

      input.each(random) do |example|
        return Ok.new(random.seed, counter)      if counter.ok   >= options.max_ok
        return Vacuous.new(random.seed, counter) if counter.skip >= options.max_skip

        catch(:skip) do
          if prop.call(example, counter)
            counter.ok += 1
          else
            return no(random, counter, input.shrink, example, options, prop)
          end
        end
      rescue Exception => error
        counter.fail += 1
        return fail(random, counter, input.shrink, example, options, prop, error)
      end

      # Didn't meet ok_max because input was exhausted
      Ok.new(random.seed, counter)
    end

  private

    def weight(xs, min, max)
      n = xs.length.to_f
      r = max - min
      xs.map.with_index{|x, k| [x, max-r*k/n] }
    end

    def _weight(xs, min, max)
      n = xs.length.to_f
      r = max - min
      xs.map.with_index{|x, k| C.new(x, max-r*k/n, 0) }
    end

    C = Struct.new(:value, :fitness, :heuristic, :note)

    # Search for the simplest counterexample
    def no(random, counter, shrink, shrunk, options, prop)
      return No.new(random.seed, counter, shrunk) if shrink.nil?

      # The problem of finding the smallest counterexample can be described in
      # terms of local search. The search space has a graph structure (think of
      # a tree with duplicate nodes) and candidate solutions are examples drawn
      # from the domain over which the property holds. The criterion to be
      # maximized is the simplicity of a counterexample -- simple is not meant
      # in any particular formal sense. The neighborhood relation is described
      # by the user-provided function `shrink`, which should return candidate
      # solutions that are only incrementally simpler than its argument.
      #
      # For ease of use, the user does not need to provide a function to
      # calculate the criterion (simplicity) of a candidate solution. Instead,
      # it is inferred by the number of edges in its path from the root and by
      # the relative order in which it was returned among other candidate
      # solutions (the first being simplest). There is also no requirement for
      # a user-supplied heuristic to rank partial solutions, as it would often
      # be difficult to estimate an optimal solution let alone calculate some
      # quantifiable difference between it and any other partial solution.
      #
      # The solution space is finite (eventually `shrink` must return an empty
      # list), but because we have a self-imposed computational budget, its not
      # feasible to exhaustively search for the deepest leaf in the tree. We can
      # conjure a heuristic based on a candidate solution's ratio of ancestors
      # that are examples or counterexamples. If one candidate solution was
      # generated among many which did not disprove the property, and another
      # candidate solution was generated among many counterexamples, we will
      # assume the first candidate is less likely to produce more
      # counterexamples than the second.
      #
      #                           shrunk
      #                             |
      #                       [✓]  [✕]  [✓]
      #                       1.0  0.8  0.6
      #                      /            \
      #                [✕] [✓] [✕]      [✓] [✓]
      #                2.0 1.8 1.6      1.6 1.4
      #               /     /     \     /     \
      #
      # The computational budget is in terms of how many candidate solutions we
      # will test to determine if they are counterexamples. As a result, the
      # heuristic value of a candidate solution would seem to require testing
      # each of its ancestors and their siblings. For now that is what we'll do,
      # but in the future there may be a way to make do with partial information
      # and reserve the budget for exploring the tree more deeply.

      fitness  = 0
      queue    = [C.new(shrunk, fitness, 0, 0)]
      _counter = counter.shrunk

      until queue.empty?
        # Expand parent by enumerating its children
        p  = queue.shift
        cs = weight(shrink.call(p.value), p.fitness+0.5, p.fitness+1)

        ok = 0.0
        no = []

        cs.each do |c, n|
          break if _counter.total >= options.max_shrink

          catch(:skip) do
            if prop.call(c, _counter)
              _counter.ok += 1
              ok          += 1
            else
              _counter.no += 1
              no.push([c, n])
            end
          end
        end

        no.map!{|c,n| C.new(c, n, 1-ok/cs.size) }

        unless no.empty?
          if no.first.fitness > fitness
            fitness = no.first.fitness
            shrunk  = no.first.value
          end

          queue.concat(no)
          queue.sort_by{|c| -c.fitness }
        end
      end

      No.new(random.seed, counter, shrunk)
    end

    # Search for a simpler example that causes the same exception
    def fail(random, counter, shrink, shrunk, options, prop, error)
      return Fail.new(random.seed, counter, shrunk, error) if shrink.nil?

      fitness  = 0
      queue    = _weight(shrink.call(shrunk), 0, 1)
      _counter = counter.shrunk

      until queue.empty? or _counter.total >= options.max_shrink
        c = queue.shift

        catch(:skip) do
          if prop.call(c.value, _counter)
            _counter.ok += 1
          else
            _counter.no += 1
          end
        rescue => e
          if c.fitness > fitness
            fitness = c.fitness
            shrunk  = c.value
          end

          _counter.fail += 1
          queue.concat(_weight(shrink.call(c.value), c.fitness+0.5, c.fitness+1.0))
          queue.sort_by!{|x| -x.fitness }
        end
      end

      return Fail.new(random.seed, counter, shrunk, error)
    end
  end

end