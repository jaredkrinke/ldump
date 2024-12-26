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

it("Allowing `==` validity preservation by marking metatable as static", function()
  local example_type = ldump.require("tests.resources.example_type")
  local a = example_type.new(1)
  local b = example_type.new(1)

  assert.are_equal(a, b)
  assert.are_equal(a, pass(b))
  assert.are_equal(pass(a), pass(b))

  -- lua5.1 requires metatable equality for object equality
  assert.are_equal(getmetatable(a), getmetatable(pass(a)))
end)

it("Allowing `==` validity preservation by marking upvalue metatable as static", function()
  local example_type = ldump.require("tests.resources.example_type_with_local")
  local a = example_type.new(1)
  local b = example_type.new(1)

  assert.are_equal(a, b)
  assert.are_equal(a, pass(b))
  assert.are_equal(pass(a), pass(b))
  assert.are_equal(getmetatable(a), getmetatable(pass(a)))
end)

it("Handling reference-type keys", function()
  local path = "tests.resources.table_keys_invalid"
  package.loaded[path] = nil
  local ok, message = pcall(ldump.require, path)
  assert.is_false(ok)

  local _, j = message:find("\n\nKeys in: ")
  message = message:sub(j + 1)
  assert.are_equal("., a.b", message)

  ldump.modules_with_reference_keys[path] = true
  package.loaded[path] = nil
  local module = ldump.require(path)
  assert.are_equal(module, pass(module))

  path = "tests.resources.table_keys_valid"
  package.loaded[path] = nil
  local valid_module = ldump.require(path)
  assert.are_equal(valid_module, pass(valid_module))
end)
