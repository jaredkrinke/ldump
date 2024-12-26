local example_type = {}

example_type.mt = {
  __eq = function(self, other)
    return self.value == other.value
  end,
}

example_type.new = function(value)
  return setmetatable({value = value}, example_type.mt)
end

return example_type
