fs      = require 'fs'
winston = require 'winston'

{mapSourcePosition} = require './stacktrace'

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

# at Object.<anonymous> (/Users/zk/play/lincoln/test.js:1:69)
nodeStackRegex   = /\n    at [^(]+ \((.*):(\d+):(\d+)\)/

# at Object.<anonymous> (/Users/zk/play/lincoln/test.js:1:11, <js>:2:9)
coffeeStackRegex = /\n  at [^(]+ \((.*):(\d+):(\d+), <js>/

class Console extends winston.transports.Console
  constructor: (options = {}) ->
    options.colorize  ?= process.stdout.isTTY
    options.timestamp ?= timestamp
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
      message = err.message

    formatted = @formatMessage message, metadata
    super level, formatted, metadata, callback

    return unless err? and err.stack

    match = nodeStackRegex.exec err.stack
    match = coffeeStackRegex.exec err.stack unless match?

    if match? and fs.existsSync match[1]
      position = mapSourcePosition
        source: match[1]
        line:   match[2]
        column: match[3]

      data = fs.readFileSync position.source, 'utf8'
      if line = data.split(/(?:\r\n|\r|\n)/)[position.line - 1]
        console.error position.source + ':' + position.line
        console.error line
        console.error ((new Array(+position.column)).join ' ') + '^'

    console.error err.stack

module.exports = Console
