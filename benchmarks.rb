#! /usr/bin/env ruby

require 'transproc/all'
require 'ruby-prof'
require 'ostruct'
require 'benchmark'

data = {
  foo: 1,
  bar: 2,
  baz: 3,
  qux: 4,
  buz: [5, 6, 7, 8],
  untouched: 'test'
}

module Operations
  extend Transproc::Registry

  import Transproc::HashTransformations
  import Transproc::ClassTransformations

  def self.my_map_value(hash, key, fn)
    new_value = fn[hash.fetch(key)]
    new_hash = hash.reject {|k, v| k == key}
    new_hash[key] = new_value
    new_hash
  end

  def self.map_from_keys(hash, mapping)
    hash.each_with_object({}) { |(k, v), memo| memo[k] = (mapping.key?(k) ? mapping[k].call(v) : v) }
  end
end

class Transform < Transproc::Transformer[Operations]
  map_value :foo, -> v { v.to_s }
  map_value :bar, -> v { v.to_s }
  map_value :baz, -> v { v.to_s }
  map_value :qux, -> v { v.to_s }
  map_value :buz, -> a { a.map(&:to_s) }
  constructor_inject OpenStruct
end

class MyTransform < Transproc::Transformer[Operations]
  map_from_keys foo: -> v {v.to_s}, bar: -> v {v.to_s}, baz: -> v {v.to_s}, qux: -> v {v.to_s}, buz: -> v { v.map(&:to_s) }
  constructor_inject OpenStruct
end

class PlainTransform
  def call(data)
    foo = data.fetch(:foo).to_s
    bar = data.fetch(:bar).to_s
    baz = data.fetch(:baz).to_s
    qux = data.fetch(:qux).to_s
    buz = data.fetch(:buz).map(&:to_s)
    new = data.reject {|k, v| [:foo, :bar, :baz, :qux, :buz].include?(k)}
    new[:foo] = foo
    new[:bar] = bar
    new[:baz] = baz
    new[:qux] = qux
    new[:buz] = buz

    OpenStruct.new(**new)
  end
end

RubyProf.start
Transform.new.call(data)
result = RubyProf.stop
printer = RubyProf::FlatPrinter.new(result)
printer.print(STDOUT)

RubyProf.start
MyTransform.new.call(data)
result = RubyProf.stop
printer = RubyProf::FlatPrinter.new(result)
printer.print(STDOUT)

Benchmark.bmbm(2) do |x|
  x.report('transproc:') { 10000.times do; Transform.new.call(data); end }
  x.report('my transproc:') { 10000.times do; MyTransform.new.call(data); end }
  x.report('plain transform:') { 10000.times do; PlainTransform.new.call(data); end }
end

puts Transform.new.call(data)
puts MyTransform.new.call(data)
puts PlainTransform.new.call(data)
