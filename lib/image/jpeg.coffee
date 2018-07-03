ICC_PROFILE = new Buffer 'ICC_PROFILE\x00'

class JPEG
  MARKERS = [0xFFC0, 0xFFC1, 0xFFC2, 0xFFC3, 0xFFC5, 0xFFC6, 0xFFC7,
             0xFFC8, 0xFFC9, 0xFFCA, 0xFFCB, 0xFFCC, 0xFFCD, 0xFFCE, 0xFFCF]

  constructor: (@data, @label) ->
    if @data.readUInt16BE(0) isnt 0xFFD8
      throw "SOI not found in JPEG"

    pos = 2
    @iccProfile = null
    while pos < @data.length
      marker = @data.readUInt16BE(pos)
      pos += 2
      break if marker in MARKERS

      blockLength = @data.readUInt16BE(pos) - 2
      pos += 2
      # APP2 - ICC Profile
      if marker is 0xFFE2
        if @data.includes(ICC_PROFILE, pos)
          # 14 = length of ICC_PROFILE\x00 + chuankNum + totalChunks
          chunk = @data.slice pos + 14, pos + blockLength
          if !@iccProfile
            @iccProfile = chunk
          else
            @iccProfile = Buffer.concat [@iccProfile, chunk]

          pos += blockLength
      else
        pos += blockLength

    throw "Invalid JPEG." unless marker in MARKERS
    pos += 2

    @bits = @data[pos++]
    @height = @data.readUInt16BE(pos)
    pos += 2

    @width = @data.readUInt16BE(pos)
    pos += 2

    @channels = @data[pos++]
    @obj = null

  embed: (document) ->
    return if @obj

    @obj = document.ref
      Type: 'XObject'
      Subtype: 'Image'
      BitsPerComponent: @bits
      Width: @width
      Height: @height
      Filter: 'DCTDecode'

    if @iccProfile
      @obj.data['ColorSpace'] = document.getColorSpaceRef @iccProfile
    else
      colorSpace = switch @channels
        when 1:
          @obj.data['ColorSpace'] = document.getColorSpaceRef 'CALGRAY'
        when 3:
          @obj.data['ColorSpace'] = document.getColorSpaceRef 'RGB'
        when 4:
          @obj.data['ColorSpace'] = document.getColorSpaceRef 'CMYK'

      # add extra decode params for CMYK images. By swapping the
      # min and max values from the default, we invert the colors. See
      # section 4.8.4 of the spec.
    if @channels is 4
      @obj.data['Decode'] = [1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0]

    @obj.end @data
    # free memory
    @data = null

module.exports = JPEG
