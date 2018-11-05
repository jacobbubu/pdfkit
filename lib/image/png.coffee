zlib = require 'zlib'
PNG = require './png-decoder'

class PNGImage
  constructor: (data, @label) ->
    @image = new PNG(data)
    @iccProfile = @image.iccProfile
    @width = @image.width
    @height = @image.height
    @imgData = @image.imgData
    @obj = null

  embed: (@document) ->
    return if @obj

    @obj = @document.ref
      Type: 'XObject'
      Subtype: 'Image'
      BitsPerComponent: @image.bits
      Width: @width
      Height: @height
      Filter: 'FlateDecode'

    unless @image.hasAlphaChannel
      params = @document.ref
        Predictor: 15
        Colors: @image.colors
        BitsPerComponent: @image.bits
        Columns: @width

      @obj.data['DecodeParms'] = params
      params.end()

    if @image.palette.length is 0
      if @iccProfile
        @obj.data['ColorSpace'] = @document.getColorSpaceRef @iccProfile
      else
        if @image.colorSpace is 'DeviceRGB'
          @obj.data['ColorSpace'] = @document.getColorSpaceRef 'RGB'
        else
          @obj.data['ColorSpace'] = @image.colorSpace
    else
      # embed the color palette in the PDF as an object stream
      palette = @document.ref()
      palette.end new Buffer @image.palette

      # build the color space array for the image
      @obj.data['ColorSpace'] = ['Indexed', @document.getColorSpaceRef('RGB'), (@image.palette.length / 3) - 1, palette]

    # For PNG color types 0(greyscale), 2(truecolor) and 3(indexed), the transparency data is stored in
    # a dedicated PNG chunk.
    if @image.transparency.grayscale
      # Use Color Key Masking (spec section 4.8.5)
      # An array with N elements, where N is two times the number of color components.
      val = @image.transparency.grayscale
      @obj.data['Mask'] = [val, val]

    else if @image.transparency.rgb
      # Use Color Key Masking (spec section 4.8.5)
      # An array with N elements, where N is two times the number of color components.
      rgb = @image.transparency.rgb
      mask = []
      for x in rgb
        mask.push x, x

      @obj.data['Mask'] = mask

    else if @image.transparency.indexed
      # Create a transparency SMask for the image based on the data
      # in the PLTE and tRNS sections. See below for details on SMasks.
      # PNG 的索引色
      @loadIndexedAlphaChannel()

    else if @image.hasAlphaChannel
      # For PNG color types 4 and 6, the transparency data is stored as a alpha
      # channel mixed in with the main image data. Separate this data out into an
      # SMask object and store it separately in the PDF.
      @splitAlphaChannel()

    else
      @finalize()

  finalize: ->
    # 和 JPG 不同，如果需要 Alpha Channel，我们就需要生成一个 SMask Obj。
    if @alphaChannel
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
    @image = null
    @imgData = null

  splitAlphaChannel: ->
    # 对于全彩 + 透明数据，则需要分别提取出来，压缩后直接保存到 PDF Obj 中
    @image.decodePixels (pixels) =>
      colorByteSize = @image.colors * @image.bits / 8
      pixelCount = @width * @height
      imgData = new Buffer(pixelCount * colorByteSize)
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

  loadIndexedAlphaChannel: (fn) ->
    transparency = @image.transparency.indexed
    @image.decodePixels (pixels) =>
      # 索引色解码前是zip.deflate，再之前是滤波的，解码之后还是单通道的，每个像素的值是索引值
      alphaChannel = new Buffer(@width * @height)

      i = 0
      for j in [0...pixels.length] by 1
        # transparency 的值来自 tRNS 区块，包含着每个索引色对应的 alpha 值
        # 因此全图的 alpha 值就可以这么计算
        alphaChannel[i++] = transparency[pixels[j]]

      # 压缩一下就可以直接放到 PDF Obj 中了
      zlib.deflate alphaChannel, (err, @alphaChannel) =>
        throw err if err
        @finalize()

module.exports = PNGImage
