local upvalue = {
  [{}] = true,
}

return {
  f = function()
    return upvalue
  end,
}
