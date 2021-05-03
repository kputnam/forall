Gem::Specification.new do |s|
  # Required attributes
  s.name     = "forall"
  s.version  = "0.0.0-rc"
  s.summary  = "Ruby generative property test library (ala QuickCheck)"
  s.authors  = ["Kyle Putnam"]

  s.files  += [__FILE__]
  s.files   = Dir[*%w(doc/**/*.md)]
  s.files  += Dir[*%w(lib/**/*.rb)]

  # Optional attributes
  s.homepage = "https://github.com/kputnam/forall"
  s.license  = "MIT"
  s.required_ruby_version     = ">= 2.0.0"
  s.required_rubygems_version = ">= 2.5.0"
end
