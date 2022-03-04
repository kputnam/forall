# frozen_string_literal: true

# This class is not meant to be instantiated by the user.
class Forall
  autoload :Bounds,       "forall/bounds"
  autoload :Config,       "forall/config"
  autoload :Control,      "forall/control"
  autoload :Coverage,     "forall/coverage"
  autoload :RSpecHelpers, "forall/rspec_helpers"
  autoload :Property,     "forall/property"
  autoload :Random,       "forall/random"
  autoload :Report,       "forall/report"
  autoload :Refinements,  "forall/refinements"
  autoload :Tree,         "forall/tree"
  autoload :VERSION,      "forall/version"
end
