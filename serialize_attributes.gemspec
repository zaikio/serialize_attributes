# frozen_string_literal: true

require_relative "lib/serialize_attributes/version"

Gem::Specification.new do |spec|
  spec.name        = "serialize_attributes"
  spec.version     = SerializeAttributes::VERSION
  spec.authors     = ["Zaikio"]
  spec.email       = ["support@zaikio.com"]
  spec.homepage    = "https://github.com/zaikio/serialize_attributes"
  spec.summary     = "Serialize ActiveModel attributes in JSON using type casting"
  spec.license     = "MIT"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/zaikio/serialize_attributes"
  spec.metadata["changelog_uri"] = "https://github.com/zaikio/serialize_attributes/blob/main/CHANGELOG.md"

  spec.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]

  spec.required_ruby_version = ">= 3.0"

  spec.add_dependency "activemodel", ">= 6"
end
