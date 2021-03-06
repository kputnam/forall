# frozen_string_literal: true

require "simplecov"

SimpleCov.start do
  enable_coverage :branch
  add_filter "/spec"
end

require "forall"
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].sort.each(&method(:require))

RSpec.configure do |config|
  config.include(FunctionMatchers)

  # Use --tag "~todo" to skip these specs
  config.alias_example_to :todo, todo: true, skip: "TODO"

  config.expect_with(:rspec){|c| c.syntax = :expect }

  # Skip platform-specific examples unless our platform matches (exclude non-matches)
  #   ruby: "2.3."               # excludes Ruby 2.3.*
  #   ruby: /^2.[12]./           # excludes Ruby 2.1.*, 2.2.*
  #   ruby:->(v){|v| v < "2.3" } # excludes Ruby < 2.3
  config.filter_run_excluding(ruby: lambda do |expected|
    case expected
    when String
      !RUBY_VERSION.start_with?(expected)
    when Regexp
      expected !~ RUBY_VERSION
    when Proc
      !expected.call(RUBY_VERSION)
    end
  end)

  # This only applies if examples exist with :focus tag; then only :focus is
  # run. You can mark examples with :focus by using "fdescribe", "fcontext",
  # and "fit" instead of the normal RSpec syntax.
  config.filter_run_when_matching :focus
end
