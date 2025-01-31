[API](/docs/api.md) | [Overloading serialization](/docs/overloading.md) | [Development](/docs/development.md)

# ldump — serializer for any lua type

`ldump` is a flexible serializer, able to serialize any data, starting with circular references, tables as keys, functions with upvalues, metatables and ending with coroutines, threads and userdata (by defining how they should be serialized). It outputs valid Lua code that recreates the original object, doing the deserialization through `load(data)()`. It aims for functionality and flexibility instead of speed and size, allowing full serialization of complex data, such as video game saves. The output is large, but can be drastically reduced with modern compression algorithms.

Inspired by [`Ser`](https://github.com/gvx/Ser). Supports Lua 5.1, 5.2, 5.3, 5.4 and LuaJIT. Tested for edge cases, such as joined upvalues and _ENV redefinition. Fully annotated in compatibility with LuaLS.

**WARNING:** `ldump`'s deserialization function is Lua's builtin `load`, which can load malicious code. Treat serialized data as arbitrary Lua code (which it is), [`.safe_load` is coming soon](https://github.com/girvel/ldump/issues/42).

| Type                                      | Support      |
| ----------------------------------------- | ------------ |
| nil, boolean, number, string              | full         |
| function                                  | full         |
| userdata                                  | user-defined |
| thread                                    | user-defined |
| table                                     | full         |
| metatables[*](/docs/development.md#plans) | full         |


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

See as a test at [/tests/test_use_case.lua:7](/tests/test_use_case.lua#L7)


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

See as a test at [/tests/test_use_case.lua:23](/tests/test_use_case.lua#L23)


## Installation

Copy the [raw contents of init.lua from the latest release](https://raw.githubusercontent.com/girvel/ldump/refs/tags/v1.2.0/init.lua) into your `lib/ldump.lua` or `git clone -b v1.2.0 https://github.com/girvel/ldump` inside the `lib/` — you still would be able to do `require("ldump")`.

## Credits

- [paulstelian97](https://www.reddit.com/user/paulstelian97/) for providing a joined upvalue test case
- [lambda_abstraction](https://www.reddit.com/user/lambda_abstraction/) for suggesting a way to join upvalues
