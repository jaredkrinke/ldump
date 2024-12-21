--- @meta

--- @param description string
--- @param body fun(): nil
describe = function(description, body) end

--- @param description string
--- @param body fun(): nil
it = function(description, body) end

--- @param it boolean
assert.is_true = function(it) end

--- @param it nil
assert.is_nil = function(it) end

--- @generic T
--- @param a T
--- @param b T
assert.are_equal = function(a, b) end

--- @generic T: table
--- @param a T
--- @param b T
assert.are_same = function(a, b) end
