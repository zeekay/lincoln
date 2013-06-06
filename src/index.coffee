Error._originalPrepareStackTrace = Error.prepareStackTrace

Logger  = require './logger'
Console = require './console'

defaultLogger = new Logger()
defaultLogger.add Console, level: 'debug'

defaultLogger.Logger     = Logger
defaultLogger.Console    = Console
defaultLogger.Sentry     = require './sentry'
defaultLogger.stacktrace = require './stacktrace'

module.exports = defaultLogger
