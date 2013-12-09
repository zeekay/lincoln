winston = require 'winston'


getClient = do ->
  Client = null  # cached Client constructor

  ->
    return Client if Client?  # reuse cached Client if possible

    # save reference to current prepareStackTrace
    prepareStackTrace = Error.prepareStackTrace
    # prepareStackTrace needs to be null for traceback (dep of raw-trackback dep of raven)
    Error.prepareStackTrace = null

    # require raven
    {Client} = require 'raven'

    # set back proper prepareStackTrace
    Error.prepareStackTrace = prepareStackTrace

    # monkey patch process/send so that we can massage kwargs sent back to sentry
    Client::_process = Client::process
    Client::_send    = Client::send

    Client::send = (kwargs) -> # noop
    Client::process = (kwargs) ->
      # get return of real process
      ret = @_process kwargs

      # try to get set culprit to module + function/method throwing error
      if kwargs.module? and kargs.method?
        kwargs.culprit = "#{kwargs.module}.#{kwargs.method}"

      # send to sentry
      @_send kwargs
      ret

    # return our bastardized client
    Client


class Sentry extends winston.Transport
  constructor: (options) ->
    @name             = 'sentry'
    @level            = options.level ? 'info'
    @_loggerName      = options.logger ? 'root'
    @_versionApp      = options.appVersion
    @_versionNode     = process.version
    @_versionOs       = 'v' + require('os').release()

    Client = getClient()

    unless options.dsn?
      throw new Error 'Sentry DSN must be declared'

    @_client = new Client options.dsn
    @_client.on 'error', (err) ->
      console.error err

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

    if metadata.module? and metadata.method?
      kwargs.module = metadata.module
      kwargs.method = metadata.method

    if level == 'error'
      @_client.captureError message, kwargs
    else
      @_client.captureMessage message, kwargs

    @_client.once 'logged', ->
      callback null, true

module.exports = Sentry
