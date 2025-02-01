local ldump = require("init")

it("On-load safety", function()
  local malicious_data = string.dump(function()
    print(123)
  end)

  local ok, res = pcall(assert(load(malicious_data, nil, nil, ldump.get_safe_env())))
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
  local ok, res = pcall(function() return deserialized.innocent_looking_field end)
  print(res)
  assert.is_false(ok)
end)
