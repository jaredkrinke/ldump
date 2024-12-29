local ldump = require("init")
-- ldump.require_path = "ldump"
_G.unpack = table.unpack

--- Serialize and deserialize
local pass = function(value)
  return load(ldump(value))()
end

describe("Serializing primitives:", function()
  local persists = function(value)
    assert.are_same(value, pass(value))
  end

  it("nil", function()
    persists(nil)
  end)

  it("boolean", function()
    persists(true)
  end)

  it("number", function()
    persists(42)
  end)

  it("string", function()
    persists("abc\n")
  end)

  it("function", function()
    local f = function()
      return true
    end

    assert.are_equal(f(), pass(f()))
  end)

  it("table", function()
    persists({a = 1, b = 2})
  end)
end)

describe("Serializing complex cases:", function()
  it("shallow table with strange keys", function()
    local t = {["function"] = 1, ["//"] = 2}
    assert.are_same(t, pass(t))
  end)

  it("embedded tables", function()
    local t = {a = {a = 1}}
    assert.are_same(t, pass(t))
  end)

  it("table with metatable", function()
    local t = setmetatable({value = 1}, {__call = function(self) return self.value end})
    assert.are_equal(1, pass(t)())
  end)

  it("function with upvalues (closure)", function()
    local a = 1
    local b = 2
    local f = function() return a + b end
    assert.are_equal(3, pass(f)())
  end)
end)

describe("Serializing table graphs:", function()
  it("multiple references to the same table", function()
    local o = {}
    local t = {o = o, t = {o = o}}
    local result = pass(t)
    assert.are_same(t, result)
    assert.are_equal(result.t.o, result.o)
  end)

  it("multiple references to the same function", function()
    local f = function() end
    local t = {f = f, t = {}}
    t.t.f = f
    local result = pass(t)
    assert.are_equal(result.t.f, result.f)
  end)

  it("multiple references to the same function with upvalues", function()
    local upvalue = 0
    local f = function() return upvalue end
    local t = {f = f, t = {f = f}}
    local result = pass(t)
    assert.are_equal(result.t.f, result.f)
  end)

  it("circular references", function()
    local t = {a = {}, b = {}}
    t.a.b = t.b
    t.b.a = t.a
    local result = pass(t)
    assert.are_same(t, result)
    assert.are_equal(result.a.b, result.b)
    assert.are_equal(result.b.a, result.a)
  end)

  it("references to itself", function()
    local t = {}
    t.t = t
    local result = pass(t)
    assert.are_same(t, result)
    assert.are_equal(result, result.t)
  end)

  it("tables as keys", function()
    local t = {}
    t[t] = t
    local result = load(ldump(t))()
    -- assert.are_same(t, result)
    -- lol my library works better than busted
    assert.are_equal(result[result], result)
  end)
end)

describe("Overriding serialization:", function()
  it("metatable's __serialize returning string", function()
    local t = setmetatable({}, {__serialize = function(self) return [[1]] end})
    assert.are_equal(1, pass(t))
  end)

  it("metatable's __serialize returning function", function()
    local t = setmetatable({a = 1}, {
      __serialize = function(self)
        local a = self.a
        return function()
          return a
        end
      end
    })

    assert.are_equal(1, pass(t))
  end)

  it("custom serializer", function()
    local t = {value = 1}
    ldump.custom_serializers[t] = "1"
    assert.are_equal(1, pass(t))
    ldump.custom_serializers[t] = nil
  end)

  it("custom serializer -- threads", function()
    local thread = coroutine.create(function()
      coroutine.yield()
      return 1
    end)
    ldump.custom_serializers[thread] = "404"
    assert.are_equal(404, pass(thread))
    ldump.custom_serializers[thread] = nil
  end)

  it("resetting custom_serializers", function()
    local path_1 = "tests.resources.function_with_upvalue"
    local f = require(path_1)
    local _, upvalue = debug.getupvalue(f, 1)

    local path_2 = "tests.resources.empty_table"
    local t = require(path_2)

    ldump.custom_serializers[f] = "1"
    ldump.custom_serializers[upvalue] = "2"
    ldump.custom_serializers[t] = "3"

    assert.are_equal(1, pass(f))
    assert.are_equal(2, pass(upvalue))
    assert.are_equal(3, pass(t))

    ldump.reset_require_cache(path_1)

    assert.are_same(f(), pass(f)())
    assert.are_same(upvalue, pass(upvalue))
    assert.are_equal(3, pass(t))

    ldump.reset_require_cache(path_2)

    assert.are_same(f(), pass(f)())
    assert.are_same(upvalue, pass(upvalue))
    assert.are_same(t, pass(t))
  end)
end)

describe("Error handling:", function()
  describe("excessively big upvalues", function()
    local upvalue = ""
    for _ = 1, 100 do
      upvalue = upvalue .. "AAAAAAAAAAAAAAAAAAAAA"
    end
    -- upvalue is of size 2100, which is exceeds the limit of 2048
    local f = function()
      return upvalue
    end

    it("produce warning by default", function()
      ldump(f)
      assert.are_equal(1, #ldump.get_warnings())
    end)

    it("omit warning if marked with ignore_upvalue_size", function()
      ldump.ignore_upvalue_size(f)
      ldump(f)
      assert.are_equal(0, #ldump.get_warnings())
    end)
  end)

  it("wrong serializer return type always causes an error", function()
    local t = setmetatable({}, {__serialize = function(self)
      return 42
    end})

    local ok, result = pcall(ldump --[[ @as function ]], t)

    assert.is_false(ok)
  end)

  describe("unsupported type", function()
    local c = coroutine.create(function() end)

    it("causes an error in strict mode", function()
      local success = pcall(ldump --[[ @as function ]], c)
      assert.is_false(success)
    end)

    it("writes a warning in non-strict mode", function()
      ldump.strict_mode = false
      ldump(c)
      assert.are_equal(1, #ldump.get_warnings())
      ldump.strict_mode = true
    end)
  end)
end)

it("handles _ENV upvalue correctly", function()
  local f = require("tests.resources.function_with_env_upvalue")
  local g = pass(f)

  local env, value = f()
  local copy_env, copy_value = g()

  assert.are_same(env, copy_env)
  assert.are_equal(value, copy_value)
end)
