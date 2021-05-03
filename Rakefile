require "rspec/core/rake_task"

task :default => :spec

# rake spec
RSpec::Core::RakeTask.new do |t|
  t.verbose    = false
  t.rspec_opts = %w(-w -rspec_helper)

  if ENV.include?("CI") or ENV.include?("TRAVIS")
    t.rspec_opts += %w(--format progress)
  else
    t.rspec_opts += %w(--format documentation)
  end
end
