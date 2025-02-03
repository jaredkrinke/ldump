local ldump = require("init")

local pass = function(value)
  return load(ldump(value))()
end

it("Treating all modules as static", function()
  ldump.deterministic_require = true
  local deterministic = require("tests.resources.deterministic")
  local f = function() return deterministic.some_value end
  local f_copy = pass(f)
  assert.are_equal(f(), f_copy())
  ldump.deterministic_require = false
end)
