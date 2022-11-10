# frozen_string_literal: true

module SerializeAttributes
  module Validators
    # This validator behaves exactly like a normal inclusion validator, except that it
    # passes the possible values to the error message, e.g:
    #
    #   class MyModel
    #      validates :foo, inclusion: { in: %w(a b c) }
    #
    #   record = MyModel.new
    #   record.validate
    #   record.errors.full_messages
    #   #=> ["Foo is not one of a, b, c"]
    class InclusionWithOptionsValidator < ::ActiveModel::Validations::InclusionValidator
      def validate_each(record, attribute, value)
        return if include?(record, value)

        humanised_options = options.fetch(:in).map { |option| option || "(null)" }.join(", ")

        record.errors.add(
          attribute,
          :inclusion_with_options,
          value: value,
          options: humanised_options
        )
      end
    end
  end
end
