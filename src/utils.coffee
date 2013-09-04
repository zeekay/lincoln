constructorRegex = /^new /
methodRegex      = /at (.*) \(/
moduleRegex      = /(\w+)\.?(\w+)?:\d/
objectRegex      = /^Object\.(module\.exports\.)?/

exports.captureLocation = (message, metadata) ->
  return if metadata.method or metadata.module

  if message instanceof Error
    console.log 'instance'
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
