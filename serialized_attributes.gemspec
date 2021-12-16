# frozen_string_literal: true

require_relative "lib/serialized_attributes/version"

Gem::Specification.new do |spec|
  spec.name        = "serialized_attributes"
  spec.version     = SerializedAttributes::VERSION
  spec.authors     = ["Zaikio"]
  spec.email       = ["support@zaikio.com"]
  spec.homepage    = "https://github.com/zaikio/serialized_attributes"
  spec.summary     = "Serialize ActiveModel attributes in JSON using type casting"
  spec.license     = "MIT"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/zaikio/serialized_attributes"
  spec.metadata["changelog_uri"] = "https://github.com/zaikio/serialized_attributes/blob/main/CHANGELOG.md"

  spec.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]

  spec.required_ruby_version = ">= 3.0"

  spec.add_dependency "activemodel", ">= 6"
end
