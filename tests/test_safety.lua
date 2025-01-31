if loadstring then return end  -- ignores lua5.1

local ldump = require("init")

it("Attempt at isolation of `load`", function()
  local to_serialize = function()
    print(123)
  end

  local safe_env = {
    require = require,
    load = load,
    debug = {
      setupvalue = debug.setupvalue,
      upvaluejoin = debug.upvaluejoin,
    },
    setmetatable = setmetatable,
  }

  local serialized = ldump(to_serialize)
  local deserialized = load(serialized, nil, nil, safe_env)()
  local ok = pcall(deserialized)
  assert.is_false(ok)
end)
