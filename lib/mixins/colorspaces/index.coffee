assert = require 'assert'
{ parse } = require 'icc'
Space = require './space'

encodeColorName = (s) -> s.replace /\s/g, '#20'

buildSeparationSpace = (document, record, colorSpaces) ->
  { name, colorSpace: space, components } = record
  encodedName = encodeColorName name
  switch space.toUpperCase()
    when 'GRAY'
      colorSpaces['CALGRAY'] ?= new Space document, 'CALGRAY'

      ref = document.ref ["""Separation
        /#{encodedName}
        #{colorSpaces['CALGRAY'].ref.toString()}
        <<
          /C0[0.0 0.0]
          /C1[#{components[0]}]
          /Domain[0 1]
          /FunctionType 2
          /N 1.0
          /Range[0.0 1.0]
        >>
      """]
    when 'LAB'
      colorSpaces['LAB'] ?= new Space document, 'LAB'

      ref = document.ref ["""Separation
        /#{encodedName}
        #{colorSpaces['LAB'].ref.toString()}
        <<
          /C0[0.0 0.0 0.0]
          /C1[#{components.join(' ')}]
          /Domain[0 1]
          /FunctionType 2
          /N 1.0
          /Range[0.0 100 -128 127 -128 127]
        >>
      """]
    when 'RGB'
      colorSpaces['RGB'] ?= new Space document, 'RGB'

      ref = document.ref ["""Separation
        /#{encodedName}
        #{colorSpaces['RGB'].ref.toString()}
        <<
          /C0[0.0 0.0 0.0]
          /C1[#{components.join(' ')}]
          /Domain[0 1]
          /FunctionType 2
          /N 1.0
          /Range[0.0 1.0 0.0 1.0 0.0 1.0]
        >>
      """]
    when 'CMYK'
      colorSpaces['CMYK'] ?= new Space document, 'CMYK'

      ref = document.ref ["""Separation
        /#{encodedName}
        #{colorSpaces['CMYK'].ref.toString()}
        <<
          /C0[0.0 0.0 0.0 0.0]
          /C1[#{components.join(' ')}]
          /Domain[0 1]
          /FunctionType 2
          /N 1.0
          /Range[0.0 1.0 0.0 1.0 0.0 1.0 0.0 1.0]
        >>
      """]
    else
      throw new Error("Unsupported color space('#{space}') for separation space")
  ref.end()
  ref

class ColorSpaces
  constructor: (@document) ->
    @colorSpaces = {}

  getSpaceObj: (record) ->
    profile = record
    if Buffer.isBuffer profile
      { description: name } = parse profile
      @colorSpaces[name] ?= new Space @document, profile
    else if typeof record is 'string'
      name = record.toUpperCase()
      @colorSpaces[name] ?= new Space @document, name
    else if typeof record is 'object'
      { name, colorSpace, components } = record
      assert name, 'The name of separation space is required'
      assert colorSpace, 'The colorSpace of separation space is required'
      assert components, 'The components of separation space is required'

      @colorSpaces[name] ?= new Space @document,
        buildSeparationSpace(@document, record, @colorSpaces)
    else
      throw new Error "Unsupported parameter type('#{record}')"

    @colorSpaces[name]

  getSpaceLabel: (record) -> @getSpaceObj(record).label

module.exports = { ColorSpaces, Space }
