postmortem = require 'postmortem'
winston    = require 'winston'

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

    # reinstall our postmortem
    postmortem.install()

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
