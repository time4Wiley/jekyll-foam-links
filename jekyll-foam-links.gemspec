# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name          = "jekyll-foam-links"
  spec.version       = "0.3.0"
  spec.authors       = ["Your Name"]
  spec.email         = ["your.email@example.com"]

  spec.summary       = "Jekyll plugin for Foam-style wikilink, hashtag, and mention conversion"
  spec.description   = "Converts [[wikilinks]], #hashtags, and @mentions to reference-style markdown links with configurable URLs"
  spec.homepage      = "https://github.com/time4Wiley/jekyll-foam-links"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 2.4.0"

  spec.files         = Dir["lib/**/*", "LICENSE", "README.md"]
  spec.require_paths = ["lib"]

  spec.add_dependency "jekyll", ">= 3.7", "< 5.0"
  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "rake", "~> 13.0"
end