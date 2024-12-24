-- NOTICE all tests in this file are represented in README, and should be updated there each time
--   they are updated here

_G.unpack = unpack or table.unpack

it("Basic use case", function()
  local ldump = require("init")

  local upvalue = 42
  local world = {
    name = "New world",
    get_answer = function() return upvalue end,
  }

  local serialized_data = ldump(world)
  local loaded_world = load(serialized_data)()

  assert.are_equal(world.name, loaded_world.name)
  assert.are_equal(world.get_answer(), loaded_world.get_answer())
end)

it("Serializing any lua data", function()
  local ldump = require("init")

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
  ldump.custom_serializers[game_state.coroutine] = create_coroutine

  -- act
  local serialized_data = ldump(game_state)
  local loaded_game_state = load(serialized_data)()

  -- assert
  assert.are_equal(game_state.get_answer(), loaded_game_state.get_answer())
  assert.are_equal(game_state.coroutine(), loaded_game_state.coroutine())
  assert.are_equal(game_state.coroutine(), loaded_game_state.coroutine())

  assert.are_same(game_state.player, loaded_game_state.player)
  assert.are_same(game_state.boss, loaded_game_state.boss)
  assert.are_same(game_state.deleted_entities[game_state.boss], loaded_game_state.deleted_entities[loaded_game_state.boss])
end)

it("Using metatables for serialization override", function()
  local ldump = require("init")

  local create_container = function()
    return {
      inner = coroutine.create(function()
        coroutine.yield(1)
        coroutine.yield(2)
      end)
    }
  end

  local t = setmetatable(create_container(), {
    __serialize = function(self) return create_container end,
  })

  local t_copy = load(ldump(t))()

  assert.are_equal(coroutine.resume(t.inner), coroutine.resume(t_copy.inner))
  assert.are_equal(coroutine.resume(t.inner), coroutine.resume(t_copy.inner))
end)

it("Using custom_serializers for serialization override", function()
  local ldump = require("init")

  local create_coroutine = function()
    return coroutine.create(function()
      coroutine.yield(1)
      coroutine.yield(2)
    end)
  end

  local c = create_coroutine()
  ldump.custom_serializers[c] = create_coroutine
  local c_copy = load(ldump(c))()

  assert.are_equal(coroutine.resume(c), coroutine.resume(c_copy))
  assert.are_equal(coroutine.resume(c), coroutine.resume(c_copy))
end)
