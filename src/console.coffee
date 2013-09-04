postmortem = require 'postmortem'
winston    = require 'winston'
utils      = require './utils'

pad = (n) ->
  n = n + ''
  if n.length >= 2 then n else new Array(2 - n.length + 1).join('0') + n

timestamp = ->
  d     = new Date()
  year  = d.getUTCFullYear()
  month = pad d.getUTCMonth() + 1
  date  = pad d.getUTCDate()
  hour  = pad d.getUTCHours()
  min   = pad d.getUTCMinutes()
  sec   = pad d.getUTCSeconds()
  "#{year}-#{month}-#{date} #{hour}:#{min}:#{sec}"

class Console extends winston.transports.Console
  constructor: (options = {}) ->
    options.colorize  ?= process.stdout.isTTY
    options.timestamp ?= timestamp
    @_captureLocation  = options.captureLocation ? true

    postmortem.install()

    super options

  _formatMessage: (message, metadata, prefix='') ->
    if metadata.module and metadata.method
      prefix = "[#{metadata.module}.#{metadata.method}]"
    else
      return message

    if @colorize
      "\x1B[90m#{prefix}\x1B[39m #{message}"
    else
      "#{prefix} #{message}"

  log: (level, message, metadata, callback) ->
    if typeof metadata == 'function'
      [callback, metadata] = [metadata, {}]

    callback ?= ->
    metadata ?= {}

    utils.captureLocation message, metadata
    formatted = @_formatMessage message, metadata

    super level, formatted, metadata, callback

    if metadata.error? and metadata.error.stack
      postmortem.prettyPrint metadata.error, colorize: @colorize

module.exports = Console
