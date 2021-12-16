# frozen_string_literal: true

require "json_store/version"
require "json_store/store"

# JsonStore provides simple read/write methods delegating to a Hash object on your
# ActiveModel/ActiveRecord models.
module JsonStore
  extend ActiveSupport::Concern

  class_methods do
    # Configure a JsonStore, using the given attribute to store each attribute
    #
    #   class Person
    #     json_store :settings do
    #       attribute :user_name, :string, default: "Christian"
    #     end
    #   end
    #
    #   Person.new(user_name: "Nick")
    def json_store(column_name, &block)
      column_name = column_name.to_sym

      @json_stores ||= {}
      @json_stores[column_name] = Store.new(self, column_name, &block)
    end

    # Retrieve a JsonStore registered against the given column
    #
    #   Person.json_store_for(:settings)
    def json_store_for(column_name)
      @json_stores.fetch(column_name.to_sym)
    end

    # Get a list of the attributes registered in a given store
    #
    #   Person.json_store_attribute_names(:settings)
    def json_store_attribute_names(column_name)
      json_store_for(column_name).attribute_names
    end
  end

  # Retrieve all of the JsonStore attributes, including their default values
  #
  #   person = Person.new
  #   person.json_store_attributes(:settings)
  #   #=> { "user_name" => "Christian" }
  def json_store_attributes(column_name)
    store = self.class.json_store_for(column_name)

    store.attribute_names.index_with do |attribute_name|
      public_send(attribute_name)
    end
  end
end
