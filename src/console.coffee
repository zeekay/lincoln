postmortem = require 'postmortem'
winston    = require 'winston'

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

    postmortem.install()

    super options

  formatMessage: (message, metadata) ->
    if @colorize
      "\x1B[90m[#{metadata._module}.#{metadata._method}]\x1B[39m #{message}"
    else
      "[#{metadata._module}.#{metadata._method}] #{message}"

  log: (level, message, metadata, callback) ->
    if typeof metadata == 'function'
      [callback, metadata] = [metadata, {}]

    callback  ?= ->
    metadata  ?= {}
    err       = metadata._error

    if err?
      message = err.toString()

    formatted = @formatMessage message, metadata
    super level, formatted, metadata, callback

    return unless err? and err.stack

    postmortem.prettyPrint err, colorize: @colorize

module.exports = Console
