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
  cache = {}

  for _frame in stack
    # wrap each frame using source-map-support
    frame = Object.create wrapFrame err, stack, _frame

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
    frame.toJSON   = utils.toJSON
    frame

module.exports =
  install: ->
    Error.prepareStackTrace = (err, stack) ->
      # sentry expects structuredStackTrace
      err.structuredStackTrace = frames = structuredStackTrace err, stack
      err + (frames.map (frame) -> '\n    at ' + frame).join ''

  mapEvalOrigin:        mapEvalOrigin
  mapSourcePosition:    mapSourcePosition
  structuredStackTrace: structuredStackTrace
  wrapFrame:            wrapFrame
