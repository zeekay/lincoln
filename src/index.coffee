require('postmortem').install()

Logger  = require './logger'
Console = require './console'

defaultLogger = new Logger()
defaultLogger.add Console, level: 'debug'

defaultLogger.Logger     = Logger
defaultLogger.Console    = Console
defaultLogger.Sentry     = require './sentry'

module.exports = defaultLogger
