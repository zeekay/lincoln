winston = require 'winston'

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

module.exports = Sentry
