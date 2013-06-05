fs        = require 'fs'
sourceMap = require 'source-map-support'
winston   = require 'winston'
settings  = require './settings'

class Console extends winston.transports.Console
  _cache: {}

  constructor: (options) ->
    options.colorize  = process.stdout.isTTY
    options.timestamp = => @_timestamp()
    super options

  _padZero: (n) ->
    n = n + ''
    if n.length >= 2 then n else new Array(2 - n.length + 1).join('0') + n

  _timestamp: ->
    d     = new Date()
    year  = d.getUTCFullYear()
    month = @_padZero d.getUTCMonth() + 1
    date  = @_padZero d.getUTCDate()
    hour  = @_padZero d.getUTCHours()
    min   = @_padZero d.getUTCMinutes()
    sec   = @_padZero d.getUTCSeconds()
    "#{year}-#{month}-#{date} #{hour}:#{min}:#{sec}"

  _formatMessage: (level, message, method, module) ->
    padding = ''

    if (distance = longestLevel - level.length) > 0
      for i in [1..distance]
        padding += ' '

    if process.stdout.isTTY
      "#{padding}\x1B[90m[#{module} #{method}]\x1B[39m #{message}"
    else
      "#{padding}[#{module} #{method}] #{message}"

  log: (level, message, metadata, callback) ->
    if typeof metadata == 'function'
      [callback, metadata] = [metadata, {}]

    callback  ?= ->
    metadata  ?= {}

    err       = null

    method    = metadata._method
    module    = metadata._module
    formatted = @_formatMessage level, message, method, module

    delete metadata._method
    delete metadata._module

    if message instanceof Error
      [err, message] = [message, message.toString().replace /^Error: /, '']

    unless err?
      return super level, formatted, metadata, callback

    unless err.stack
      console.error 'Uncaught exception:', err
      return super level, formatted, metadata, callback

    unless match = /\n    at [^(]+ \((.*):(\d+):(\d+)\)/.exec err.stack
      return super level, formatted, metadata, callback

    position = mapSourcePosition @_cache,
      source: match[1]
      line:   match[2]
      column: match[3]

    done = =>
      metadata._method = method
      metadata._module = module
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

class Sentry extends winston.Transport
  constructor: (options) ->
    @name = 'sentry'
    @level = options.level ? 'info'

    @_versionApp   = settings.version
    @_versionNode  = process.version
    @_versionOs    = 'v' + require('os').release()

    Error.prepareStackTrace = null
    @_client = new (require('raven').Client) options.dsn

    @_client.on 'error', (err) -> console.error err

  log: (level, message, metadata, callback) ->
    if typeof metadata == 'function'
      [callback, metadata] = [metadata, {}]

    callback ?= ->
    metadata ?= {}

    tags =
      version_app:   @_versionApp
      version_node:  @_versionNode
      version_os:    @_versionOs
      module:        metadata._module

    if message instanceof Error
      @_client.captureError message, {tags: tags}
    else
      @_client.captureMessage message, {tags: tags}

    @_client.once 'logged', -> callback null, true

require('source-map-support').install handleUncaughtExceptions: false

logger = new winston.Logger
  exitOnError: false
  transports: []
  colors:
    debug: 'blue'
    info:  'green'
    warn:  'yellow'
    error: 'red'
  levels:
    debug: 0
    info:  1
    warn:  2
    error: 3

constructorRegex = /^new /
methodRegex      = /at (.*) \(/
objectRegex      = /^Object\.(module\.exports\.)?/
moduleRegex      = /(\w+)\.?(\w+)?:\d/
longestLevel     = Math.max.apply Math, (Object.keys(logger.levels).map (key) -> key.length)

log = (level, message, metadata, callback) ->
  if typeof metadata == 'function'
    [callback, metadata] = [metadata, {}]

  callback ?= ->
  metadata ?= {}

  line = (new Error()).stack.split('\n')[3]
  module = (moduleRegex.exec line)[1]
  method = (methodRegex.exec line)[1].replace objectRegex, ''

  if constructorRegex.test methodRegex
    method = method.replace(constructorRegex, '') + '.constructor'
    method = method.replace /^new /

  metadata._method = method
  metadata._module = module

  logger.log.call logger, level, message, metadata, callback

wrapper = ->
  log.apply null, arguments

for level in ['debug', 'info', 'warn', 'error']
  do (level) ->
    wrapper[level] = ->
      args = Array::slice.call arguments, 0
      args.unshift level
      log.apply null, args

switch process.env.NODE_ENV
  when 'production'
    logger.add Console,
      level: 'info'
    logger.add Sentry,
      level: 'warn'
      dsn: settings.sentry.production

  when 'staging'
    logger.add Console,
      level: 'debug'
    logger.add Sentry,
      level: 'warn'
      dsn: settings.sentry.staging

  when 'test'
    logger.add Console,
      level: 'warn'

  else
    logger.add Console,
      level: 'debug'

module.exports = wrapper
