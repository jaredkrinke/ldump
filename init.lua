unpack = unpack or table.unpack
local warnings, allowed_big_upvalues, stack, build_table, handle_primitive, mark_as_static

-- API --

local ldump_mt = {}

--- Serialization library, can be called directly.
--- Serialize given value to a string, that can be deserialized via `load`.
--- @overload fun(value: any): string
local ldump = setmetatable({}, ldump_mt)

--- @alias deserializer string | fun(): any

--- Custom serialization functions for the exact objects. 
---
--- Key is the value that can be serialized, value is a deserializer in form of `load`-compatible
--- string or function. Takes priority over `__serialize`.
--- @type table<any, deserializer>
ldump.custom_serializers = {}

--- Loads the given module, returns any value returned by the given module (`true` when `nil`).
--- 
--- Additionally, marks all data inside to be deserialized by requiring the module.
--- @param modname string
ldump.require = function(modname)
  local is_currently_loaded = package.loaded[modname]
  local result = require(modname)
  if not is_currently_loaded then
    mark_as_static(result, modname, {})
  end
  return result
end

--- Get the list of warnings from the last ldump call.
---
--- See `ldump.strict_mode`.
--- @return string[]
ldump.get_warnings = function() return {unpack(warnings)} end

--- Mark function, causing dump to stop producing upvalue size warnings.
---
--- Upvalues can cause large modules to be serialized implicitly. Warnings allow to track that.
--- @generic T: function
--- @param f T
--- @return T # returns the same function
ldump.ignore_upvalue_size = function(f)
  allowed_big_upvalues[f] = true
  return f
end

--- If true (by default), `ldump` treats unserializable data as an error, if false produces a
--- warning.
--- @type boolean
ldump.strict_mode = true

--- `require`-style path to the ldump module, used in deserialization.
---
--- Inferred from requiring the ldump itself, can be changed.
--- @type string
ldump.require_path = select(1, ...)

ldump_mt.__call = function(self, x)
  assert(
    self.require_path,
    "Put the lua path to ldump libary into ldump.require_path before calling ldump itself"
  )

  stack = {}
  warnings = {}
  local cache = {size = 0}
  local result = "return " .. handle_primitive(x, cache)

  return ("local cache = {}\nlocal ldump = require(\"%s\")\n"):format(self.require_path) .. result
end


-- internal implementation --

allowed_big_upvalues = {}

local to_expression = function(statement)
  return ("(function()\n%s\nend)()"):format(statement)
end

build_table = function(x, cache)
  local mt = getmetatable(x)

  cache.size = cache.size + 1
  cache[x] = cache.size

  local result = {}
  result[1] = "local _ = {}"
  result[2] = ("cache[%s] = _"):format(cache.size)

  for k, v in pairs(x) do
    table.insert(stack, tostring(k))
    table.insert(result, ("_[%s] = %s"):format(
      handle_primitive(k, cache),
      handle_primitive(v, cache)
    ))
    table.remove(stack)
  end

  if not mt then
    table.insert(result, "return _")
  else
    table.insert(result, ("return setmetatable(_, %s)"):format(handle_primitive(mt, cache)))
  end

  return table.concat(result, "\n")
end

local build_function = function(x, cache)
  cache.size = cache.size + 1
  cache[x] = cache.size

  local result = {}

  local ok, res = pcall(string.dump, x)

  if not ok then
    error((
      "Function %s is not `string.dump`-compatible; if it uses coroutines, use " ..
      "`ldump.custom_serializers`"
    ):format(table.concat(stack, ".")))
  end

  result[1] = "local _ = " .. ([[load(%q)]]):format(res)
  result[2] = ("cache[%s] = _"):format(cache.size)

  if allowed_big_upvalues[x] then
    result[3] = "ldump.ignore_upvalue_size(_)"
  end

  for i = 1, math.huge do
    local k, v = debug.getupvalue(x, i)
    if not k then break end

    table.insert(stack, ("<upvalue %s>"):format(k))
    local upvalue
    if k == "_ENV" then
      upvalue = "_ENV"
    else
      upvalue = handle_primitive(v, cache)
    end
    table.remove(stack)

    if not allowed_big_upvalues[x] and #upvalue > 2048 then
      table.insert(warnings, ("Big upvalue %s in %s"):format(k, table.concat(stack, ".")))
    end
    table.insert(result, ("debug.setupvalue(_, %s, %s)"):format(i, upvalue))
  end
  table.insert(result, "return _")
  return table.concat(result, "\n")
end

local primitives = {
  number = function(x)
    return tostring(x)
  end,
  string = function(x)
    return string.format("%q", x)
  end,
  ["function"] = function(x, cache)
    return to_expression(build_function(x, cache))
  end,
  table = function(x, cache)
    return to_expression(build_table(x, cache))
  end,
  ["nil"] = function()
    return "nil"
  end,
  boolean = function(x)
    return tostring(x)
  end,
}

handle_primitive = function(x, cache)
  do  -- handle custom serializers
    local mt = getmetatable(x)
    local deserializer = ldump.custom_serializers[x] or mt and mt.__serialize and mt.__serialize(x)

    if deserializer then
      local deserializer_type = type(deserializer)

      if deserializer_type == "string" then
        return deserializer
      end

      if deserializer_type == "function" then
        allowed_big_upvalues[deserializer] = true
        return ("%s()"):format(handle_primitive(deserializer, cache))
      end

      local which_serializer = ldump.custom_serializers[x]
        and "ldump.custom_serializers[x]"
        or "getmetatable(x).__serialize"

      error(("%s returned type %s for %s; serializers should return string or function")
        :format(which_serializer, deserializer_type, table.concat(stack, ".")))
    end
  end

  local xtype = type(x)
  if not primitives[xtype] then
    local message = (
      "ldump does not support serializing type %q of %s; use `__serialize` metamethod or " ..
      "`ldump.custom_serializers` to define serialization"
    ):format(xtype, table.concat(stack, "."))

    if ldump.strict_mode then
      error(message)
    end

    table.insert(warnings, message)
    return "nil"
  end

  if xtype == "table" or xtype == "function" then
    local cache_i = cache[x]
    if cache_i then
      return ("cache[%s]"):format(cache_i)
    end
  end

  return primitives[xtype](x, cache)
end

local reference_types = {
  string = true,
  ["function"] = true,
  userdata = true,
  thread = true,
  table = true,
}

mark_as_static = function(value, module_path, key_path)
  local value_type = type(value)
  if not reference_types[value_type] then return end

  do
    local key_path_copy = {unpack(key_path)}
    local ldump_require_path = ldump.require_path

    ldump.custom_serializers[value] = function()
      local result = require(ldump_require_path).require(module_path)
      for _, key in ipairs(key_path_copy) do
        result = result[key]
      end
      return result
    end
  end

  if value_type ~= "table" then return end

  for k, v in pairs(value) do
    table.insert(key_path, k)
    mark_as_static(v, module_path, key_path)
    table.remove(key_path)
  end
end


return ldump
