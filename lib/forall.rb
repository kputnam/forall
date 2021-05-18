# frozen_string_literal: true

# This class is not meant to be instantiated by the user.
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
        prop_ = prop
        prop  = lambda{|x, _| prop_.call(x) }
      end

      raise ArgumentError, "property must take one or two arguments" \
        unless prop.arity == 2

      counter = Counter.new

      input.each(random) do |example|
        return Ok.new(random.seed, counter)      if counter.ok   >= options.max_ok
        return Vacuous.new(random.seed, counter) if counter.skip >= options.max_skip

        catch(:skip) do
          return no(random, counter, input.shrink, example, options, prop) \
            unless prop.call(example, counter)

          counter.ok += 1
        end
      rescue RuntimeError => e
        counter.fail += 1
        return fail(random, counter, input.shrink, example, options, prop, e)
      end

      # Didn't meet ok_max because input was exhausted
      Ok.new(random.seed, counter)
    end

  private

    def weight(items, min, max)
      n = items.length.to_f
      r = max - min
      items.map.with_index{|x, k| C.new(x, max - r*k/n, 0) }
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
      queue    = weight(shrink.call(shrunk), 0, 1)
      counter_ = counter.shrunk

      until queue.empty? or counter_.total >= options.max_shrink
        c = queue.shift

        catch(:skip) do
          if prop.call(c.value, counter_)
            counter_.ok += 1
          else
            if c.fitness > fitness
              fitness = c.fitness
              shrunk  = c.value
            end

            counter_.no += 1
            queue.concat(weight(shrink.call(c.value), c.fitness + 0.5, c.fitness + 1.0))
            queue.sort_by!{|x| -x.fitness }
          end
        rescue RuntimeError => e
          counter_.fail += 1
          raise e
        end
      end

      No.new(random.seed, counter, shrunk)
    end

    # Search for a simpler example that causes the same exception
    def fail(random, counter, shrink, shrunk, options, prop, error)
      return Fail.new(random.seed, counter, shrunk, error) if shrink.nil?

      fitness  = 0
      queue    = weight(shrink.call(shrunk), 0, 1)
      counter_ = counter.shrunk

      until queue.empty? or counter_.total >= options.max_shrink
        c = queue.shift

        catch(:skip) do
          if prop.call(c.value, counter_)
            counter_.ok += 1
          else
            counter_.no += 1
          end
        rescue RuntimeError
          # TODO: Do we care if this exception is different from `error`?

          if c.fitness > fitness
            fitness = c.fitness
            shrunk  = c.value
          end

          counter_.fail += 1
          queue.concat(weight(shrink.call(c.value), c.fitness + 0.5, c.fitness + 1.0))
          queue.sort_by!{|x| -x.fitness }
        end
      end

      Fail.new(random.seed, counter, shrunk, error)
    end
  end
end
