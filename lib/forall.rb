# frozen_string_literal: true

# This class is not meant to be instantiated by the user.
class Forall
  autoload :Bounds,       "forall/bounds"
  autoload :Config,       "forall/config"
  autoload :Coverage,     "forall/coverage"
  autoload :RspecDsl,     "forall/rspec_dsl"
  autoload :Property,     "forall/property"
  autoload :Random,       "forall/random"
  autoload :Report,       "forall/report"
  autoload :Refinements,  "forall/refinements"
  autoload :Tree,         "forall/tree"
  autoload :VERSION,      "forall/version"
end
