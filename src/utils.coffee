constructorRegex = /^new /
methodRegex      = /at (.*) \(/
moduleRegex      = /(\w+)\.?(\w+)?:\d/
objectRegex      = /^Object\.(module\.exports\.)?/

exports.captureLocation = (message, metadata) ->
  return if metadata.method or metadata.module

  if message instanceof Error
    stack = error.stack
    line = stack.split('\n')[1]
  else
    error = null
    stack = (new Error()).stack
    line = stack.split('\n')[11]

  method = '<unknown>'
  module = ''

  if match = methodRegex.exec line
    method = match[1].replace objectRegex, ''
    if constructorRegex.test method
      method = method.replace(constructorRegex, '') + '.constructor'

  if match = moduleRegex.exec line
    module = match[1]

  metadata.method = method
  metadata.module = module

exports.pad = pad = (n) ->
  n = n + ''
  if n.length >= 2 then n else new Array(2 - n.length + 1).join('0') + n

exports.timestamp = ->
  d     = new Date()
  year  = d.getUTCFullYear()
  month = pad d.getUTCMonth() + 1
  date  = pad d.getUTCDate()
  hour  = pad d.getUTCHours()
  min   = pad d.getUTCMinutes()
  sec   = pad d.getUTCSeconds()
  "#{year}-#{month}-#{date} #{hour}:#{min}:#{sec}"
