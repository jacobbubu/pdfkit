{ ColorSpaces, Space } = require './colorspaces'

module.exports =
  initColorSpace: ->
    @_colorSpaces = new ColorSpaces @

  getColorSpace: (space) ->
    @_colorSpaces.getSpaceObj(space)

  getColorSpaceRef: (space) ->
    @_colorSpaces.getSpaceObj(space).ref

  getColorSpaceLabel: (space) ->
    @_colorSpaces.getSpaceLabel(space)
