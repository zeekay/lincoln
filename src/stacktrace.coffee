path      = require 'path'
sourceMap = require 'source-map-support'
utils     = require './utils'

cache            = {}
coffeePrepare    = Error._originalPrepareStackTrace
coffeeDetected   = typeof coffeePrepare is 'function'
coffeeStackRegex = /\n  at [^(]+ \((.*):(\d+):(\d+), <js>/

mapSourcePosition = (frame) ->
  sourceMap.mapSourcePosition cache, frame

mapEvalOrigin = (origin) ->
  # Most eval() calls are in this format
  match = /^eval at ([^(]+) \((.+):(\d+):(\d+)\)$/.exec(origin)
  if match
    position = mapSourcePosition
      source: match[2]
      line: match[3]
      column: match[4]

    return 'eval at ' + match[1] + ' (' + position.source + ':' + position.line + ':' + position.column + ')'

  # Parse nested eval() calls using recursion
  if match = /^eval at ([^(]+) \((.+)\)$/.exec(origin)
    return 'eval at ' + match[1] + ' (' + (mapEvalOrigin match[2]) + ')'

  # Make sure we still return useful information if we didn't find anything
  origin

wrapFrame = (err, stack, frame) ->
  # If using coffee 1.6.2+ executable we can derive source, line, and column
  # from it's prepareStackTrace function
  if coffeeDetected and match = coffeeStackRegex.exec coffeePrepare err, [frame]
    return _frame =
      __proto__: frame
      getFileName: ->
        match[1]
      getLineNumber: ->
        match[2]
      getColumnNumber: ->
        match[3] - 1
      getScriptNameOrSourceURL: ->
        match[1]

  # Most call sites will return the source file from getFileName(), but code
  # passed to eval() ending in "//@ sourceURL=..." will return the source file
  # from getScriptNameOrSourceURL() instead
  source = frame.getFileName() or frame.getScriptNameOrSourceURL()

  if source
    position = mapSourcePosition
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
    origin = mapEvalOrigin origin
    return _frame =
      __proto__: frame
      getEvalOrigin: ->
        origin

  # If we get here then we were unable to change the source position
  frame

structuredStackTrace = (err, stack) ->
  for frame in stack
    _frame = Object.create {}, frame

    _frame['this']  = frame.getThis()
    _frame.type     = frame.getTypeName()
    _frame.isTop    = frame.isToplevel()
    _frame.isEval   = frame.isEval()
    _frame.origin   = frame.getEvalOrigin()
    _frame.script   = frame.getScriptNameOrSourceURL()
    _frame.fun      = frame.getFunction()
    _frame.name     = frame.getFunctionName()
    _frame.method   = frame.getMethodName()
    _frame.path     = frame.getFileName()
    _frame.line     = frame.getLineNumber()
    _frame.col      = frame.getColumnNumber()
    _frame.isNative = frame.isNative()
    _frame.pos      = frame.getPosition()
    _frame.isCtor   = frame.isConstructor()
    _frame.file     = path.basename frame.path
    _frame.toJSON   = utils.toJSON
    _frame

module.exports =
  install: ->
    Error.prepareStackTrace = (err, stack) ->
      # rewrite callsites with source map info when possible
      stack = for frame in stack
        wrapFrame err, stack, frame
      # sentry expects structuredStackTrace
      err.structuredStackTrace = structuredStackTrace err, stack
      # return formatted stacktrace
      err + (stack.map (frame) -> '\n    at ' + frame).join ''

  mapEvalOrigin:        mapEvalOrigin
  mapSourcePosition:    mapSourcePosition
  structuredStackTrace: structuredStackTrace
  wrapFrame:            wrapFrame
