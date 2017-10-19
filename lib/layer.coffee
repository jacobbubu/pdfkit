class Layer
  constructor: (@document, @name, @visible) -> @

  ref: ->
    @dictionary ?= @document.ref()

  finalize: ->
    return if !@dictionary?

    @dictionary.data =
      Type: 'OCG'
      Name: new String @name
    @dictionary.end()

module.exports = Layer
