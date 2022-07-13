# frozen_string_literal: true

require "test_helper"

module SerializeAttributes
  module Types
    class EnumTest < ActiveSupport::TestCase
      test ":enum type is registered" do
        instance = ActiveModel::Type.lookup(:enum, of: %w[placed confirmed])

        assert_equal SerializeAttributes::Types::Enum, instance.class
        assert_equal %w[placed confirmed], instance.options
      end

      test "valid options are passed through uncast when type: nil" do
        instance = ActiveModel::Type.lookup(:enum, of: %w[placed confirmed])

        assert_equal "placed", instance.cast("placed")
        assert_equal "confirmed", instance.cast("confirmed")
      end

      test "casting/deserializing can happen using type: with a symbol" do
        instance = ActiveModel::Type.lookup(:enum, of: [true, false], type: :boolean)

        assert_equal false, instance.cast("off")
        assert_equal true, instance.cast("yes")
      end

      test "casting/deserializing can happen using type: with a type instance" do
        instance = ActiveModel::Type.lookup(:enum, of: [true, false], type: ActiveModel::Type::Boolean.new)

        assert_equal false, instance.cast("f")
        assert_equal true, instance.cast("yes")
      end
    end
  end
end
