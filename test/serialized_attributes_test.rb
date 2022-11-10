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

    record.booly = "true"

    record.save!
    record.reload

    assert_equal true, record.booly
    assert_equal true, record.booly_default
    assert_equal "present", record.stringy
  end

  test "arrays can be created, modified and emptied" do
    record = MyModel.create!(listy: %w[foo bar])

    assert_equal %w[foo bar], record.listy

    record.listy << "baz"
    assert_equal %w[foo bar baz], record.listy
    assert record.changed?

    record.save!
    record.reload

    assert_equal %w[foo bar baz], record.listy

    record.update!(listy: nil)

    assert_equal [], record.listy
  end

  test "casting to & from the database with timestamp" do
    timestamp = Time.zone.at(0)
    record = MyModel.create!(data: { timestamp: timestamp })

    assert_equal timestamp, record.timestamp

    record.timestamp = Time.zone.at(1)
    assert_equal record.timestamp, Time.zone.at(1)

    record.save!
    record.reload

    assert_equal Time.zone.at(1), record.timestamp
  end

  test "casting to and from the database with bigdecimal" do
    record = MyModel.new(decy: BigDecimal("0.42"))

    assert_equal BigDecimal("0.42"), record.decy

    record.decy = BigDecimal("9.99")
    assert_equal BigDecimal("9.99"), record.decy

    record.save!
    record.reload

    assert_equal BigDecimal("9.99"), record.decy
  end

  test "enums return validation failures with unknown values" do
    record = MyModel.new(enumy: "placed")
    assert record.valid?

    record.enumy = "unknown"
    assert_not record.valid?
    assert_includes record.errors.full_messages,
                    "Enumy unknown is not one of (null), placed, confirmed"

    record.enumy = "confirmed"
    assert record.valid?
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

    assert_equal({ "user_name" => "Nick", "height" => BigDecimal("42.690") }, record.settings.to_hash)
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
        listy_integer: [],
        enumy: nil,
        decy: nil
      },
      record.serialized_attributes_on(:data)
    )
  end

  test ".serialized_attribute_names" do
    assert_equal %i[booly booly_default stringy timestamp listy listy_integer enumy decy],
                 MyModel.serialized_attribute_names(:data)

    assert_equal %i[booly booly_default], MyModel.serialized_attribute_names(:data, :boolean)
    assert_equal %i[stringy listy], MyModel.serialized_attribute_names(:data, ActiveModel::Type::String)
  end

  test "json store is immutable once setup" do
    store = MyModel.serialized_attributes_store(:data)
    assert_raises(FrozenError) { store.instance_variable_set(:@attribute_types, {}) }
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

  test "change tracking: no changes after loading record and reading attributes" do
    record = MyModel.create!(normal_column: "yes", booly: false, stringy: "hello")

    assert_not record.booly? # triggers actually reading the column value...
    assert_not record.changed?, "Expected no changes, found: #{record.changes.as_json}"

    record = MyModel.find(record.id)
    assert_not record.changed?, "Expected no changes, found: #{record.changes.as_json}"

    record.booly = true
    assert record.changed?
  end

  test "change tracking: new records" do
    record = MyModel.new
    assert_not record.changed?

    record.booly = true
    assert record.changed?
  end
end
