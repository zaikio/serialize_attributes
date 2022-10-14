# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0]

This version moves some of the internals around. Now the store columns are modelled as an
`ActiveModel::AttributeSet`, rather than a simple hash. This allows the library to do
proper dirty tracking & casting, similar to how Rails itself works with regular attributes.

As a result of this change, unfortunately two (unused) features had to be removed:

* **BREAKING** Default values using a block are no longer supported
* **BREAKING** `Store#default` no longer accepts a second `context` argument
* **BREAKING** Arrays no longer support default values (default is always `[]`)

However, the following features have been added:

* Typecasting is now transparent to the user so complex types can be immediately read back
  after setting

## [0.6.0]

* Add predicated methods to attributes.

## [0.5.0]

* Add `enum` type using validator to core library.

## [0.4.1]

* Fix typecasting of BigDecimal just after creation of object
* Add descriptive error message when deserializing a non-existing attribute

## [0.4.0]

* Add support for listing array attributes

## [0.3.1]

* Don't raise an error when used with ActiveRecord models where the schema has not yet loaded

## [0.3.0]

* Add `type` parameter to `serialized_attribute_names` to filter by type.

## [0.2.0] - 2022-01-12

* Add support for `array: true` when specifying attributes

## 0.1.0 - 2021-12-16

* Initial release

[Unreleased]: https://github.com/zaikio/serialize_attributes/compare/v1.0.0..HEAD
[1.0.0]: https://github.com/zaikio/serialize_attributes/compare/v0.6.0..v1.0.0
[0.6.0]: https://github.com/zaikio/serialize_attributes/compare/v0.5.0..v0.6.0
[0.5.0]: https://github.com/zaikio/serialize_attributes/compare/v0.4.1..v0.5.0
[0.4.1]: https://github.com/zaikio/serialize_attributes/compare/v0.4.0..v0.4.1
[0.4.0]: https://github.com/zaikio/serialize_attributes/compare/v0.3.1..v0.4.0
[0.3.1]: https://github.com/zaikio/serialize_attributes/compare/v0.3.0..v0.3.1
[0.3.0]: https://github.com/zaikio/serialize_attributes/compare/v0.2.0..v0.3.0
[0.2.0]: https://github.com/zaikio/serialize_attributes/compare/v0.1.0..v0.2.0
