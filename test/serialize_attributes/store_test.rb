# frozen_string_literal: true

require "test_helper"

module SerializeAttributes
  class StoreTest < ActiveSupport::TestCase
    def setup
      @store = MyModel.serialized_attributes_store(:data)
    end

    test "Store.attribute_names with array: true/false" do
      assert_equal %i[booly booly_default stringy timestamp listy listy_default listy_integer],
                   @store.attribute_names

      assert_equal %i[listy listy_default listy_integer],
                   @store.attribute_names(array: true)
    end
    test "Store.attribute_names with type and array: true/false" do
      assert_equal %i[booly booly_default stringy timestamp listy listy_default listy_integer],
                   @store.attribute_names

      assert_equal %i[listy listy_default listy_integer],
                   @store.attribute_names(array: true)
      assert_equal %i[listy listy_default],
                   @store.attribute_names(type: :string, array: true)
      assert_equal %i[stringy], @store.attribute_names(type: :string, array: false)
    end
  end
end
