exports.toJSON = ->
  result = {}
  Object.keys(@).forEach (key) =>
    val = @[key]
    if key is 'toJSON'
      return
    else if key is 'this'
      result[key] = '' + val
    else if typeof val is 'function'
      result[key] = '' + val
    else
      result[key] = @[key]
  result
