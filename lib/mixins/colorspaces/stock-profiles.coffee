fs = require 'fs'
{ join } = require 'path'

profileDir = join __dirname, '../../../profiles'

class StockProfiles
  constructor: ->
    @_Lab50 = null
    @_DefaultCMYK = null
    @_DefaultRGB = null

    Object.defineProperties this,
      LabD50:
        enumerable: true
        get: => @_Lab50 ?= fs.readFileSync join(profileDir, 'LabD50.icc')
      DefaultCMYK:
        enumerable: true
        get: => @_DefaultCMYK ?= fs.readFileSync join(profileDir, 'CoatedFOGRA39.icc')
      DefaultRGB:
        enumerable: true
        get: => @_DefaultRGB ?= fs.readFileSync join(profileDir, 'sRGB Profile.icc')

module.exports = new StockProfiles()
