lincoln = require '../lib'

testInfo = ->
  lincoln.info 'test'

testError = ->
  lincoln.error (new Error 'eep')

describe 'lincoln', ->
  it 'default logger should log to console', ->
    testInfo()

  it.skip 'default logger should log to console and show stack trace', ->
    testError()
