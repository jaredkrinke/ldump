# ldump — serializer for any lua type

`ldump` is a flexible serializer, able to serialize any data, starting with circular references, tables as keys, functions with upvalues, metatables and ending with coroutines, threads and userdata (by defining how they should be serialized). It outputs valid Lua code that recreates the original object, doing the deserialization through `load(data)()`. It aims for functionality and flexibility instead of speed and size, allowing full serialization of complex data, such as video game saves. The output is large, but can be drastically reduced with modern compression algorithms.

Inspired by [`Ser`](https://github.com/gvx/Ser). Supports Lua 5.1, 5.2, 5.3, 5.4 and LuaJIT. Tested for edge cases, such as joined upvalues and _ENV redefinition.

| Type                         | Support      |
| ---------------------------- | ------------ |
| nil, boolean, number, string | full         |
| function                     | full         |
| userdata                     | user-defined |
| thread                       | user-defined |
| table                        | full         |
| metatables[*](#plans)        | full         |


## TL;DR show me the code

```lua
local ldump = require("ldump")

local upvalue = 42
local world = {
  name = "New world",
  get_answer = function() return upvalue end,
}

local serialized_data = ldump(world)  -- serialize to a string
local loaded_world = load(serialized_data)()  -- deserialize the string
```

See as a test at [/tests/test_use_case.lua:3](/tests/test_use_case.lua#L3)


## The full power of ldump

```lua
local ldump = require("ldump")

-- basic tables
local game_state = {
  player = {name = "Player"},
  boss = {name = "Boss"},
}

-- circular references & tables as keys
game_state.deleted_entities = {
  [game_state.boss] = true,
}

-- functions even with upvalues
local upvalue = 42
game_state.get_answer = function() return upvalue end

-- fundamentally non-serializable types if overriden
local create_coroutine = function()
  return coroutine.wrap(function()
    coroutine.yield(1337)
    coroutine.yield(420)
  end)
end

-- override serialization
game_state.coroutine = create_coroutine()
ldump.serializer.handlers[game_state.coroutine] = create_coroutine

local serialized_data = ldump(game_state)  -- serialize
local loaded_game_state = load(serialized_data)()  -- deserialize
```

See as a test at [/tests/test_use_case.lua:19](/tests/test_use_case.lua#L19)


## Installation

Copy the [raw contents of init.lua from the latest release](https://raw.githubusercontent.com/girvel/ldump/refs/tags/v1.1.0/init.lua) into your `lib/ldump.lua` or `git clone -b v1.1.0 https://github.com/girvel/ldump` inside the `lib/` — you still would be able to do `require("ldump")`.


## Overriding serialization

`ldump` handles serialization overload in two ways: through defining a custom serialization metamethod or through assigning a custom serializer for the exact value. See [`__serialize`](#__serialize), [`ldump.custom_serializers`](#ldumpcustom_serializers).


## API

### `ldump`

```lua
ldump(value: any) -> string
```

Serialize given value to a string, that can be deserialized via `load`

#### Example

```lua
local ldump = require("ldump")

local t = setmetatable({
  creation_time = os.clock(),
  inner = coroutine.create(function()
    coroutine.yield(1)
    coroutine.yield(2)
  end)
}, {
  __serialize = function(self)
    local creation_time = self.creation_time  -- capturing upvalue
    return function()
      return {
        creation_time = creation_time,
        inner = coroutine.create(function()
          coroutine.yield(1)
          coroutine.yield(2)
        end)
      }
    end
  end,
})

local data = ldump(t)
local t_copy = load(data)()
```

See as a test at [/tests/test_use_case:65](/tests/test_use_case#L65)

### `ldump.serializer`

```lua
ldump.serializer(x: any) -> (string | fun(): any)?, string?
```

Function, encapsulating custom serialization logic.

Defined by default to work with `__serialize` and `.handlers`, can be reassigned. Accepts the serialized value, returns a deserializer in the form of a string with a valid lua expression, a function or nil if the value should be serialized normally. Also may return a second optional result -- a string to be displayed in the error message.

### `ldump.serializer.handlers`

```lua
ldump.serializer.handlers: table<any, string | fun(): any>
```

Custom serialization functions for the exact objects. 

Key is the value that can be serialized, value is a deserializer in form of a string with a valid lua expression or a function. Takes priority over `__serialize`.

### `ldump.get_warnings`

```lua
ldump.get_warnings() -> string[]
```

Get the list of warnings from the last ldump call.

See [`ldump.strict_mode`](#ldumpstrict_mode)

### `ldump.ignore_upvalue_size`

```lua
ldump.ignore_upvalue_size<T: function>(f: T) -> T
```

Mark function, causing dump to stop producing upvalue size warnings.

Upvalues can cause large modules to be serialized implicitly. Warnings allow to track that. Returns the same function.

### `ldump.strict_mode`

```lua
ldump.strict_mode: boolean = true
```

If true (by default), `ldump` treats unserializable data as an error, if false produces a warning and replaces data with nil.

### `ldump.require_path`

```lua
ldump.require_path: string
```

`require`-style path to the ldump module, used in deserialization.

Inferred from requiring the ldump itself, can be changed.


## Development

Most of the development happened in [girvel/fallen](https://github.com/girvel/fallen), this repository was created afterwards.

### Testing

Via [busted](https://github.com/lunarmodules/busted):

```bash
busted
```

### Plans

Serialization in dynamic languages such as Lua (especially serializing upvalues) has an issue of capturing large chunks of data from modules and libraries, growing the size of the output and causing issues with `==`. [girvel/fallen](https://github.com/girvel/fallen) handles this problem through [module](https://github.com/girvel/fallen/blob/master/lib/module.lua) module, explicitly marking all static data (see [tech.sound](https://github.com/girvel/fallen/blob/master/tech/sound.lua)). This solution seems too verbose and causes boilerplate; right now, an attempt to write a better solution is in progress (see [2.0 milestone](https://github.com/girvel/ldump/milestone/2)).
