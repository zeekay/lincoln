Logger = require './lib/logger'

describe 'logger', ->
  it 'should instantiate logger successfully', (done) ->
    logger = new Logger()
