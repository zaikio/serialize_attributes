# serialize_attributes

Serialize ActiveModel attributes in JSON using type casting:

```ruby
class MyModel
  serialize_attributes :settings do
    attribute :user_name, :string
    attribute :subscribed, :boolean, default: false
  end
end
```

> Unlike similar projects like [`ActiveRecord::TypedStore`](https://github.com/byroot/activerecord-typedstore),
> underneath this library doesn't  use the `store` interface and instead uses the native
> type coercion provided by ActiveModel (as long as you have an attribute recognised as a
> Hash-like object).

## Quickstart

Add `serialized_atributes` to your Gemfile:

```bash
$ bundle add serialized_atributes
```

Next, include `SerializeAttributes` in your model class (or `ApplicationRecord` if you want to make
it available everywhere). Your model should have a JSON (or JSONB) attribute, for example
this one is called `settings`:

```ruby
create_table :my_models do |t|
  t.json :settings, null: false, default: {}
end
```

Then, tell the model what attributes we'll be storing there:

```ruby
class MyModel < ActiveRecord::Base
  include SerializeAttributes

  serialize_attributes :settings do
    attribute :user_name, :string
    attribute :subscribed, :boolean, default: false
  end
end
```

Now you can read/write values on the model and they will be automatically cast to and from
database values:

```ruby
record = MyModel.create!(user_name: "Nick")
#=> #<MyModel id: 1, settings: { user_name: "Nick" }>

record.subscribed
#=> false

record.subscribed = true
record
#=> #<MyModel id: 1, settings: { user_name: "Nick", subscribed: true }>
```

### Getting all of the stored attributes

Default values are not automatically persisted to the database, so there is a helper
method to get the full object including default values:

```ruby
record = MyModel.new(user_name: "Nick")
record.serialized_attributes_on(:settings)
#=> { user_name: "Nick", subscribed: false }
```

### Getting a list of attribute names

If you wish to programmatically get the list of attributes known to a store, you can use
`.serialized_attribute_names`. The list is returned in order of definition:

```ruby
MyModel.serialized_attribute_names(:settings)
#=> [:user_name, :subscribed]
```

### Complex types

Underneath, we use the `ActiveModel::Type` mechanism for type coercion, which means
that more complex and custom types are also supported. For an example, take a look at
[ActiveModel::Type::Value](https://api.rubyonrails.org/classes/ActiveModel/Type/Value.html).

The `#attribute` method
[has the same interface as ActiveRecord](https://api.rubyonrails.org/classes/ActiveRecord/Attributes/ClassMethods.html#method-i-attribute),
and supports both symbols and objects for the `cast_type`:

```ruby
# An example from the Rails docs:
class MoneyType < ActiveRecord::Type::Integer
  def cast(value)
    if !value.kind_of?(Numeric) && value.include?('$')
      price_in_dollars = value.gsub(/\$/, '').to_f
      super(price_in_dollars * 100)
    else
      super
    end
  end
end

ActiveRecord::Type.register(:money, MoneyType)
```

```ruby
class MyModel
  serialize_attributes :settings do
    attribute :price_in_cents, :money
  end
end
```

### Array types

By default, `ActiveModel::Attribute` does not support Array types, however this library
does. The syntax is the same as `ActiveRecord::Attribute` when using the Postgres adapter:

```ruby
class MyModel
  serialize_attributes :settings do
    attribute :emails, :string, array: true
  end
end
```

Please note that the default value for an array attribute is always `[]`, unless you
specify a `default` attribute yourself explicitly:

```ruby
attribute :emails, :string, array: true, default: ["unknown@example.com"]
```

### Usage with ActiveModel alone

It's also possible to use this library without `ActiveRecord`:

```ruby
class MyModel
  include ActiveModel::Model
  include ActiveModel::Attributes
  include SerializeAttributes

  # ActiveModel doesn't include a native Hash type, we can just use the Value
  # type here for demo purposes:
  attribute :settings, ActiveModel::Type::Value

  serialize_attributes :settings do
    attribute :user_name, :string
  end
end
```

## License
The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
