local ldump = require("init")

it("Attempt at isolation of `load`", function()
  local to_serialize = function()
    print(123)
  end

  local safe_env = ldump.get_safe_env()
  local serialized = ldump(to_serialize)

  local deserialized
  if loadstring then
    local f = function()
      deserialized = loadstring(serialized)()
    end
    setfenv(f, safe_env)
    f()
  else
    deserialized = load(serialized, nil, nil, safe_env)()
  end

  local ok = pcall(deserialized)
  assert.is_false(ok)
end)
