# frozen_string_literal: true

class Forall
  using Forall::Refinements

  # @private
  class Tree
    # @return [A]
    attr_reader :value

    # @return [Enumerator<Tree<A>>]
    attr_reader :children

    # @param [A]                    value
    # @param [Enumerator<Tree<A>>]  children
    def initialize(value, children)
      raise TypeError, "children must be an Enumerator" \
        unless Enumerator === children

      @value    = value
      @children = children.by_need
    end

    # Renders the tree in ASCII form.
    #
    # @return [String]
    def print(output = "".dup)
      _print("", "", output)
    end

    # Returns the maximum depth of the tree. The root node is at depth 0.
    #
    # @return [Integer]
    def depth
      1 + (@children.map(&:depth).max || -1)
    end

    # Remove any nodes past the given depth. If the root (depth 0) is removed,
    # then `nil` is returned.
    #
    # @param  [Integer] depth
    # @return [Tree<A> | nil]
    def prune(depth)
      if depth.negative?
        nil
      elsif depth.zero?
        Tree.leaf(@value)
      else
        Tree.new(@value, @children.map{|c| c.prune(depth - 1) })
      end
    end

    # Expand this tree using an unfolding function. The function maps the value
    # in a node to a set of children, which are then prepended to that node's
    # existing children.
    #
    # @yieldparam  [A]
    # @yieldreturn [Enumerable<A>]
    # @return      [Tree<A>]
    def expand(&block)
      xs = block[@value].map{|x| Tree.unfold(x, &block) }
      cs = @children.map{|c| c.expand(&block) }
      Tree.new(@value, cs + xs)
    end

    # Maps each value in this tree using the given function. The shape of the
    # tree is preserved.
    #
    # @yieldparam  [A] value
    # @yieldreturn [B]
    # @return      [Tree<B>]
    def map(&block)
      Tree.new(block[@value], @children.map{|c| c.map(&block) })
    end

    # bbb
    #
    # @yieldparam  [A]
    # @yieldreturn [Tree<B>]
    # @return      [Tree<B>]
    def flat_map(&block)
      block[@value].prepend_children(@children.map{|c| c.flat_map(&block) })
    end

    # @TODO
    #
    # @param  [Tree<B>]
    # @return [Tree<[A, B]>]
    def zip(other, &block)
      l_ = self
      r_ = other

      Tree.new((block || Array)[l_.value, r_.value],
        l_.children.map{|lc| lc.zip(r_, &block) } +
        r_.children.map{|rc| l_.zip(rc, &block) })
    end

    # Combine the values in the tree using a binary operator. The root node's
    # value is used as the initial value unless one is provided.
    #
    # @param       [A] zero
    # @yieldparam  [A] accumulator
    # @yieldparam  [B] value
    # @yieldreturn [A]
    # @return      [A]
    def reduce(zero = nil, &block)
      if zero.nil?
        @children.inject(@value){|sum, c| c.reduce(sum, &block) }
      else
        @children.inject(block[zero, @value]){|sum, c| c.reduce(sum, &block) }
      end
    end

    # Removes all nodes that satisfy the predicate. If root node is removed,
    # `nil` is returned. This method does not preserve the shape of the tree:
    # When other nodes are removed, they are replaced by their children, which
    # are recursively filtered. 
    #
    # @yieldparam  [A]
    # @yieldreturn [Boolean]
    # @return      [Tree<A> | nil]
    def filter(&block)
      # Can't replace the root of its tree with its children, because trees
      # have only one root node.
      Tree.new(@value, @children.flat_map{|c| _filter(c, &block) }) \
        if block[@value]
    end

    # Removes all nodes that don't satisfy the predicate. If root node is
    # removed, `nil` is returned. This method does not preserve the shape of the
    # tree: When other nodes are removed, they are replaced by their children,
    # which are recursively filtered. 
    #
    # @yieldparam  [A]
    # @yieldreturn [Boolean]
    # @return      [Tree<A> | nil]
    def select(&block)
      filter{|x| !block[x] }
    end

    # Counts the number of nodes (leaves and internal nodes) that have a value
    # matching a given predicate. If predicate is not provided, all nodes are
    # counted.
    #
    # @yieldparam  [A]
    # @yieldreturn [Boolean]
    # @return      [Integer]
    def count(&block)
      if block_given?
        reduce(0){|count, x| count + (block[x] ? 0 : 1) }
      else
        reduce(0){|count, _| count + 1 }
      end
    end

    # Creates a new tree that has the given argument as its first child.
    #
    # @param  [Tree<A>] child
    # @return [Tree<A>]
    def prepend_children(children)
      Tree.new(@value, children + @children)
    end

  protected

    # @param       [Tree<A>] tree
    # @yieldparam  [A]
    # @yieldreturn [Boolean]
    # @return      [Enumerable<Tree<A>>]
    def _filter(tree, &block)
      if block[tree.value]
        [Tree.new(tree.value, tree.children.flat_map{|c| _filter(c, &block) })]
      else
        tree.children.flat_map{|c| _filter(c, &block) }
      end
    end

    def _print(prefix, cprefix, output)
      output << "#{prefix}#{@value.inspect}\n"

      # Since this might be a lazy Enumerator, avoid iterating twice (once to
      # get the length, once to print each child)
      children = @children.to_a
      last     = children.length - 1

      children.each_with_index do |child, k|
        if k < last
          child._print("#{cprefix}├─ ", "#{cprefix}│  ", output)
        else
          child._print("#{cprefix}└─ ", "#{cprefix}   ", output)
        end
      end

      output
    end
  end

  class << Tree
    EMPTY = Enumerator.new{|e| }

    # Construct a tree with no children
    #
    # @param  [A] value
    # @return [Tree<A>]
    def leaf(value)
      Tree.new(value, EMPTY)
    end

    # @TODO: Change _drop_one so the tree is shorter and wider, rather than
    # removing only one item at each lewel. Also, this terminates with empty
    # lists at the leaves, but it may be better to structure the tree more like
    # Random#numeric_tree. It's not yet clear how an "origin" on size would be
    # determined though.
    #
    # @TODO: The current implementation results in nodes with duplicate values.
    # For example:
    #
    #   >> T.interleave([T.leaf(1), T.leaf(2), T.leaf(3)]).print($stdout)
    #   [1, 2, 3]
    #   ├─ [2, 3]
    #   │  ├─ [3]
    #   │  │  └─ []
    #   │  └─ [2]
    #   │     └─ []
    #   ├─ [1, 3]
    #   │  ├─ [3]
    #   │  │  └─ []
    #   │  └─ [1]
    #   │     └─ []
    #   └─ [1, 2]
    #      ├─ [2]
    #      │  └─ []
    #      └─ [1]
    #         └─ []
    #
    # @param trees [Enumerable<Tree<A>>]
    # @return      [Tree<Array<A>>]
    def interleave(trees)
      Tree.new(trees.map(&:value), _drop_one(trees) + _shrink_one(trees))
    end

    # Create a tree from an initial value and an unfolding function
    #
    # @yieldparam  [A] value
    # @yieldreturn [Enumerable<A>]
    # @rreturn     [Tree<A>]
    def unfold(value, &block)
      Tree.new(value, Enumerator.new do |e|
        block[value].each do |c|
          e << unfold(c, &block)
        end
      end)
    end

  private

    # TODO: This method has the effect of performig a linear search starting at
    # the initial size and working toward the minimum size. Probably doing a
    # binary search for the minimal list size would perform much better.
    #
    # @param trees [Enumerable<Tree<A>>]
    # @return      [Enumerator<Tree<Array<A>>>]
    def _drop_one(trees)
      Enumerator.new do |e|
        trees.each_with_index do |_t, k|
          # drop the _t == tree[k]
          xs = trees[0, k]
          zs = trees[k+1..-1]
          e << interleave(xs + zs)
        end
      end
    end

    # @param trees [Enumerable<Tree<A>>]
    # @return      [Enumerator<Tree<Array<A>>>]
    def _shrink_one(trees)
      Enumerator.new do |e|
        trees.each_with_index do |t, k|
          xs = trees[0, k]
          zs = trees[k+1..-1]

          # shrink t == trees[k] by replacing it with its children
          t.children.each do |y|
            e << interleave(xs + [y] + zs)
          end
        end
      end
    end
  end
end
