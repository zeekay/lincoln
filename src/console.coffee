fs        = require 'fs'
sourceMap = require 'source-map-support'
winston   = require 'winston'

pad: (n) ->
  n = n + ''
  if n.length >= 2 then n else new Array(2 - n.length + 1).join('0') + n

timestamp: ->
  d     = new Date()
  year  = d.getUTCFullYear()
  month = pad d.getUTCMonth() + 1
  date  = pad d.getUTCDate()
  hour  = pad d.getUTCHours()
  min   = pad d.getUTCMinutes()
  sec   = pad d.getUTCSeconds()
  "#{year}-#{month}-#{date} #{hour}:#{min}:#{sec}"

_cache = {}

class Console extends winston.transports.Console
  constructor: (options = {}) ->
    options.colorize  ?= process.stdout.isTTY
    options.timestamp ?= timestamp
    super options

  formatMessage: (message) ->
    if @colorize
      "\x1B[90m[#{message.module} #{message.method}]\x1B[39m #{message}"
    else
      "[#{message.module} #{message.method}] #{message}"

  log: (level, message, metadata, callback) ->
    if typeof metadata == 'function'
      [callback, metadata] = [metadata, {}]

    callback  ?= ->
    metadata  ?= {}
    err       = null
    formatted = @formatMessage message

    if message instanceof Error
      [err, message] = [message, message.toString().replace /^Error: /, '']

    unless err?
      return super level, formatted, metadata, callback

    unless err.stack
      console.error 'Uncaught exception:', err
      return super level, formatted, metadata, callback

    unless match = /\n    at [^(]+ \((.*):(\d+):(\d+)\)/.exec err.stack
      return super level, formatted, metadata, callback

    position = sourceMap.mapSourcePosition _cache,
      source: match[1]
      line:   match[2]
      column: match[3]

    done = =>
      console.error err.stack
      Console::log.call @, level, message, metadata, callback

    fs.exists position.source, (exists) ->
      unless exists
        return done()

      fs.readFile position.source, 'utf8', (err, data) ->
        return done() if err?

        line = data.split(/(?:\r\n|\r|\n)/)[position.line - 1]

        if line
          console.error position.source + ':' + position.line
          console.error line
          console.error ((new Array(+position.column)).join ' ') + '^'

        done()

module.exports = Console
