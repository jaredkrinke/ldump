local dump = require("dump")
-- dump.require_path = "dump"
_G.unpack = table.unpack

--- Serialize and deserialize
local pass = function(value)
  return load(dump(value))()
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
    local result = load(dump(t))()
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
    dump.custom_serializers[t] = function(self)
      return "1"
    end
    assert.are_equal(1, pass(t))
    dump.custom_serializers[t] = nil
  end)

  it("custom serializer -- threads", function()
    local thread = coroutine.create(function()
      coroutine.yield()
      return 1
    end)
    dump.custom_serializers[thread] = function(_)
      return "404"
    end
    assert.are_equal(404, pass(thread))
    dump.custom_serializers[thread] = nil
  end)
end)
