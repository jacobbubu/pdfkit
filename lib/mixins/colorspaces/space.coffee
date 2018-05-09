{ parse } = require 'icc'
PDFReference = require '../../reference'
stockProfiles = require './stock-profiles'

D50 = '[0.964203 1.0000 0.824905]'
BlackPoint = '[0.0 0.0 0.0]'

getChannels = (name) ->
  switch name.toUpperCase()
    when 'RGB' then 3
    when 'Lab' then 3
    when 'CMYK' then 4
    when 'GRAY' then 1
    when 'XYZ' then 3
    else 3

# Save ICC Profile to PDF stream
profileToRef = (document, profile, alt) ->
  { colorSpace } = parse profile

  # alt either be a PDFObject or a string (e.g. DeviceCMYK)
  stream = document.ref
    N: getChannels(colorSpace)

  stream.data.Alternate = alt if alt
  stream.end profile

  ref = document.ref ["ICCBased #{stream.toString()}"]
  ref.end()
  ref

# Build predefined Colorspace(case-insensitive) to PDF
nameToRef = (document, name) ->
  switch name.toUpperCase()
    when 'CALGRAY'
      ref = document.ref ["CalGray <</WhitePoint #{D50}"]
      ref.end()
    when 'CALRGB'
      ref = document.ref ["CalRGB <</WhitePoint #{D50}"]
      ref.end()
    when 'LAB'
      alt = document.ref ["""
        Lab <</BlackPoint #{BlackPoint} /WhitePoint #{D50} /Range [-128 127 -128 127]>>
      """]
      alt.end()
      ref = profileToRef document, stockProfiles.LabD50, alt
    when 'CMYK'
      ref = profileToRef document, stockProfiles.DefaultCMYK, 'DeviceCMYK'
    when 'RGB'
      ref = profileToRef document, stockProfiles.DefaultRGB, 'DeviceRGB'
    else
      throw new Error "Unsupported colorspace('#{name}')"
  ref

counter = do ->
  count = 0
  -> count++

class Space
  constructor: (@document, record, alt) ->
    @ref = null
    @_colorSpaceCount = 0
    @_label = null

    if Buffer.isBuffer record
      @ref = profileToRef @document, record, alt
    else if typeof record is 'string'
      @ref = nameToRef @document, record
    else if record instanceof PDFReference
      @ref = record
    else
      throw new Error "Unsupported colorspace type('#{record}')"

    Object.defineProperties @,
      'label':
        # enumerable: true
        get: =>
          @_label ?= "CS#{counter()}"
          @document.page.colorspace[@_label] ?= @ref
          @_label

module.exports = Space
