class MyModel < ApplicationRecord
  serialize_attributes :data do
    attribute :booly, :boolean
    attribute :booly_default, :boolean, default: true

    attribute :stringy, :string
    attribute :timestamp, :datetime

    attribute :listy, :string, array: true
    attribute :listy_default, :string, array: true, default: ["first"]

    attribute :listy_integer, :integer, array: true
  end
end
