# frozen_string_literal: true

require "serialized_attributes/version"
require "serialized_attributes/store"

# Serialize ActiveModel attributes in JSON using type casting
module SerializedAttributes
  extend ActiveSupport::Concern

  class_methods do
    # Configure a SerializedAttributes::Store, using the given column to store each
    # attribute.
    #
    #   class Person
    #     serialize_attributes :settings do
    #       attribute :user_name, :string, default: "Christian"
    #     end
    #   end
    #
    #   Person.new(user_name: "Nick")
    def serialize_attributes(column_name, &block)
      column_name = column_name.to_sym

      @serialized_attribute_stores ||= {}
      @serialized_attribute_stores[column_name] = Store.new(self, column_name, &block)
    end

    # Retrieve a SerializedAttributes registered against the given column
    #
    #   Person.serialized_attributes_store(:settings)
    def serialized_attributes_store(column_name)
      @serialized_attribute_stores.fetch(column_name.to_sym)
    end

    # Get a list of the attributes registered in a given store
    #
    #   Person.serialized_attribute_names(:settings)
    def serialized_attribute_names(column_name)
      serialized_attributes_store(column_name).attribute_names
    end
  end

  # Retrieve all of the SerializedAttributes attributes, including their default values
  #
  #   person = Person.new
  #   person.serialized_attributes_on(:settings)
  #   #=> { "user_name" => "Christian" }
  def serialized_attributes_on(column_name)
    store = self.class.serialized_attributes_store(column_name)

    store.attribute_names.index_with do |attribute_name|
      public_send(attribute_name)
    end
  end
end
