# ldump — serializer for any lua type

(description)

## TL;DR show me the code

```lua
local ldump = require("ldump")

local upvalue = 42
local world = {
  name = "New world",
  get_answer = function() return upvalue end,
}

local serialized_data = ldump(world)
local loaded_world = load(serialized_data)()
```

Run yourself at [/tests/test_use_case.lua:3](/tests/test_use_case.lua#L3)

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

game_state.coroutine = create_coroutine()
ldump.custom_serializers[game_state.coroutine] = function()
  return create_coroutine
end

-- act
local serialized_data = ldump(game_state)
local loaded_game_state = load(serialized_data)()
```

Run yourself at [/tests/test_use_case.lua:19](/tests/test_use_case.lua#L19)

## Installation

Copy the [raw contents of init.lua](https://raw.githubusercontent.com/girvel/ldump/refs/heads/master/init.lua) into your `lib/ldump.lua` or `git clone https://github.com/girvel/ldump` inside the `lib/` — you still would be able to do `require("ldump")`

## API

### ldump

```lua
ldump(value: any) -> string
```

Serialize given value to a string, that can be deserialized via `load`

### ldump.get_warnings

```lua
ldump.get_warnings() -> string[]
```

Get the list of warnings from the last ldump call.

See [`ldump.strict_mode`](#ldumpstrict_mode)

### ldump.ignore_upvalue_size

```lua
ldump.ignore_upvalue_size<T: function>(f: T) -> T
```

Mark function, causing dump to stop producing upvalue size warnings.

Upvalues can cause large modules to be serialized implicitly. Warnings allow to track that. Returns the same function.

### ldump.require_path

```lua
ldump.require_path: string
```

`require`-style path to the ldump module, used in deserialization.

Inferred from requiring the ldump itself, can be changed.

### serialize_function

```lua
type serialize_function = fun(any): (string | fun(): any)
```

Type of any serialize function, either defined in `getmetatable(x).__serialize` or passed through

### ldump.custom_serializers

```lua
ldump.custom_serializers: table<any, serialize_function> = {}
```

Custom serialization functions for the exact objects.

Key is the value that can be serialized, value is its serialization function. Takes priority over `getmetatable(x).__serialize`.

### ldump.strict_mode

```lua
ldump.strict_mode: boolean = true
```

If true (by default), `ldump` treats unserializable data as an error, if false produces a warning.

## Development

### Testing

Via [busted](https://github.com/lunarmodules/busted):

```bash
busted
```

