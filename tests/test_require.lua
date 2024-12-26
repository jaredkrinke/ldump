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

it("Keeping the actual reference through multiple sessions", function()
  local path = "tests.resources.example_module"
  local example_module_1 = ldump.require(path)
  local serialized = ldump(example_module_1)

  -- emulate new session
  package.loaded[path] = nil
  local example_module_2 = ldump.require(path)
  local copy_2 = load(serialized)()

  assert.are_equal(example_module_2, copy_2)
  assert.are_not_equal(example_module_1, copy_2)
end)

it("Keeping the actual reference through multiple serializations", function()
  local example_module = ldump.require("tests.resources.example_module")
  local copy = pass(pass(example_module))
  assert.are_equal(example_module, copy)
end)

-- TODO saving metatables

it("Handling reference-type keys", function()
  local path = "tests.resources.table_keys_invalid"
  package.loaded[path] = nil
  local success = pcall(ldump.require, path)
  assert.is_false(success)

  ldump.modules_with_reference_keys[path] = true
  package.loaded[path] = nil
  local module = ldump.require(path)
  assert.are_equal(module, pass(module))

  path = "tests.resources.table_keys_valid"
  package.loaded[path] = nil
  local valid_module = ldump.require(path)
  assert.are_equal(valid_module, pass(valid_module))
end)
