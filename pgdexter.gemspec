# coding: utf-8

lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "dexter/version"

Gem::Specification.new do |spec|
  spec.name          = "pgdexter"
  spec.version       = Dexter::VERSION
  spec.authors       = ["Andrew Kane"]
  spec.email         = ["andrew@chartkick.com"]

  spec.summary       = "The automatic indexer for Postgres"
  spec.homepage      = "https://github.com/ankane/dexter"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "slop", ">= 4.2.0"
  spec.add_dependency "pg"
  spec.add_dependency "pg_query"

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "minitest"
end
