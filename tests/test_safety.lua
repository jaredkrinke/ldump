if loadstring then return end  -- ignores lua5.1

local ldump = require("init")

it("Attempt at isolation of `load`", function()
  local to_serialize = function()
    print(123)
  end

  local safe_env = 

  local serialized = ldump(to_serialize)
  local deserialized = load(serialized, nil, nil, safe_env)()
  local ok = pcall(deserialized)
  assert.is_false(ok)
end)
