# frozen_string_literal: true

require "set"

module JsonStore
  # JsonStore::Store is the individual store, keyed by name. You can get a reference to
  # the store by calling `Model.json_store_for(column_name)`.
  class Store
    def initialize(model_class, column_name, &block) # :nodoc:
      @model_class = model_class
      @column_name = column_name
      @attributes = {}
      @defaults = {}

      instance_exec(&block)
      wrap_store_column
      [self, @attributes, @defaults].each(&:freeze)
    end

    # Get a list of the attributes managed by this store
    def attribute_names = @attributes.keys

    # Cast a stored attribute against a given name
    #
    #    Model.json_store_for(:settings).cast(:user_name, 42)
    #    => "42"
    def cast(name, value)
      @attributes[name.to_sym].cast(value)
    end

    # Deserialize a stored attribute using the value from the database (or elsewhere)
    #
    #   Model.json_store_for(:settings).deserialize(:subscribed, "0")
    #   => false
    def deserialize(name, value)
      @attributes[name.to_sym].deserialize(value)
    end

    # Retrieve the default value for a given block. If the default is a Proc, it can be
    # optionally executed in the context of the model.
    #
    #   Model.json_store_for(:settings).default(:subscribed)
    #   #=> false
    def default(name, context = nil)
      given = @defaults[name]
      return (context || self).instance_exec(&given) if given.is_a?(Proc)

      given
    end

    private

    def attribute(name, type, **options)
      name = name.to_sym
      type = ActiveModel::Type.lookup(type, **options.except(:default)) if type.is_a?(Symbol)

      @attributes[name] = type
      @defaults[name] = options[:default] if options.key?(:default)

      @model_class.module_eval <<~RUBY, __FILE__, __LINE__ + 1
        def #{name}                                     # def user_name
          store = public_send(:#{@column_name})         #   store = public_send(:settings)
          if store.key?("#{name}")                      #   if store.key?("user_name")
            store["#{name}"]                            #     store["user_name"]
          else                                          #   else
            self.class.json_store_for(:#{@column_name}) #     self.class.json_store_for(:settings)
              .default(:#{name}, self)                  #       .default(:user_name, self)
          end                                           #   end
        end                                             # end

        def #{name}=(value)                             # def user_name=(value)
          cast_value = self.class                       #   cast_value = self.class
            .json_store_for(:#{@column_name})           #     .json_store_for(:settings)
            .cast(:#{name}, value)                      #     .cast(:user_name, value)
          store = public_send(:#{@column_name})         #   store = public_send(:settings)
          self.public_send(                             #   self.public_send(
            :#{@column_name}=,                          #     :settings=,
            store.merge("#{name}" => cast_value)        #     store.merge("user_name" => cast_value)
          )                                             #   )
        end                                             # end
      RUBY
    end

    class StoreColumnWrapper < SimpleDelegator # :nodoc:
      def initialize(original, json_store) # rubocop:disable Lint/MissingSuper
        __setobj__(original)
        @json_store = json_store
      end

      def deserialize(...)
        result = __getobj__.deserialize(...)
        return result unless @json_store && result.respond_to?(:each)

        result.each_with_object({}) do |(attribute_name, serialized_value), out|
          out[attribute_name] = @json_store.deserialize(attribute_name, serialized_value)
        end
      end
    end

    def wrap_store_column
      return unless @model_class.respond_to?(:attribute_types)

      original_store_column_type = @model_class.attribute_types.fetch(@column_name.to_s)
      @model_class.attribute(@column_name, StoreColumnWrapper.new(
                                             original_store_column_type,
                                             self
                                           ))
    end
  end
end
