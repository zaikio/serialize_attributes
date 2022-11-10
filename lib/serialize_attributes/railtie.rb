# frozen_string_literal: true

module SerializeAttributes
  class Railtie < Rails::Railtie # :nodoc:
    initializer "serialize_attributes.translations" do |_app|
      locale_files = Dir[File.expand_path("../../config/locales/*.yml", __dir__)]
      raise "Could not find locale files" unless locale_files.any?

      I18n.load_path += locale_files
    end
  end
end
