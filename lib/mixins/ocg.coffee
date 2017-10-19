assert = require 'assert'
Layer = require '../layer'

module.exports =
  initOCG: ->
    # document width layer informations
    @_layers ?= {}

  beginOCG: (layerName, visible=true) ->
    assert layerName, 'layerName required'

    @page._currentLayerName ?= ''
    @page._shouldEndOCG = true
    if @page._currentLayerName is layerName
        @page._shouldEndOCG = false
        return @

    layer = @_layers[layerName] ? new Layer(@, layerName, visible)
    @_layers[layerName] = layer

    mark = null
    # find page level mark for layer
    @page._marks ?= []
    @page._markId ?= 1
    for m in @page._marks
        if m.layerName is layerName
            mark = m

    if !mark
        mark =
            name: 'OC'+ @page._markId++
            layerName: layerName
        @page._marks.push mark

    @page.properties[mark.name] ?= layer.ref()

    @addContent "/OC /#{mark.name} BDC"
    @

  endOCG: ->
    if @page._shouldEndOCG
        @addContent 'EMC'
        @page._shouldEndOCG = false
    @