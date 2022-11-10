# frozen_string_literal: true

require "active_support/core_ext/module/delegation"

module SerializeAttributes
  module Types
    # A custom type which can only hold one of a set of predetermined values.
    class Enum
      attr_reader :options

      # Construct a type instance.
      #
      # @param of   [Array]  One or more possible values that this type can take
      # @param type [Symbol] An optional ActiveModel::Type instance, or symbol, for
      #                      casting/uncasting (only required if enum has non-primitive types)
      #
      # @example Required to be one of two values
      #   attribute :state, :enum, of: ["placed", "confirmed"]
      #
      # @example Optionally allowing nil
      #   attribute :folding, :enum, of: [nil, "top-fold", "bottom-fold"]
      #
      # @example Casting input/output using another type
      #   attribute :loves_pizza, :enum, of: [true], type: :boolean
      #   # object.loves_pizza = "t"
      #   #=> true
      def initialize(of: [], type: nil)
        @options = of.freeze
        @type    = resolve_type(type)
      end

      def attach_validations_to(object, field_name)
        object.validates_with(
          Validators::InclusionWithOptionsValidator,
          attributes: [field_name],
          in: @options
        )
      end

      delegate_missing_to :@type

      private

      UNTYPED_TYPE = ActiveModel::Type::Value.new

      def resolve_type(given)
        case given
        in Symbol then ActiveModel::Type.lookup(given)
        in nil    then UNTYPED_TYPE
        in _      then given
        end
      end
    end
  end
end

ActiveModel::Type.register(:enum, SerializeAttributes::Types::Enum)
