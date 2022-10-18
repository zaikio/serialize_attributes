# frozen_string_literal: true

module SerializeAttributes
  # SerializeAttributes::Store is the individual store, keyed by name. You can get a
  # reference to the store by calling `Model.serialized_attributes_store(column_name)`.
  class Store
    def initialize(model_class, column_name, &block) # :nodoc:
      @model_class = model_class
      @column_name = column_name
      @attribute_types = {}
      @defaults = {}

      instance_exec(&block)
      wrap_store_column
      [self, @attribute_types, @defaults].each(&:freeze)
    end

    attr_reader :attribute_types

    # Get a list of the attributes managed by this store. Pass an optional `type` argument
    # to filter attributes by their type.
    #
    #   Model.serialized_attributes_store(:settings).attribute_names
    #   => [:user_name, :subscribed, :subscriptions]
    #
    #   Model.serialized_attributes_store(:settings).attribute_names(type: :string)
    #   => [:user_name, :subscriptions]
    #
    #  Model.serialized_attributes_store(:settings).attribute_names(type: :string, array: true)
    #  => [:subscriptions]
    #
    #  Model.serialized_attributes_store(:settings).attribute_names(type: :string, array: false)
    #  => [:user_name]
    #
    #
    def attribute_names(type: nil, array: nil)
      attributes = @attribute_types
      attributes = @attribute_types.select { |_, v| v.is_a?(ArrayWrapper) == array } unless array.nil?
      if type
        attributes_for_type(attributes, type)
      else
        attributes
      end.keys.map(&:to_sym)
    end

    # Get a list of enumerated options for the column `name` in this store.
    #
    #   Model.serialized_attributes_store(:settings).enum_options(:enumy)
    #   => [nil, "placed", "confirmed"]
    def enum_options(name)
      type = @attribute_types.fetch(name.to_s)
      raise ArgumentError, "`#{name}` attribute is not an enum type" unless type.respond_to?(:options)

      type.options
    end

    # Cast a stored attribute against a given name into an
    # ActiveModel::Attribute::FromUser object (the cast value can be got using `#value`).
    #
    #    Model.serialized_attributes_store(:settings).cast(:user_name, 42).value
    #    => "42"
    def cast(name, value)
      type = @attributes_types.fetch(name.to_s)

      ActiveModel::Attribute.from_user(name, value, type)
    end

    # Deserialize a stored attribute using the value from the database (or elsewhere) into
    # an ActiveModel::Attribute::FromDatabase object (the cast value can be got using
    # `#value`).
    #
    #   Model.serialized_attributes_store(:settings).deserialize(:subscribed, "0").value
    #   => false
    def deserialize(name, value)
      type = @attribute_types[name.to_s]
      if type.nil?
        raise "The attribute #{name} is not defined in serialize_attribute method in the #{@model_class} class."
      end

      ActiveModel::Attribute.from_database(name, value, type)
    end

    # Retrieve the default value for a given block.
    #
    #   Model.serialized_attributes_store(:settings).default(:subscribed)
    #   #=> false
    def default(name)
      @defaults[name.to_s]
    end

    private

    def attributes_for_type(attributes, type)
      type = ActiveModel::Type.lookup(type)&.class if type.is_a?(Symbol)
      attributes.select do |_, v|
        v = v.__getobj__ if v.is_a?(ArrayWrapper)
        v.is_a?(type)
      end
    end

    NO_DEFAULT = Object.new

    def attribute(name, type, default: NO_DEFAULT, array: false, **type_options)
      name = name.to_s
      type = ActiveModel::Type.lookup(type, **type_options) if type.is_a?(Symbol)

      if array
        raise ArgumentError, "Enum-arrays not currently supported" if type.is_a?(Types::Enum)

        type = ArrayWrapper.new(type)
      end

      @attribute_types[name] = type

      if default != NO_DEFAULT
        @defaults[name] = default
      elsif array
        @defaults[name] = []
      end

      type.attach_validations_to(@model_class, name) if type.respond_to?(:attach_validations_to)

      @model_class.module_eval <<~RUBY, __FILE__, __LINE__ + 1
        def #{name}                               # def user_name
          store = public_send(:#{@column_name})   #   store = public_send(:settings)
          store.fetch_value("#{name}")            #   store.fetch_value("user_name")
        end                                       # end

        unless #{array}                           # unless false
          def #{name}?                            #   def user_name?
            query_attribute("#{name}")            #     query_attribute("user_name")
          end                                     #   end
        end                                       # end

        def #{name}=(value)                       # def user_name=(value)
          store = public_send(:#{@column_name})   #   store = public_send(:settings)
          try(:#{@column_name}_will_change!)      #   try(:settings_will_change!)
          store.write_from_user("#{name}", value) #   store.write_from_user("user_name", value)
        end                                       # end
      RUBY
    end

    class ArrayWrapper < SimpleDelegator # :nodoc:
      def cast(value)
        return [] if value.nil?

        Array(value)
      end

      def deserialize(value)
        Array.wrap(value).map { __getobj__.deserialize(_1) }
      end

      # For arrays of strings (the most common array type), the underlying Type::String in
      # Rails won't do this check if the raw value isn't a String (and returns `nil`):
      #
      #   def changed_in_place?(a, b)
      #     if a.is_a?(String)
      #       ...
      #
      # This means we have to override this check ourselves here.
      def changed_in_place?(raw_old_value, new_value)
        raw_old_value != new_value
      end
    end

    class AttributeSet < ::ActiveModel::AttributeSet # :nodoc:
      def ==(other)
        attributes == if other.is_a?(Hash)
                        other
                      else
                        other.attributes
                      end
      end
    end

    class StoreColumnWrapper < SimpleDelegator # :nodoc:
      def initialize(original, store) # rubocop:disable Lint/MissingSuper
        __setobj__(original)
        @store = store
      end

      def cast(value)
        case value
        when Hash then deserialize(value.stringify_keys)
        else value
        end
      end

      def changed_in_place?(raw_original_value, new_value)
        (deserialize(raw_original_value) != new_value) || new_value.each_value.any?(&:changed_in_place?)
      end

      def serialize(value)
        super(value.values_for_database)
      end

      def deserialize(...)
        result = super
        return result unless @store && result.respond_to?(:each)

        AttributeSet.new(
          @store.attribute_types.each_with_object({}) do |(attribute, type), out|
            out[attribute] = if result.key?(attribute)
                               @store.deserialize(attribute, result[attribute])
                             else
                               ActiveModel::Attribute.from_user(attribute, @store.default(attribute), type)
                             end
          end
        )
      end
    end

    # This method wraps the original store column and catches several read/write calls;
    # this gives us a chance to convert the data in the database back into our types.
    #
    # We using the block form of `.attribute` when the schema is lazily loaded (and has
    # not been loaded yet).
    def wrap_store_column
      if respond_to?(:schema_loaded?) && !schema_loaded?
        store = self
        @model_class.attribute(@column_name) do
          original_type = @model_class.attribute_types.fetch(@column_name.to_s)
          StoreColumnWrapper.new(original_type, store)
        end

      else
        original_type = @model_class.attribute_types.fetch(@column_name.to_s)
        type = StoreColumnWrapper.new(original_type, self)
        @model_class.attribute(@column_name, type)
      end
    end
  end
end
