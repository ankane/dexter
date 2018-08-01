
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "dexter/version"

Gem::Specification.new do |spec|
  spec.name          = "pgdexter"
  spec.version       = Dexter::VERSION
  spec.summary       = "The automatic indexer for Postgres"
  spec.homepage      = "https://github.com/ankane/dexter"
  spec.license       = "MIT"

  spec.author        = "Andrew Kane"
  spec.email         = "andrew@chartkick.com"

  spec.files         = Dir["*.{md,txt}", "{lib,exe}/**/*"]
  spec.require_path  = "lib"

  spec.bindir        = "exe"
  spec.executables   = ["dexter"]

  spec.required_ruby_version = ">= 2.2"

  spec.add_dependency "slop", ">= 4.2.0"
  spec.add_dependency "pg", ">= 0.18.2"
  spec.add_dependency "pg_query"

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "minitest"
end
