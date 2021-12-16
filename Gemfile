# frozen_string_literal: true

source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

# Specify your gem's dependencies in serialized_atributes.gemspec.
gemspec

group :development do
  gem "pg"
  gem "pry-byebug"
end

group :development, :test do
  gem "rails"
  gem "rake"
  gem "rubocop"
  gem "rubocop-rails"
end
