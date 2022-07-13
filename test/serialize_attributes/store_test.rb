# frozen_string_literal: true

require "test_helper"

module SerializeAttributes
  class StoreTest < ActiveSupport::TestCase
    def setup
      @store = MyModel.serialized_attributes_store(:data)
    end

    test ".attribute_names with array: true/false" do
      assert_equal %i[booly booly_default stringy timestamp listy listy_default listy_integer enumy],
                   @store.attribute_names

      assert_equal %i[listy listy_default listy_integer],
                   @store.attribute_names(array: true)
    end

    test ".attribute_names with type and array: true/false" do
      assert_equal %i[listy listy_default],
                   @store.attribute_names(type: :string, array: true)
      assert_equal %i[stringy], @store.attribute_names(type: :string, array: false)
    end

    test ".enum_options returns enum types and their values" do
      assert_equal [nil, "placed", "confirmed"], @store.enum_options(:enumy)

      ex = assert_raises(ArgumentError) do
        @store.enum_options(:booly)
      end

      assert_equal "`booly` attribute is not an enum type", ex.message
    end
  end
end
