zlib = require 'zlib'
{ decode } = require './tiff-decoder'

class TIFFImage
  constructor: (data, @label) ->
    decoded = decode data

    { @width, @height, @colorMode } = decoded
    @imgData = decoded.data
    @channels = decoded.entries.bitsPerSample.length
    @bitsPerSample = decoded.entries.bitsPerSample[0]
    @iccProfile = Buffer.from decoded.entries.iccProfile

    @hasAlphaChannel = @colorMode is 'RGB' and @channels is 4
    @colors = @channels - if @hasAlphaChannel then -1 else 0

    @obj = null

  embed: (@document) ->
    return if @obj

    @obj = @document.ref
      Type: 'XObject'
      Subtype: 'Image'
      BitsPerComponent: @bitsPerSample
      Width: @width
      Height: @height
      Filter: 'FlateDecode'

    if @iccProfile
      @obj.data['ColorSpace'] = @document.getColorSpaceRef @iccProfile
    else
      @obj.data['ColorSpace'] = switch @colorMode
        when 'RGB' then 'DeviceRGB'
        when 'CMYK' then 'DeviceCMYK'

    if @colorMode is 'CMYK'
      zlib.deflate @imgData, (err, @imgData) =>
        throw err if err
        @finalize()
    else
      @splitAlphaChannel()

  finalize: ->
    if @hasAlphaChannel and @alphaChannel
      sMask = @document.ref
        Type: 'XObject'
        Subtype: 'Image'
        Height: @height
        Width: @width
        BitsPerComponent: 8
        Filter: 'FlateDecode'
        ColorSpace: 'DeviceGray'
        Decode: [0, 1]

      sMask.end @alphaChannel
      @obj.data['SMask'] = sMask

    # add the actual image data
    @obj.end @imgData

    # free memory
    @imgData = null

  splitAlphaChannel: ->
    pixels = @imgData
    colorByteSize = @colors * @bitsPerSample / 8
    pixelCount = @width * @height
    imgData = new Buffer pixelCount * colorByteSize
    alphaChannel = new Buffer(pixelCount)

    i = p = a = 0
    len = pixels.length
    while i < len
      imgData[p++] = pixels[i++]
      imgData[p++] = pixels[i++]
      imgData[p++] = pixels[i++]
      alphaChannel[a++] = pixels[i++]

    done = 0
    zlib.deflate imgData, (err, @imgData) =>
      throw err if err
      @finalize() if ++done is 2

    zlib.deflate alphaChannel, (err, @alphaChannel) =>
      throw err if err
      @finalize() if ++done is 2

module.exports = TIFFImage