winston = require 'winston'

nodeEnv = process.env.NODE_ENV ? 'development'

methodRegex = /at (.*) \(/
objectRegex = /^Object\.(module\.exports\.)?/
moduleRegex = /(\w+)\.?(\w+)?:\d/

class Logger extends winston.Logger
  constructor: (options = {}) ->
    options.exitOnError      ?= false
    options.transports       ?= []
    options.sourceMapSupport ?= true

    options.colors ?=
      debug: 'blue'
      info:  'green'
      warn:  'yellow'
      error: 'red'

    options.levels ?=
      debug: 0
      info:  1
      warn:  2
      error: 3

    if options.souceMapSupport
      require('source-map-support').install handleUncaughtExceptions: false

    super options

  log: (level, message, metadata, callback) ->
    if typeof metadata == 'function'
      [callback, metadata] = [metadata, {}]

    callback ?= ->
    metadata ?= {}

    line = (new Error()).stack.split('\n')[3]

    if message instanceof Error
      error = message
    else
      error = null

    Object.defineProperties metadata,
      _method:
        get: ->
          (methodRegex.exec line)[1].replace objectRegex, ''
        enumerable: false
      _module:
        get: ->
          (moduleRegex.exec line)[1]
        enumerable: false
      _error:
        value: error
        enumerable: false

    super level, message, metadata, callback

  configure: (env, fn) ->
    if typeof env is 'string'
      fn.call @ if env == nodeEnv
    else
      @configure k, v for k,v of env

module.exports = Logger
