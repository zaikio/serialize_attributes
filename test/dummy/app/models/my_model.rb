class MyModel < ApplicationRecord
  serialize_attributes :data do
    attribute :booly, :boolean
    attribute :booly_default, :boolean, default: true

    attribute :stringy, :string
    attribute :timestamp, :datetime
  end
end
