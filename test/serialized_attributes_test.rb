# frozen_string_literal: true

require "test_helper"

class SerializeAttributesTest < ActiveSupport::TestCase
  test "loading and reloading a complex model" do
    record = MyModel.create!(normal_column: "yes", data: { "booly" => false, "stringy" => "present" })

    assert_equal "yes", record.normal_column
    assert_equal false, record.booly
    assert_equal true, record.booly_default
    assert_equal "present", record.stringy
    assert_equal [], record.listy
    assert_equal ["first"], record.listy_default

    record.save!
    record.reload

    assert_equal false, record.booly
    assert_equal true, record.booly_default
    assert_equal "present", record.stringy
  end

  test "arrays can be created, modified and emptied" do
    record = MyModel.create!(listy: %w[foo bar], listy_default: %w[second])

    assert_equal %w[foo bar], record.listy
    assert_equal %w[second], record.listy_default

    record.listy << "baz"
    assert_equal %w[foo bar baz], record.listy

    record.save!
    record.reload

    assert_equal %w[foo bar baz], record.listy

    record.update!(listy: nil, listy_default: nil)

    assert_equal [], record.listy
    assert_equal ["first"], record.listy_default
  end

  test "casting to & from the database with timestamp" do
    timestamp = Time.zone.at(0)
    record = MyModel.create!(data: { timestamp: timestamp })

    assert_equal timestamp, record.timestamp

    record.timestamp = Time.zone.at(1)
    record.save!
    record.reload

    assert_equal Time.zone.at(1), record.timestamp
  end

  test "casting to and from the database with bigdecimal" do
    klass = Class.new(MyModel) do
      serialize_attributes :data do
        attribute :height, :decimal
      end
    end
    record = klass.new(height: BigDecimal("0.42"))

    assert_equal BigDecimal("0.42"), record.height

    record.save!
    record.reload

    assert_equal BigDecimal("0.42"), record.height
  end

  test "enums return validation failures with unknown values" do
    record = MyModel.new(enumy: "placed")
    assert record.valid?

    record.enumy = "unknown"
    assert_not record.valid?

    record.enumy = "confirmed"
    assert record.valid?
  end

  test "defaults supports a Proc referencing other parts of the record" do
    second = Class.new(MyModel) do
      self.table_name = :my_models

      serialize_attributes :data do
        attribute :defaulty_block, :string, default: -> { secret }
      end

      def secret
        "four"
      end
    end

    record = second.new
    assert_equal "four", record.defaulty_block
  end

  test "with a non-ActiveRecord model" do
    local = Class.new do
      include ActiveModel::Model
      include ActiveModel::Attributes
      include SerializeAttributes

      attribute :settings, ActiveModel::Type::Value.new

      serialize_attributes :settings do
        attribute :user_name, :string
        attribute :height,    :decimal
      end
    end

    record = local.new(settings: {})

    assert_nil record.user_name

    record.user_name = "Nick"
    record.height = BigDecimal("42.690")

    assert_equal "Nick", record.user_name
    assert_equal BigDecimal("42.690"), record.height
    assert_equal({ "user_name" => "Nick", "height" => BigDecimal("42.690") }, record.settings)
  end

  test "#serialized_attributes_on" do
    record = MyModel.create!(normal_column: "yes", data: { "booly" => false, "timestamp" => Time.zone.at(0) })

    assert_equal(
      {
        booly: false,
        booly_default: true,
        stringy: nil,
        timestamp: Time.zone.at(0),
        listy: [],
        listy_default: ["first"],
        listy_integer: [],
        enumy: nil
      },
      record.serialized_attributes_on(:data)
    )
  end

  test ".serialized_attribute_names" do
    assert_equal %i[booly booly_default stringy timestamp listy listy_default listy_integer enumy],
                 MyModel.serialized_attribute_names(:data)

    assert_equal %i[booly booly_default], MyModel.serialized_attribute_names(:data, :boolean)
    assert_equal %i[stringy listy listy_default], MyModel.serialized_attribute_names(:data, ActiveModel::Type::String)
  end

  test "json store is immutable once setup" do
    store = MyModel.serialized_attributes_store(:data)
    assert_raises(FrozenError) { store.instance_variable_set(:@attributes, {}) }
    assert_raises(FrozenError) { store.instance_variable_set(:@model_class, "value") }
    assert_raises(NoMethodError) { store.attribute(:foo, :string) }
  end

  test "calling #deserialize with a non-existing attribute" do
    ex = assert_raises { MyModel.serialized_attributes_store(:data).deserialize(:chunky_bacon, 0) }
    assert_equal "The attribute chunky_bacon is not defined in serialize_attribute method in the MyModel class.",
                 ex.message
  end

  test "predicated methods are included" do
    record = MyModel.create!(data: { "booly" => false, "timestamp" => nil, "listy" => [] })

    assert_equal false, record.booly?
    assert_equal false, record.timestamp?
  end

  test "should not be possible to use enums and arrays together" do
    ex = assert_raises(ArgumentError) do
      Class.new do
        include SerializeAttributes

        serialize_attributes :settings do
          attribute :foo, :enum, of: [1, 2, 3], array: true
        end
      end
    end

    assert_equal "Enum-arrays not currently supported", ex.message
  end
end
