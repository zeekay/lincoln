lincoln = require '../lib'

describe 'lincoln', ->
  it 'default logger should log to console', ->
    lincoln.info 'test'
