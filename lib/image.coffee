###
PDFImage - embeds images in PDF documents
By Devon Govett
###

fs = require 'fs'
Data = require './data'
JPEG = require './image/jpeg'
PNG = require './image/png'
TIFF = require './image/tiff'

isTiff = (buf) ->
  #  II or MM in first 2 chars
  first = buf.readUInt8(0)
  second = buf.readUInt8(1)
  if (first is 0x49 and second is 0x49) or (first is 0x4d and second is 0x4d)
      if first is 0x49
          buf.readUInt16LE(2) is 42
      else
          buf.readUInt16BE(2) is 42
  else
      false

class PDFImage
  @open: (src, label) ->
    if Buffer.isBuffer(src)
      data = src
    else if src instanceof ArrayBuffer
      data = new Buffer(new Uint8Array(src))
    else
      if match = /^data:.+;base64,(.*)$/.exec(src)
        data = new Buffer(match[1], 'base64')

      else
        data = fs.readFileSync src
        return unless data

    if data[0] is 0xff and data[1] is 0xd8
      return new JPEG(data, label)

    else if data[0] is 0x89 and data.toString('ascii', 1, 4) is 'PNG'
      return new PNG(data, label)

    else if isTiff(data)
      return new TIFF(data, label)

    else
      throw new Error 'Unknown image format.'

module.exports = PDFImage