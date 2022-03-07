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
    #   Model.serialize_attributes_store(:settings).attribute_names
    #   => [:user_name, :subscribed, :subscriptions]
    #
    #   Model.serialize_attributes_store(:settings).attribute_names(type: :string)
    #   => [:user_name, :subscriptions]
    #
    #  Model.serialize_attributes_store(:settings).attribute_names(type: :string, array: true)
    #  => [:subscriptions]
    #
    #  Model.serialize_attributes_store(:settings).attribute_names(type: :string, array: false)
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

    # Cast a stored attribute against a given name
    #
    #    Model.serialized_attributes_store(:settings).cast(:user_name, 42)
    #    => "42"
    def cast(name, value)
      @attributes[name.to_sym].cast(value)
    end

    # Deserialize a stored attribute using the value from the database (or elsewhere)
    #
    #   Model.serialized_attributes_store(:settings).deserialize(:subscribed, "0")
    #   => false
    def deserialize(name, value)
      @attributes[name.to_sym].deserialize(value)
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

    def attribute(name, type, **options)
      name = name.to_sym
      arr = options.delete(:array) { false }
      type = ActiveModel::Type.lookup(type, **options.except(:default)) if type.is_a?(Symbol)
      type = ArrayWrapper.new(type) if arr

      @attributes[name] = type

      if options.key?(:default)
        @defaults[name] = options[:default]
      elsif arr
        @defaults[name] = []
      end

      @model_class.module_eval <<~RUBY, __FILE__, __LINE__ + 1
        def #{name}                                          # def user_name
          store = public_send(:#{@column_name})              #   store = public_send(:settings)
          if store.key?("#{name}")                           #   if store.key?("user_name")
            store["#{name}"]                                 #     store["user_name"]
          else                                               #   else
            self.class                                       #     self.class
              .serialized_attributes_store(:#{@column_name}) #       .serialized_attributes_store(:settings)
              .default(:#{name}, self)                       #       .default(:user_name, self)
          end                                                #   end
        end                                                  # end

        def #{name}=(value)                                  # def user_name=(value)
          cast_value = self.class                            #   cast_value = self.class
            .serialized_attributes_store(:#{@column_name})   #     .serialized_attributes_store(:settings)
            .cast(:#{name}, value)                           #     .cast(:user_name, value)
          store = public_send(:#{@column_name})              #   store = public_send(:settings)
                                                             #
          if #{arr} && cast_value == ArrayWrapper::EMPTY     #   if false && cast_value == ArrayWrapper::EMPTY
            store.delete("#{name}")                          #     store.delete("user_name")
          else                                               #   else
            store.merge!("#{name}" => cast_value)            #     store.merge!("user_name" => cast_value)
          end                                                #   end
                                                             #
          self.public_send(:#{@column_name}=, store)         #   self.public_send(:settings=, store)
        end                                                  # end
      RUBY
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
