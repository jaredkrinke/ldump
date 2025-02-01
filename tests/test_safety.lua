-- if _VERSION == "Lua 5.1" then return end  -- Lua 5.1 and LuaJIT are not safe

local ldump = require("init")

it("On-load safety", function()
  local malicious_data = string.dump(function()
    print(123)
  end)

  local ok, res
  if _VERSION == "Lua 5.1" and type(jit) ~= "table" then
    local f = function()
      ok, res = pcall(assert(load(malicious_data)))
    end

    local env = ldump.get_safe_env()
    env.pcall = pcall
    env.assert = assert
    setfenv(f, env)

    f()
  else
    ok, res = pcall(assert(load(malicious_data, nil, nil, ldump.get_safe_env())))
  end

  print(res)
  assert.is_false(ok)
end)

it("Data safety", function()
  local malicious_data = ldump(setmetatable({}, {
    __index = function()
      print(123)
    end
  }))

  local deserialized = load(malicious_data, nil, nil, ldump.get_safe_env())()

  local ok, res
  if _VERSION == "Lua 5.1" then
    local f = function()
      ok, res = pcall(function() return deserialized.innocent_looking_field end)
    end

    local env = ldump.get_safe_env()
    env.pcall = pcall
    setfenv(f, env)

    f()
  else
    ok, res = pcall(function() return deserialized.innocent_looking_field end)
  end

  print(res)
  assert.is_false(ok)
end)
