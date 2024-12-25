return {
  table = {},
  coroutine = coroutine.create(function()
    local i = 0
    while true do
      i = i + 1
      coroutine.yield(i)
    end
  end),
}
