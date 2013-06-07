winston = require 'winston'

nodeEnv = process.env.NODE_ENV ? 'development'

constructorRegex = /^new /
methodRegex      = /at (.*) \(/
moduleRegex      = /(\w+)\.?(\w+)?:\d/
objectRegex      = /^Object\.(module\.exports\.)?/

class Logger extends winston.Logger
  constructor: (options = {}) ->
    options.exitOnError      ?= false
    options.transports       ?= []

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

    super options

  log: (level, message, metadata, callback) ->
    if typeof metadata == 'function'
      [callback, metadata] = [metadata, {}]

    callback ?= ->
    metadata ?= {}

    if message instanceof Error
      error = message
      stack = error.stack
      line = stack.split('\n')[1]
    else
      error = null
      stack = (new Error()).stack
      line = stack.split('\n')[3]

    Object.defineProperties metadata,
      _method:
        get: ->
          if match = methodRegex.exec line
            method = match[1].replace objectRegex, ''
            if constructorRegex.test method
              method = method.replace(constructorRegex, '') + '.constructor'
            method
          else
            '<unknown>'

        enumerable: false
      _module:
        get: ->
          if match = moduleRegex.exec line
            match[1]
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

  patchGlobal: ->
    process.on 'uncaughtException', (err) =>
      @log 'error', err, -> process.exit 1

module.exports = Logger
