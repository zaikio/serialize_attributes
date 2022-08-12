# frozen_string_literal: true

module SerializeAttributes
  # SerializeAttributes::Store is the individual store, keyed by name. You can get a
  # reference to the store by calling `Model.serialized_attributes_store(column_name)`.
  class Store
    def initialize(model_class, column_name, &block)
      # :nodoc:
      @model_class = model_class
      @column_name = column_name
      @attributes = {}
      @defaults = {}

      instance_exec(&block)
      wrap_store_column
      [self, @attributes, @defaults].each(&:freeze)
    end

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
      attributes = @attributes
      attributes = @attributes.select { |_, v| v.is_a?(ArrayWrapper) == array } unless array.nil?
      if type
        attributes_for_type(attributes, type)
      else
        attributes
      end.keys
    end

    # Get a list of enumerated options for the column `name` in this store.
    #
    #   Model.serialized_attributes_store(:settings).enum_options(:enumy)
    #   => [nil, "placed", "confirmed"]
    def enum_options(name)
      type = @attributes.fetch(name.to_sym)
      raise ArgumentError, "`#{name}` attribute is not an enum type" unless type.respond_to?(:options)

      type.options
    end

    # Cast a stored attribute against a given name
    #
    #    Model.serialized_attributes_store(:settings).cast(:user_name, 42)
    #    => "42"
    def cast(name, value)
      # @attributes.fetch(name.to_sym) returns the Type as defined in ActiveModel::Type or
      # raise an error if the type is unknown.
      # Type::Integer.new.cast("42") => 42
      @attributes.fetch(name.to_sym).cast(value)
    end

    # Deserialize a stored attribute using the value from the database (or elsewhere)
    #
    #   Model.serialized_attributes_store(:settings).deserialize(:subscribed, "0")
    #   => false
    def deserialize(name, value)
      attribute = @attributes[name.to_sym]
      if attribute.nil?
        raise "The attribute #{name} is not defined in serialize_attribute method in the #{@model_class} class."
      end

      attribute.deserialize(value)
    end

    # Retrieve the default value for a given block. If the default is a Proc, it can be
    # optionally executed in the context of the model.
    #
    #   Model.serialized_attributes_store(:settings).default(:subscribed)
    #   #=> false
    def default(name, context = nil)
      given = @defaults[name]
      return (context || self).instance_exec(&given) if given.is_a?(Proc)

      given
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
      define_serialize_attribute_methods_on_instance
      name = name.to_sym
      type = ActiveModel::Type.lookup(type, **type_options) if type.is_a?(Symbol)
      type = wrap_array(type) if array

      @attributes[name] = type

      if default != NO_DEFAULT
        @defaults[name] = default
      elsif array
        @defaults[name] = []
      end

      type.attach_validations_to(@model_class, name) if type.respond_to?(:attach_validations_to)

      @model_class.module_eval <<~RUBY, __FILE__, __LINE__ + 1
        def #{name}                                            # def user_name
          store = public_send(:#{@column_name})                #   store = public_send(:settings)
          if store.key?("#{name}")                             #   if store.key?("user_name")
            value = store["#{name}"]                           #     value = store["user_name"]
            # Decimal typecasting fails in the setter (public_send(:settings=, store)) after
            # an attribute is assigned, even a non decimal attribute. Typecasting is fine
            # when reading from the DB or after save. So we check for store that have been
            # assigned but not saved and decimal.
            return value unless @attributes["#{@column_name}"] #   return value unless @attributes["settings"]
              .came_from_user? && _decimal?("#{name}")         #      .came_from_user? && _decimal?("user_name")
                                                               #
            _cast(:#{name}, value)                             #     _cast(:user_name, value)
          else                                                 #   else
            _store(:#{@column_name}).default(:#{name}, self)   #     _store(:setting).default(:user_name, self)
          end                                                  #   end
        end                                                    # end
                                                               #
        unless #{array}                                        # unless array
          def #{name}?                                         #   def user_name?
            query_attribute("#{name}")                         #     query_attribute(:user_name)
          end                                                  #   end
        end                                                    # end
                                                               #
        def #{name}=(value)                                    # def user_name=(value)
          cast_value = _cast(:#{name}, value)                  #   cast_value = _cast(:user_name, value)
          store = public_send(:#{@column_name})                #   store = public_send(:settings)
                                                               #
          if #{array} && cast_value == ArrayWrapper::EMPTY     #   if array && cast_value == ArrayWrapper::EMPTY
            store.delete("#{name}")                            #     store.delete("user_name")
          else                                                 #   else
            store.merge!("#{name}" => cast_value)              #     store.merge!("user_name" => cast_value)
          end                                                  #   end
          public_send(:#{@column_name}=, store)                #   public_send(:settings=, store)
        end                                                    # end
      RUBY
    end

    def define_serialize_attribute_methods_on_instance
      return if @instance_methods_defined

      @model_class.module_eval <<~RUBY, __FILE__, __LINE__ + 1
        def _cast(attribute, value)                                                       # def _cast(attribute, value)
          _store(:#{@column_name}).cast(attribute, value)                                 #   _store(:setting).cast(attribute, value)
        end                                                                               # end
                                                                                          #
        def _decimal?(attribute)                                                          # def _decimal?(attribute)
          _store(:#{@column_name}).instance_variable_get(:@attributes)[attribute.to_sym]  #   _store(:setting).instance_variable_get(:@attributes)[attribute.to_sym]
            .class == ActiveModel::Type::Decimal                                          #     .class == ActiveModel::Type::Decimal
        end                                                                               # end
                                                                                          #
        def _store(column_name)                                                           # def _store(column_name)
          self.class.serialized_attributes_store(column_name)                             #   self.class.serialized_attributes_store(column_name)
        end                                                                               # end
      RUBY
      @instance_methods_defined = true
    end

    def wrap_array(type)
      raise ArgumentError, "Enum-arrays not currently supported" if type.is_a?(Types::Enum)

      ArrayWrapper.new(type)
    end

    class ArrayWrapper < SimpleDelegator # :nodoc:
      EMPTY = Object.new

      def cast(value)
        # We don't want to store the null value, because array types _always_ have a default
        # configured. So we return this special object here, and check it again before
        # updating the underlying store.
        return EMPTY unless value

        Array(value)
      end

      def deserialize(value)
        value.map { __getobj__.deserialize(_1) }
      end
    end

    class StoreColumnWrapper < SimpleDelegator # :nodoc:
      def initialize(original, store) # rubocop:disable Lint/MissingSuper
        __setobj__(original)
        @store = store
      end

      def deserialize(...)
        result = __getobj__.deserialize(...)
        return result unless @store && result.respond_to?(:each)

        result.each_with_object({}) do |(attribute_name, serialized_value), out|
          out[attribute_name] = @store.deserialize(attribute_name, serialized_value)
        end
      end
    end

    # This method wraps the original store column and catches the `deserialize` call -
    # this gives us a chance to convert the data in the database back into our types.
    #
    # We're using the block form of `.attribute` to avoid loading the database schema just
    # to figure out our wrapping type.
    def wrap_store_column
      return unless @model_class.respond_to?(:attribute_types)

      store = self

      @model_class.attribute(@column_name) do
        original_type = @model_class.attribute_types.fetch(@column_name.to_s)
        StoreColumnWrapper.new(original_type, store)
      end
    end
  end
end
