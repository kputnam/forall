# Forall [![Build Status](https://github.com/kputnam/forall/actions/workflows/build.yml/badge.svg)](https://github.com/kputnam/forall/actions/workflows/build.yml).


Property-based testing for Ruby (adapted from Jacob Stanley's [Hedgehog](https://github.com/hedgehogqa/haskell-hedgehog) library for Haskell, and an older project I made named [Propr](https://github.com/kputnam/propr)).

## Introduction

The usual approach to testing software is to describe a set of test inputs and
their expected corresponding outputs. The program is run with these inputs, and
the actual outputs are compared to what's expected to ensure the program
behaves correctly. This methodology is simple to implement and automate, but
has some problems like:

* Writing test cases is tedious and repetitive.
* Only edge cases that occur to the author are tested.
* It can be difficult to see which parts of the test input are mere prerequisites rather than essential.
* Getting 100% code coverage with trivial tests doesn't offer much assurance.

Property-based testing is an alternative and complementary approach in which
the binary relations between attributes of inputs and desired output are
expressed as functions, rather than enumerating particular inputs and outputs.
The properties specify things like, "assuming the program is correct, when its
run with any valid inputs, the inputs and the program output are related by
`f(input, output)`".

## Properties

The following example demonstrates testing a property with a specific input,
then generalizing the test for any input.

```ruby
describe Array do
  include Forall::RSpecHelpers

  describe "#+(other)" do
    # Traditional unit test
    it "sums lengths" do
      xs = [100, 200, 300]
      ys = [400, 500]
      expect((xs + ys).length).to eq(xs.length + ys.length)
    end

    # Property-based test
    it "sums lengths" do
      ints = random.array(random.integer(0..999))

      forall(random.sequence(ints, ints)) do |xs, ys|
        (xs + ys).length == xs.length + ys.length
      end
    end
    # property("sums lengths"){|xs, ys| (xs + ys).length == xs.length + ys.length }
    #   .check([100, 200, 300], [500, 200])
    #   .check{ sequence [Array.random { Integer.random }, Array.random { Integer.random }] }
  end
end
```

The following example is similar, but contains an error in the specification

```ruby
describe Array do
  include Propr::RSpec

  describe "#|(other)" do
    # Traditional unit test
    it "sums lengths" do
      xs = [100, 200, 300]
      ys = [400, 500]

      # This passes
      expect((xs | ys).length).to eq(xs.length + ys.length)
    end

    # Property-based test
    it "sums lengths" do
      ints = random.array(random.integer(0..999))

      forall(random.sequence(ints, ints)) do |xs, ys|
        (xs | ys).length == xs.length + ys.length
      end
    end

    # property("sums lengths"){|xs, ys| (xs | ys).length == xs.length + ys.length }
    #   .check([100, 200, 300], [400, 500])
    #   .check{ sequence [Array.random{Integer.random(min:0, max:50)}]*2 }
  end
end
```

When this specification is executed, the following error is reported.

    $ rake spec
    ..F

    Failures:

      1) Array#| sums lengths
         Failure/Error: raise Falsifiable.new(counterex, m.shrink(counterex), passed, skipped)
         Propr::Falsifiable:
           input: [], [0, 0]
           after: 49 passed, 0 skipped
         # ./lib/propr/rspec.rb:29:in `block in check'

    Finished in 0.22829 seconds
    3 examples, 1 failure

You may have figured out the error is that `|` removes duplicate elements
from the result. We might not have caught the mistake by writing individual
test cases. The output indicates Forall generated 49 sets of input before
finding one that failed.

<!--

Now that a failing test case has been identified, you might write another
`check` with those specific inputs to prevent regressions.

You could also print the initial random seed like this and when a test fails,
explicitly set the random seed to regenerate the same inputs for the entire
test suite:

    $ cat spec/spec_helper.rb
    RSpec.configure do |config|
      srand.tap{|seed| puts "Random seed is #{seed}"; srand seed }
    end

    $ rake spec
    Random seed is 146211424375622429406889408197139382303
    ..F

    Failures:

      1) Array#| sums lengths
         Failure/Error: raise Falsifiable.new(counterex, m.shrink(counterex), passed, skipped)
         Propr::Falsifiable:
           input:    [25, 24], [24, 27]
           shrunken: [], [0, 0]
           after: 49 passed, 0 skipped

    Finished in 0.22829 seconds
    3 examples, 1 failure

Now change spec\_helper.rb to explicitly set the random seed:

    $ cat spec/spec_helper.rb
    RSpec.configure do |config|
      srand 146211424375622429406889408197139382303
      srand.tap{|seed| puts "Random seed is #{seed}"; srand seed }
    end

    $ rake spec
    Random seed is 146211424375622429406889408197139382303

The remaining output should be identical every time you run the suite, so
long as specs are in the same order each time.

### Just Plain Functions

Properties are basically just functions, they should return `true` or `false`.

    p = Propr::Property.new("name", lambda{|a,b| a + b == b + a })

You can invoke a property using `#check`. Like lambdas and procs, you can also
invoke them using `#call` or `#[]`.

    p.check(3, 4)     #=> true
    p.check("x", "y") #=> false

But you can also invoke them by yielding a function that generates random inputs.

    m = Propr::Random
    p.check { m.eval(m.sequence [Integer.random, Float.random]) }  #=> true
    p.check { m.eval(m.sequence [String.random , String.random]) } #=> false

When invoked with a block, `check` will run `p` with 100 random inputs by
default, but you can also pass an argument to `check` indicating how many
examples `p` should be tested against.

## Using Propr + Test Frameworks

Mixing in a module magically defines the `property` singleton method, so
you can use it to generate test cases.

```ruby
describe "foo" do
  include Propr::RSpec

  # This defines three test cases, one per each `check`
  property("length"){|a| a.length >= 0 }.
    check("abc").
    check("xyz").
    check{ String.random }
end
```

Note your property should still return `true` or `false`. You should *not* use
`#should` or `#assert`, because the test generator will generate the assertion
for you. This also reduces visual clutter.

Alternatively, to use Propr with all specification, you can add this to your
`spec_helper.rb`

```ruby
RSpec.configure do |config|
  include Propr::RSpec
end
```

### Property DSL

The code block inside `property { ... }` has an extended scope that defines
a few helpful methods:

* __guard__: Skip this iteration unless all the given conditions are met. This
  can be used, for instance, to define a property only on even integers.
  `property{|x| guard(x.even?); x & 1 == 0 }`

* __error?__: True if the code block throws an exception of the given type.
  `property{|x| error? { x / 0 }}`

* __m__: Short alias for `Propr::Random`, used to generate random data as described
  below.
  `property{|x| m.eval(m.sequence([m.unit 0] * x)).length == x }`

### Check DSL

The code block inside `check { ... }` should return a generator value. The code
block's scope is extended with a few combinators to compose generators.

* __unit__: Create a generator that returns the given value. For instance, to yield
  `3` as an argument to the property,
  `check { unit(3) }`

* __bind__: Chain the value yielded by one generator into another. For instance, to
  yield two integers as arguments to a property,
  `check { bind(Integer.random){|a| bind(Integer.random){|b| unit([a,b]) }}}`

* __guard__: Short-circuit the chain if the given condition is false. The entire chain
  will be re-run until the guard passes. For instance, to generate two distinct numbers,
  `check { bind(Integer.random){|a| bind(Integer.random){|b| guard(a != b){ unit([a,b]) }}}}`

* __join__: Remove one level of generator nesting. If you have a generator `x` that
  *yields* a number generator, then `join x` is a number generator. For instance, to yield
  either a number or a string,
  `check { join([Integer.random, String.random].random) }`

* __sequence__: Convert a list of generator values to a list generator. For instance, to
  yield three integers to a property,
  `check { sequence [Integer.random]*3 }`

## Generating Random Values

Propr defines a `random` method that returns a generator for most standard
Ruby types. You can run the generator using the `Propr::Random.eval` method.

    >> m = Propr::Random
    => ...

    >> m.eval(Boolean.random)
    => false

### Boolean

    >> m.eval Boolean.random
    => true

### Date

    >> m.eval(Date.random(min: Date.today - 10, max: Date.today + 10)).to_s
    => "2012-03-01"

Options

* `min:` minimum value, defaults to 0001-01-01
* `max:` maximum value, defaults to 9999-12-31
* `center:` defaults to the midpoint between min and max

### Time

    >> m.eval Time.random(min: Time.now, max: Time.now + 3600)
    => 2012-02-20 13:47:57 -0600

Options

* `min:` minimum value, defaults to 1000-01-01 00:00:00 UTC
* `max:` maximum value, defaults to 9999-12-31 12:59:59 UTC
* `center:` defaults to the midpoint between min and max

### String

    >> m.eval String.random(min: 5, max: 10, charset: :lower)
    => "rqyhw"

Options

* `min:` minimum size, defaults to 0
* `max:` maximum size, defaults to 10
* `center:` defaults to the midpoint between min and max
* `charset:` regular expression character class, defaults to `/[[:print]]/`

### Numbers

#### Integer.random

    >> m.eval Integer.random(min: -500, max: 500)
    => -382

Options

* `min:` minimum value, defaults to Integer::MIN
* `max:` maximum value, defaults to Integer::MAX
* `center:` defaults to the midpoint between min and max.

#### Float.random

    >> m.eval Float.random(min: -500, max: 500)
    => 48.252030464134364

Options

* `min:` minimum value, defaults to -Float::MAX
* `max:` maximum value, defaults to Float::MAX
* `center:` defaults to the midpoint between min and max.

#### Rational.random

    >> m.eval m.bind(m.sequence [Integer.random]*2){|a,b| unit Rational(a,b) }
    => (300421843/443649464)

Not implemented, as there isn't a nice way to ensure a `min` works. Instead,
generate two numeric values and combine them:

#### BigDecimal.random

    >> m.eval(BigDecimal.random(min: 10, max: 20)).to_s("F")
    => "14.934854011762374703280016489856414847259220844969789892"

Options

* `min:` minimum value, defaults to -Float::MAX
* `max:` maximum value, defaults to Float::MAX
* `center:` defaults to the midpoint between min and max

#### Bignum.random

    >> m.eval Integer.random(min: Integer::MAX, max: Integer::MAX * 2)
    => 2015151263

There's no constructor specifically for Bignum. You can use `Integer.random`
and specify `min: Integer::MAX + 1` and some even larger `max` value. Ruby
will automatically handle Integer overflow by coercing to Bignum.

#### Complex.random

    >> m.eval(m.bind(m.sequence [Float.random(min:-10, max:10)]*2){|a,b| m.unit Complex(a,b) })
    => (9.806161068637833+7.523520738439842i)

Not implemented, as there's no simple way to implement min and max, nor the types
of the components. Instead, generate two numeric values and combine them:

### Collections

The class method `random` returns a generator to construct a collection of
elements, while the `#random` instance method returns a generator which returns
an element from the collection.

#### Array.random

Expects a block parameter that yields a generator for elements.

    >> m.eval Array.random(min:4, max:4) { String.random(min:4, max:4) }
    => ["2n #", "UZ1d", "0vF,", "cV_{"]

Options

* `min:` minimum size, defaults to 0
* `max:` maximum size, defaults to 10
* `center:` defaults to the midpoint between min and max

#### Hash.random

Expects a block parameter that yields generator of [key, value] pairs.

    >> m.eval Hash.random(min:2, max:4) { m.sequence [Integer.random, m.unit(nil)] }
    => {564854752=>nil, -1065292239=>nil, 830081146=>nil}

Options

* `min:` minimum size, defaults to 0
* `max:` maximum size, defaults to 10
* `center:` defaults to the midpoint between min and max

#### Hash.random_vals

Expects a hash whose keys are ordinary values, and whose values are
generators.

    >> m.eval Hash.random_vals(a: String.random, b: Integer.random)
    => {:a=>"Fi?p`g", :b=>4551738453396095365}

Doesn't accept any options.

#### Set.random

Expects a block parameter that yields a generator for elements.

    >> m.eval Set.random(min:4, max:4) { String.random(min:4, max:4) }
    => #<Set: {"2n #", "UZ1d", "0vF,", "cV_{"}>

Options

* `min:` minimum size, defaults to 0
* `max:` maximum size, defaults to 10
* `center:` defaults to the midpoint between min and max

#### Range.random

Expects __either__ a block parameter __or__ one or both of min and max.

    >> m.eval Range.random(min: 0, max: 100)
    => 81..58

    >> m.eval Range.random { Integer.random(min: 0, max: 100) }
    => 9..80

Options

* `min:` minimum element
* `max:` maximum element
* `inclusive?:` defaults to true, meaning Range includes max element

#### Elements from a collection

The `#random` instance method is defined on the above types. It takes no parameters.

    >> m.eval([1,2,3,4,5].random)
    => 4

    >> m.eval({a: 1, b: 2, c: 3, d: 4}.random)
    => [:b, 2]

    >> m.eval((0..100).random)
    => 12

    >> m.eval(Set.new([1,2,3,4]).random)
    => 4

## Search Space Attenuation

The `m.eval` method has a second parameter that serves to exponentially reduce
the domain for generators, specified with `min:` and `max:` parameters. The scale
value may range from `0` to `1`, where `1` causes no change.

When scale is `0`, the domain is reduced to a single value, which is specified by
the `center:` parameter. Usually this defaults to the midpoint between `min:` and
`max:`. Any value between `min:` and `max:` can be given for `center:`, in addition
to the three symbolic values, `:min`, `:mid`, and `:max`.

Scale values beteween `0` and `1` adjust the domain exponentially, so a domain with
10,000 elements when `scale = 1` will have 1,000 elements when `scale = 0.5` and
only 100 when `scale = 0.25`.

With `scale = 0`, the domain contains at most `10000^0 = 1` elements:

    >> m.eval Integer.random(min: 0, max: 10000, center: :min), 0
    == m.eval Integer.random(min: 0, max: 0)

    >> m.eval Integer.random(min: 0, max: 10000, center: :mid), 0
    == m.eval Integer.random(min: 5000, max: 5000)

    >> m.eval Integer.random(min: 0, max: 10000, center: :max), 0
    == m.eval Integer.random(min: 10000, max: 10000)

With `scale = 0.25`, the domain contains at most `10000^0.25 = 10` elements:

    >> m.eval Integer.random(min: 0, max: 10000, center: :min), 0.25
    == m.eval Integer.random(min: 0, max: 9)

    >> m.eval Integer.random(min: 0, max: 10000, center: :mid), 0.25
    == m.eval Integer.random(min: 4996, max: 5004)

    >> m.eval Integer.random(min: 0, max: 10000, center: :max), 0.25
    == m.eval Integer.random(min: 9991, max: 10000)

With `scale = 0.50`, the domain contains at most `10000^0.5 = 100` elements:

    >> m.eval Integer.random(min: 0, max: 10000, center: :min), 0.5
    == m.eval Integer.random(min: 0, max: 99)

    >> m.eval Integer.random(min: 0, max: 10000, center: :mid), 0.5
    == m.eval Integer.random(min: 4951, max: 5048)

    >> m.eval Integer.random(min: 0, max: 10000, center: :max), 0.5
    == m.eval Integer.random(min: 9901, max: 10000)

With `scale = 0.75`, the domain contains at most `10000^0.75 = 1000` elements:

    >> m.eval Integer.random(min: 0, max: 10000, center: :min), 0.75
    == m.eval Integer.random(min: 0, max: 998)

    >> m.eval Integer.random(min: 0, max: 10000, center: :mid), 0.75
    == m.eval Integer.random(min: 4507, max: 5499)

    >> m.eval Integer.random(min: 0, max: 10000, center: :max), 0.75
    == m.eval Integer.random(min: 9002, max: 10000)

### Deepening of the Search Space

By default, the test framework adapters increase the scale linearly (causing
an exponential increase of the domain size) each time the property is tested.

That is, when running 100 iterations, scale values will be 0.00, 0.01, 0.02,
0.03, 0.04, etc. This is intended to test the simplest counterexamples first,
and increase the complexity of generated inputs exponentially.

### Simplification of Counterexamples

Once a random input has been classified as a counterexample, Propr will
search for a simpler counterexample. This is done by iteratively calling
`#shrink` on each successively smaller counterexample.

    $ cat shrink.example
    require "rspec"
    require "propr"

    RSpec.configure do |config|
      include Propr::RSpec

      srand 146211424375622429406889408197139382303
      srand.tap{|seed| puts "Random seed is #{seed}"; srand seed }
    end

    describe Float do
      property("assoc"){|x,y,z| (x + y) + z == x + (y + z) }
        .check(-382863.98514407175, 224121.21177705095, 276118.77134001954)
    end

    $ rspec shrink.example
    Random seed is 146211424375622429406889408197139382303
    F

    Failures:

      1) Float assoc
         Propr::Falsifiable:
           input:    -382863.98514407175, 224121.21177705095, 276118.77134001954
           shrunken: -0.007740960460133677, 0.011895728563551701, 3.9765678826328424e-05
           after: 0 passed, 0 skipped
         # ./lib/propr/rspec.rb:36:in `block in check'

    Finished in 10.52 seconds
    1 example, 1 failure

Notice the output shows a "simpler" counterexample than the inputs we explicitly
tested. This becomes useful when testing with more complex data like trees, where
it can be difficult to understand which aspect of the counterexample is relevant.

## Installation

There are a few things I'd like to fix before publishing this as a gem. Until
then, you can install directly from the git repo using Bundler, with this in
your Gemfile:

    gem "propr", git: "git@github.com:kputnam/propr.git", branch: "rewrite"

You'll probably want to specify the current tag, also (eg, `..., tag: "v0.2.0"`)


## More Reading

* [Presentation at KC Ruby Meetup Group](https://github.com/kputnam/presentations/raw/master/Property-Based-Testing.pdf)

## Related Projects

* [Rantly](https://github.com/hayeah/rantly)
* [PropER](https://github.com/manopapad/proper)
* [QuviQ](http://www.quviq.com/documents/QuviqFlyer.pdf)
* [QuickCheck](http://www.haskell.org/haskellwiki/Introduction_to_QuickCheck)

-->
