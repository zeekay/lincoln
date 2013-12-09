winston    = require 'winston'
postmortem = require 'postmortem'
utils      = require './utils'


class Logger extends winston.Logger
  constructor: (options = {}) ->
    options.exitOnError ?= false
    options.transports  ?= []

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

    @_nodeEnv = process.env.NODE_ENV ? 'development'
    @_captureLocation = options.captureLocation ? true

    postmortem.install()

    super options

  log: (level, message, metadata, callback) ->
    if typeof metadata == 'function'
      [callback, metadata] = [metadata, {}]

    callback ?= ->
    metadata ?= {}

    # try to capture location of logging call
    if @_captureLocation
      utils.captureLocation message, metadata

    unless metadata.error?
      if message instanceof Error
        metadata.error = message
        message = message.toString()

    super level, message, metadata, callback

  configure: (env, fn) ->
    if typeof env is 'string'
      fn.call @ if env == @_nodeEnv
    else
      @configure k,v for k,v of env

  patchGlobal: ->
    process.on 'uncaughtException', (err) =>
      @log 'error', err, -> process.exit 1

module.exports = Logger
