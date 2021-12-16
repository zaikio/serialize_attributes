# frozen_string_literal: true

require_relative "lib/json_store/version"

Gem::Specification.new do |spec|
  spec.name        = "json-store"
  spec.version     = JsonStore::VERSION
  spec.authors     = ["Zaikio"]
  spec.email       = ["support@zaikio.com"]
  spec.homepage    = "https://github.com/zaikio/json-store"
  spec.summary     = "Simple read/write methods delegating to a Hash object on your ActiveModel/ActiveRecord models"
  spec.license     = "MIT"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/zaikio/json-store"
  spec.metadata["changelog_uri"] = "https://github.com/zaikio/json-store/blob/main/CHANGELOG.md"

  spec.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]

  spec.required_ruby_version = ">= 3.0"

  spec.add_dependency "activemodel", ">= 6"
end
