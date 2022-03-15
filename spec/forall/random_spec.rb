# frozen_string_literal: true

describe Forall::Random do
  using Forall::Refinements

  # @example:
  #   tree("0", ["1", ["2"], ["3"]], ["4"], ["5"])
  #
  #            0
  #         /  |  \
  #       1    4    5
  #     /   \
  #    2     3
  #
  def tree(root, *kids)
    Forall::Tree.new(root, kids.map{|k| tree(*k) }.each)
  end

  # @example
  #   random{|prng, scale| ... }  #=> Forall::Random.new{|prng, scale| ... }
  #   random.integer(1..10)       #=> Forall::Random.integer(1..10)
  #   random                      #=> Forall::Random
  #
  def random(&block)
    if block_given?
      Forall::Random.new(&block)
    else
      Forall::Random
    end
  end

  describe ".new(&block)" do
    it "delays evaluation" do
      expect{ random{|_, _| raise "not delayed" } }.to_not raise_error
    end
  end

  describe "#each(prng:)" do
    before do
      @random = random.prng
    end

    it "returns an Enumerator" do
      expect(@random.each).to be_a(Enumerator)
    end

    it "uses a default prng" do
      expect(@random.each.first.value).to be_a(::Random)
    end

    it "passes along prng" do
      expect(@random.each(prng: :prng).first.value).to eq(:prng)
    end
  end

  describe "#each(&block)" do
    it "forces evaluation" do
      subject = random{|_, _| raise "forced" }
      expect{ subject.each{|_| } }.to raise_error("forced")
    end

    it "increments the scale parameter at each iteration" do
      actual   = random.scale.each.take(500).map(&:value)
      expected = (0..99).cycle.take(500)
      expect(actual).to eq(expected)
    end
  end

  describe "#sample(prng, scale)" do
    it "provides a default scale and prng" do
      subject = random{|prng, scale| [prng, scale] }
      prng  = an_instance_of(::Random)
      scale = an_instance_of(Integer)
      expect(subject.sample).to match([prng, scale])
    end

    it "passes prng and scale parameters to block" do
      subject = random{|prng, scale| [prng, scale] }
      expect(subject.sample(prng: :a, scale: :b)).to eq([:a, :b])
    end

    it "generates a single sample" do
      state   = 0
      subject = random{|_, _| state += 1 }
      expect(subject.sample).to eq(1)
      expect(subject.sample).to eq(2)
    end
  end

  describe "#map{|x| ... }" do
    before do
      @numbers = random.integer(100..500)
      @strings = @numbers.map(&:to_s)
    end

    it "returns another random generator" do
      expect(@strings).to be_a(Forall::Random)
    end

    it "transforms each element in tree" do
      numbers = @numbers.sample(prng: Random.new(100))
      strings = @strings.sample(prng: Random.new(100))
      expect(strings.to_a).to eq(numbers.to_a.map(&:to_s))
    end

    it "doesn't reevaluate tree nodes" do
      state  = 0
      effect = @numbers.map{|x| state += x }

      # The full tree isn't fully reified, because it's done lazily. But the
      # root value is determined, and the subtrees are functions of this root.
      result = effect.sample

      # See comment in the "#flat_map{|x| ... } doesn't reevaluate tree nodes"
      # specification
      r1 = result.to_a
      r2 = result.to_a
      expect(r1).to eq(r2)
    end
  end

  todo "#ap(*args)"

  describe "#flat_map{|x| ... }" do
    it "returns another random generator" do
      t1 = random.constant(tree(1))
      t2 = random.constant(tree(2))
      t3 = t1.flat_map{|t1_| t2.map{|t2_| t1_ + t2_ }}
      expect(t3).to be_a(Forall::Random)
    end

    it "delays evaluation" do
      t1 = random.boolean
      xx = lambda{|_| raise "not delayed" }
      expect{ t1.flat_map(&xx) }.to_not raise_error
    end

    it "shares the prng with inner level" do
      t1 = random.prng
      t2 = random.prng
      t3 = t1.flat_map{|t1_| t2.map{|t2_| [t1_, t2_] }}
      expect(t3.sample(prng: :prng).value).to eq([:prng, :prng])
    end

    it "shares the scale with inner level" do
      t1 = random.scale
      t2 = random.scale
      t3 = t1.flat_map{|t1_| t2.map{|t2_| [t1_, t2_] }}
      expect(t3.sample(scale: :scale).value).to eq([:scale, :scale])
    end

    it "requires block to return correct type" do
      t1 = random.boolean
      t2 = t1.flat_map{|x| 0 }
      expect{ t2.sample }.to raise_error(TypeError)
    end

    it "transforms subtrees recursively" do
      #           / tuv
      #       mno
      #     /     \ xyz
      #    /
      # abc - qrs
      #     \
      #       ijk
      #
      t0 = tree("abc", ["mno", ["tuv", "xyz"], ["qrs"], ["ijk"]])
      t1 = random{|_, _| t0 }

      # abc => a
      t2 = t1.flat_map{|str| random{|_, _| tree(str.chars.first) }}

      #       / t
      #     m
      #   /   \ x
      #  /
      # a - q
      #   \
      #     i
      #
      expect(t2.sample.to_a).to eq(%w[a m t x q i])
    end

    it "doesn't transform children returned by block" do
      # "abc"
      # ├─ "mno"
      # │  ├─ "tuv"
      # │  └─ "xyz"
      # ├─ "qrs"
      # └─ "ijk"
      t0 = tree("abc", ["mno", "tuv", "xyz"], ["qrs"], ["ijk"])
      t1 = random{|_, _| t0 }

      #          "aa"
      # "abc" => ├─ "b"
      #          └─ "c"
      t2 = t1.flat_map{|str| random{|_, _| tree(str.chars[0]*2, *str.chars[1..-1]) }}

      # "aa"
      # ├─ "b"
      # ├─ "c"
      # ├─ "mm"
      # │  ├─ "n"
      # │  ├─ "o"
      # │  ├─ "tt"
      # │  │  ├─ "u"
      # │  │  └─ "v"
      # │  └─ "xx"
      # │     ├─ "y"
      # │     └─ "z"
      # ├─ "qq"
      # │  ├─ "r"
      # │  └─ "s"
      # └─ "ii"
      #    ├─ "j"
      #    └─ "k"
      expect(t2.sample.to_a).to eq(%w[aa b c mm n o tt u v xx y z qq r s ii j k])
    end

    it "doesn't reevaluate tree nodes" do
      t1 = random.integer(0..10)
      t2 = random.float_(0..1)
      t3 = t1.flat_map{|_| t2 }

      # The full tree isn't fully reified, because it's done lazily. But the
      # root value is determined, and the subtrees are functions of this root.
      result = t3.sample

      # Tree children are produced on-demand during iteration. So it's possible
      # that the Enumerator yields different children each time its iterated,
      # which would be bad.
      #
      # Normally this wouldn't happen, because most Random constructors only
      # randomly select a root element and the rest of the tree is created
      # deterministically.
      #
      # However, using `Random#flat_map` would guarantee this to happen. Even
      # though the first tree is created once and can't change, the second tree
      # is constructed by mapping a random tree generator over every node in the
      # first tree. This is solved by caching the generated nodes with
      # `Enumerator#as_needed`, defined in `Forall::Refinements`
      r1 = result.to_a
      r2 = result.to_a
      expect(r1).to eq(r2)
    end
  end

  describe "#filter{|x| ... }" do
  end

  todo "#shrink{|x| ... }"

  todo "#rename(name)"

  todo ".pure(value)"

  todo ".scale"

  todo ".sequence(*randoms)"

  todo ".bernoulli(p)"

  todo ".binomial(n, p)"

  todo ".geometric(p)"

  todo ".negative_binomial(r, p)"

  todo ".hypergeometric(w, b, n)"

  todo ".poisson(λ)"

  todo ".uniform(range)"

  todo ".normal(μ, s)"

  todo ".exponential(λ)"

  todo ".gamma(α, β)"

  todo ".beta(α, β)"

  todo ".chi_square(n)"

  todo ".student_t(n)"

  todo ".unit(value)"

  todo ".boolean"

  todo ".integer(bounds)"

  todo ".integer_(bounds)"

  todo ".float(bounds)"

  todo ".float_(bounds)"

  todo ".complex(bounds)"

  todo ".range(bounds)"

  todo ".choose(items)"

  todo ".weighted(items, weights)"

  todo ".permutation(items)"

  todo ".subsequence(items, scale)"

  todo ".array(size, item)"

  todo ".set(size, item)"

  todo ".hash(length, pair)"

  todo ".binit"

  todo ".octit"

  todo ".digit"

  todo ".hexit"

  todo ".lowercase"

  todo ".uppercase"

  todo ".alpha"

  todo ".alphanum"

  todo ".ascii"

  todo ".latin"

  todo ".byte"

  todo ".utf8"

  todo ".utf8_all"
end
