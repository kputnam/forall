# frozen_string_literal: true

require "rspec/core/rake_task"

task default: :spec

# rake spec
RSpec::Core::RakeTask.new do |t|
  t.verbose    = false
  t.rspec_opts = %w[-w -rspec_helper]

  t.rspec_opts +=
    if ENV.include?("CI") or ENV.include?("TRAVIS")
      %w[--format progress]
    else
      %w[--format documentation]
    end
end
