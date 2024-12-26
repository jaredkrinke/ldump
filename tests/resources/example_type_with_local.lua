local example_type = {}

local mt = {
  __eq = function(self, other)
    return self.value == other.value
  end,
}

example_type.new = function(value)
  return setmetatable({value = value}, mt)
end

return example_type
