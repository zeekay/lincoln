postmortem = require 'postmortem'
winston    = require 'winston'
utils      = require './utils'


class Console extends winston.transports.Console
  constructor: (options = {}) ->
    options.colorize  ?= process.stdout.isTTY
    options.timestamp ?= utils.timestamp
    super options

  _formatMessage: (message, metadata) ->
    unless (metadata.module and metadata.method)
      return message

    prefix = "[#{metadata.module}.#{metadata.method}]"

    # remove from metadata object
    delete metadata.module
    delete metadata.method

    if @colorize
      "\x1B[90m#{prefix}\x1B[39m #{message}"
    else
      "#{prefix} #{message}"

  log: (level, message, metadata, callback) ->
    if typeof metadata == 'function'
      [callback, metadata] = [metadata, {}]

    callback ?= ->
    metadata ?= {}

    formatted = @_formatMessage message, metadata

    super level, formatted, metadata, callback

    if metadata.error? and metadata.error.stack
      postmortem.prettyPrint metadata.error, colorize: @colorize

module.exports = Console
