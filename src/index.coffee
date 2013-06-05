Console = require './console'
Logger  = require './logger'
Sentry  = require './sentry'

logger = new Logger
logger.add Console, level: 'debug'

logger.Console = Console
logger.Logger  = Logger
logger.Sentry  = Sentry

module.exports = logger
