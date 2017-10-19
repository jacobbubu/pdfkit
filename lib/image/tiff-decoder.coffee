zlib = require 'zlib'

###
 Required Fields for Bilevel Images

   ImageWidth 256 100 SHORT or LONG
   ImageLength 257 101 SHORT or LONG
   Compression 259 103 SHORT 1, 2 or 32773
   PhotometricInterpretation 262 106 SHORT 0 or 1
   StripOffsets 273 111 SHORT or LONG
   RowsPerStrip 278 116 SHORT or LONG
   StripByteCounts 279 117 LONG or SHORT
   XResolution 282 11A RATIONAL
   YResolution 283 11B RATIONAL
   ResolutionUnit 296 128 SHORT 1, 2 or 3
###

TAG_NAME_MAP =
  0x0100: 'imageWidth'
  0x0101: 'imageLength'
  0x0102: 'bitsPerSample'
  0x0103: 'compression'
  0x0106: 'photometricInterpretation'
  0x0111: 'stripOffsets'
  0x0116: 'rowsPerStrip'
  0x0117: 'stripByteCounts'
  0x0128: 'resolutionUnit'
  0x0140: 'colorMap'
  0x8773: 'iccProfile'

loadPages = (buf) ->

  idx = 0; isMSB = undefined; ifdEntries = {}; stripData = undefined

  read = (offset, length) ->
    begin = offset
    end = offset + length
    if isMSB
      buf.subarray begin, end
    else
      s = buf.subarray(begin, end)
      x = new Uint8Array(end - begin)
      i = 0
      while i < s.byteLength
        x[s.byteLength - i - 1] = s[i]
        i++
      x

  readRaw = (offset, length) ->
    begin = offset
    end = offset + length
    buf.subarray begin, end

  readAsUint16 = (offset, length = 1, force) ->
    if isMSB
      dd = new DataView(buf.buffer)
      if length > 1 or force
        y = new Uint16Array(length)
        i = 0
        while i < length
          y[i] = dd.getUint16(offset + (i << 1))
          i++
        y
      else
        dd.getUint16 offset
    else
      d = new DataView(read(offset, length << 1).buffer)
      if length > 1 or force
        x = new Uint16Array(length)
        i = 0
        while i < length
          x[i] = d.getUint16(i << 1)
          i++
        x
      else
        d.getUint16 0

  readAsUint32 = (offset, length = 1, force) ->
    if isMSB
      dd = new DataView(buf.buffer)
      if length > 1 or force
        y = new Uint32Array(length)
        i = 0
        while i < length
          y[i] = dd.getUint32(offset + (i << 2))
          i++
        y
      else
        dd.getUint32 offset
    else
      d = new DataView(read(offset, length << 2).buffer)
      if length > 1 or force
        x = new Uint32Array(length)
        i = 0
        while i < length
          x[i] = d.getUint32(i << 2)
          i++
        x
      else
        d.getUint32 0

  ###
    The field types and their sizes are:

      1  = BYTE 8-bit unsigned integer.
      2  = ASCII 8-bit byte that contains a 7-bit ASCII code; the last byte must be NUL (binary zero).
      3  = SHORT 16-bit (2-byte) unsigned integer.
      4  = LONG 32-bit (4-byte) unsigned integer.
      5  = RATIONAL Two LONGs: the first represents the numerator of a fraction; the second, the denominator.

    In TIFF 6.0, some new field types have been defined:

      6  = SBYTE An 8-bit signed (twos-complement) integer.
      7  = UNDEFINED An 8-bit byte that may contain anything, depending on the definition of the field.
      8  = SSHORT A 16-bit (2-byte) signed (twos-complement) integer.
      9  = SLONG A 32-bit (4-byte) signed (twos-complement) integer.
      10 = SRATIONAL Two SLONG’s: the first represents the numerator of a fraction, the second the denominator.
      11 = FLOAT Single precision (4-byte) IEEE format.
      12 = DOUBLE Double precision (8-byte) IEEE format
  ###

  byteLength = (fieldType, numOfValues) ->
    switch fieldType
      when 1, 7
        return numOfValues
      when 3
        return numOfValues << 1
      when 4
        return numOfValues << 2
      when 5
        return numOfValues << 3
      else
        return numOfValues << 2

  parseIFDFieldValueToArray = (fieldType, numOfValues, valueOffset) ->
    bl = byteLength(fieldType, numOfValues)
    if bl > 4
      valueOffset = readAsUint32(valueOffset)
    if bl < 4
      l = 4 / bl
    else
      l = numOfValues
    x = undefined
    switch fieldType
      when 7
        x = readRaw(valueOffset, l)
      when 1, 3
        x = readAsUint16(valueOffset, l, true)
      when 4
        x = readAsUint32(valueOffset, l, true)
    if !x
      return
    if bl < 4
      if isMSB then x.slice(0, l - numOfValues) else x.slice(l - numOfValues)
    else
      x

  parseIFDEntry = (tagId, fieldType, numOfValues, valueOffset) ->
    k = TAG_NAME_MAP[tagId]
    if k
      ifdEntries[k] = parseIFDFieldValueToArray(fieldType, numOfValues, valueOffset)
    else
      # TODO
      # console.log("unknown IFD entry: ", tagId, fieldType, numOfValues, valueOffset);
    return

  readStrips = (ifdEntries) ->
    ret = new Uint8Array ifdEntries.stripByteCounts.reduce ((s, b) -> s + b), 0
    copiedBl = 0
    for s in [0...ifdEntries.stripOffsets.length]
      x = buf.subarray ifdEntries.stripOffsets[s], ifdEntries.stripOffsets[s] + ifdEntries.stripByteCounts[s]
      ret.set x, copiedBl
      copiedBl += x.byteLength
    ret

  # Image File Header
  # Byte order
  if buf[0] is 0x4d and buf[1] is 0x4d
    isMSB = true
  else if buf[0] is 0x49 and buf[1] is 0x49
    isMSB = false
  else
    throw new Error('Invalid byte order ' + buf[0] + buf[1])
  if read(2, 2)[1] != 0x2a
    throw new Error('not tiff')
  pages = []
  ifdOffset = readAsUint32(4)
  while ifdOffset != 0
    # Number of Directory Entries
    idx = ifdOffset
    numOfIFD = readAsUint16(idx)
    ifdEntries = {}
    # IFD Entries
    idx += 2
    i = 0
    while i < numOfIFD
      # TAG
      tagId = readAsUint16(idx)
      # Field type
      idx += 2
      fieldType = readAsUint16(idx)
      # The number of values
      idx += 2
      numOfValues = readAsUint32(idx)
      # The value offset
      idx += 4
      valueOffset = idx
      parseIFDEntry tagId, fieldType, numOfValues, valueOffset
      idx += 4
      i++
    stripData = readStrips(ifdEntries)
    pages.push
      stripData: stripData
      ifdEntries: ifdEntries
    ifdOffset = readAsUint32(idx)

    return pages

decompressData = (ifdEntries, stripData) ->
  { compression } = ifdEntries
  if !compression or compression[0] is 1
    # no-compress
    return stripData
  else if compression[0] is 2
    # CCITT Group 3
    throw new Error('CCITT group3 decompressionion is not implemented.')
  else if compression[0] is 5
    # LZW
    throw new Error('LZW decompressionion is not implemented.')
  else if compression[0] is 6
    # JPEG
    throw new Error('JPEG decompressionion is not implemented.')
  else if compression[0] is 7
    # JPEG2
    throw new Error('JPEG2 decompressionion is not implemented.')
  else if compression[0] is 8
    # Zip(Adobe Deflate)
    return Uint8Array.from zlib.unzipSync(stripData)
    # throw new Error('Zip (Adove Deflate) decompressionion is not implemented.')
  else if compression[0] is 32773
    # Packbits
    throw new Error('Packbits decompression is not implemented.')
  else
    throw new Error('Unknown compression type: ' + compression[0])

###
  PHOTOMETRIC_MINISWHITE = 0;
  PHOTOMETRIC_MINISBLACK = 1;
  PHOTOMETRIC_RGB = 2;
  PHOTOMETRIC_PALETTE = 3;
  PHOTOMETRIC_MASK = 4;
  PHOTOMETRIC_SEPARATED = 5;
  PHOTOMETRIC_YCBCR = 6;
  PHOTOMETRIC_CIELAB = 8;
  PHOTOMETRIC_ICCLAB = 9;
  PHOTOMETRIC_ITULAB = 10;
  PHOTOMETRIC_LOGL = 32844;
  PHOTOMETRIC_LOGLUV = 32845;
###

normalizeStripData = (ifdEntries, stripData) ->
  { colorMap, bitsPerSample, photometricInterpretation } = ifdEntries

  stripData = decompressData(ifdEntries, stripData)
  if !bitsPerSample
    throw new Error('Bilevel image decode is not implemented.')
  if colorMap
    throw new Error('Palette-color image decode is not implemented.')
  if photometricInterpretation[0] is 2 and bitsPerSample.length is 4
    # 32bit RBGA image
    return stripData
  else if photometricInterpretation[0] is 2 and bitsPerSample.length is 3
    # 24bit RBG image, extend to 32bits with alpha channel
    x = new Uint8Array(stripData.length / 3 * 4)
    i = 0
    while i < stripData.length / 3
      x[i * 4] = stripData[i * 3]
      x[i * 4 + 1] = stripData[i * 3 + 1]
      x[i * 4 + 2] = stripData[i * 3 + 2]
      x[i * 4 + 3] = 0xff
      i++
    return x
  else if photometricInterpretation[0] < 2 and bitsPerSample.length is 1 and bitsPerSample[0] is 4
    # 4bit grayscale image，将灰度值放大16倍
    # 不太理解，为什么要将后续像素放到其他色彩通道, 难道不是RGB三个通道值一样吗?
    x = new Uint8Array(stripData.length * 4)
    i = 0
    while i < stripData.length
      x[i * 4] = stripData[i] << 4
      x[i * 4 + 1] = stripData[i + 1] << 4
      x[i * 4 + 2] = stripData[i + 2] << 4
      x[i * 4 + 3] = 0xff
      i++
    return x
  else if photometricInterpretation[0] < 2 and bitsPerSample.length is 1 and bitsPerSample[0] is 8
    # 8bit grayscale image
    x = new Uint8Array(stripData.length * 4)
    i = 0
    while i < stripData.length
      x[i * 4] = stripData[i]
      x[i * 4 + 1] = stripData[i + 1]
      x[i * 4 + 2] = stripData[i + 2]
      x[i * 4 + 3] = 0xff
      i++
    return x
  else if photometricInterpretation[0] is 5 and bitsPerSample.length is 4 and bitsPerSample[0] is 8
    # CMYK
    return stripData
  else
    throw new Error('Can\'t detect image type. PhotometricInterpretation: ' + photometricInterpretation[0] + ', BitsPerSample: ' + bitsPerSample)

decode = (buf, opt = { singlePage: true }) ->
  rawPages = loadPages new Uint8Array(buf)
  pages = rawPages.map (rawPage) ->
    entries = rawPage.ifdEntries
    width = entries.imageWidth[0]
    height = entries.imageLength[0]
    pi = entries.photometricInterpretation[0]
    colorMode = switch pi
      when 2, 3 then 'RGB'   # Both 2-RGB and 3-PALETTE are in RGB mode
      when 5 then 'CMYK'
      else throw new Error("We only support 2-RGB, 3-PALLETE and 5-CMYK for photometricInterpretation#{pi}")
    data = normalizeStripData(entries, rawPage.stripData)
    { width, height, colorMode, data, entries }

  if opt.singlePage
    if !pages or !pages.length
      throw new Error('No pages')
    pages[0]
  else
    pages

module.exports = { decode }
