winston = require 'winston'
path    = require 'path'

{mapSourcePosition} = require 'source-map-support'

mapEvalOrigin = (cache, origin) ->
  # Most eval() calls are in this format
  match = /^eval at ([^(]+) \((.+):(\d+):(\d+)\)$/.exec(origin)
  if match
    position = mapSourcePosition cache,
      source: match[2]
      line: match[3]
      column: match[4]

    return 'eval at ' + match[1] + ' (' + position.source + ':' + position.line + ':' + position.column + ')'

  # Parse nested eval() calls using recursion
  if match = /^eval at ([^(]+) \((.+)\)$/.exec(origin)
    return 'eval at ' + match[1] + ' (' + mapEvalOrigin(cache, match[2]) + ')'

  # Make sure we still return useful information if we didn't find anything
  origin

wrapFrame = (cache, frame) ->
  # Most call sites will return the source file from getFileName(), but code
  # passed to eval() ending in "//@ sourceURL=..." will return the source file
  # from getScriptNameOrSourceURL() instead
  source = frame.getFileName() or frame.getScriptNameOrSourceURL()

  if source
    position = mapSourcePosition cache,
      source: source
      line: frame.getLineNumber()
      column: frame.getColumnNumber()

    return _frame =
      __proto__: frame
      getFileName: ->
        position.source
      getLineNumber: ->
        position.line
      getColumnNumber: ->
        position.column
      getScriptNameOrSourceURL: ->
        position.source

  # Code called using eval() needs special handling
  origin = frame.isEval() and frame.getEvalOrigin()
  if origin
    origin = mapEvalOrigin cache, origin
    return _frame =
      __proto__: frame
      getEvalOrigin: ->
        origin

  # If we get here then we were unable to change the source position
  frame

structuredStackTrace = (stack) ->
  cache = {}

  for _frame in stack
    frame = Object.create wrapFrame cache, _frame

    frame['this']  = frame.getThis()
    frame.type     = frame.getTypeName()
    frame.isTop    = frame.isToplevel()
    frame.isEval   = frame.isEval()
    frame.origin   = frame.getEvalOrigin()
    frame.script   = frame.getScriptNameOrSourceURL()
    frame.fun      = frame.getFunction()
    frame.name     = frame.getFunctionName()
    frame.method   = frame.getMethodName()
    frame.path     = frame.getFileName()
    frame.line     = frame.getLineNumber()
    frame.col      = frame.getColumnNumber()
    frame.isNative = frame.isNative()
    frame.pos      = frame.getPosition()
    frame.isCtor   = frame.isConstructor()
    frame.file     = path.basename frame.path
    frame.toJSON   = toJSON
    frame

toJSON = ->
  result = {}
  Object.keys(@).forEach (key) =>
    val = @[key]
    if key is 'toJSON'
      return
    else if key is 'this'
      result[key] = '' + val
    else if typeof val is 'function'
      result[key] = '' + val
    else
      result[key] = @[key]
  result

class Sentry extends winston.Transport
  constructor: (options) ->
    @name   = 'sentry'
    @level  = options.level ? 'info'

    @_loggerName  = options.logger ? 'root'
    @_versionApp  = options.appVersion
    @_versionNode = process.version
    @_versionOs   = 'v' + require('os').release()

    # needs to be null for traceback (dep of raw-trackback dep of raven)
    Error.prepareStackTrace = null
    {Client} = require 'raven'

    # monkey patch process/send so that we can massage kwargs sent back to sentry
    Client::_process = Client::process
    Client::_send    = Client::send

    Client::send = (kwargs) -> # noop
    Client::process = (kwargs) ->
      ret = @_process kwargs

      # try to get set culprit to module + function/method throwing error
      kwargs.culprit = "#{kwargs.module}.#{kwargs.method}"

      @_send kwargs
      ret

    @_client = new Client options.dsn
    @_client.on 'error', (err) -> console.error err

    Error.prepareStackTrace = (err, stack) ->
      err.structuredStackTrace = frames = structuredStackTrace stack
      err + (frames.map (frame) -> '\n    at ' + frame).join ''

  log: (level, message, metadata, callback) ->
    if typeof metadata == 'function'
      [callback, metadata] = [metadata, {}]

    callback ?= ->
    metadata ?= {}

    kwargs =
      extra: metadata
      level: level
      logger: @_loggerName
      tags:
        version_app:   @_versionApp
        version_node:  @_versionNode
        version_os:    @_versionOs
      module:          metadata._module
      method:          metadata._method

    if (err = metadata._error)?
      @_client.captureError err, kwargs
    else
      @_client.captureMessage message, kwargs

    @_client.once 'logged', -> callback null, true

module.exports = Sentry
