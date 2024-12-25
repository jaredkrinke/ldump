_G.unpack = unpack or table.unpack
local ldump = require("init")

local pass = function(x)
  return load(ldump(x))()
end

it("Basic usage", function()
  local example_module = ldump.require("tests.resources.example_module")
  assert.are_equal(example_module, pass(example_module))
  assert.are_equal(example_module.table, pass(example_module.table))
  assert.are_equal(example_module.coroutine, pass(example_module.coroutine))
end)

-- TODO keeping == through multiple sessions
-- TODO serializing/deserializing 2 times
