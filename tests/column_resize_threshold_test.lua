package.path = package.path .. ";./?.lua;./?/init.lua"

local addonEnv = {
  ColumnResize = {},
  _Test = {},
}

local chunk = assert(loadfile("columnResize.lua"))
chunk("MyBags", addonEnv)

local function assert_equal(expected, actual, message)
  if expected ~= actual then
    error((message or "values differ") .. ": expected " .. tostring(expected) .. " got " .. tostring(actual), 2)
  end
end

local calc = addonEnv._Test.ColumnResize.CalculateTarget
local classify = addonEnv._Test.ColumnResize.ClassifyPreview

assert_equal(4, calc(3, 3.5, 3, 8), "grow at +0.5 threshold")
assert_equal(3, calc(3, 3.49, 3, 8), "no grow below +0.5")
assert_equal(3, calc(3, 2.5, 3, 8), "no shrink at 2.5")
assert_equal(3, calc(3, 2.49, 3, 8), "min bound keeps 3")
assert_equal(8, calc(3, 8.6, 3, 8), "multi-step grow clamps to max")
assert_equal(3, calc(8, 1.1, 3, 8), "multi-step shrink clamps to min")

do
  local target, delta = classify(3, 3.5, 3, 8)
  assert_equal(4, target, "preview grow target")
  assert_equal(1, delta, "preview grow delta")
end

do
  local target, delta = classify(3, 3.49, 3, 8)
  assert_equal(3, target, "preview no-change target")
  assert_equal(0, delta, "preview no-change delta")
end

do
  local target, delta = classify(4, 3.49, 3, 8)
  assert_equal(3, target, "preview shrink target")
  assert_equal(-1, delta, "preview shrink delta")
end

do
  local target, delta = classify(7, 99, 3, 8)
  assert_equal(8, target, "preview max clamp target")
  assert_equal(1, delta, "preview max clamp delta")
end

do
  local target, delta = classify(8, -12, 3, 8)
  assert_equal(3, target, "preview min clamp target")
  assert_equal(-5, delta, "preview min clamp delta")
end

print("All column resize threshold scenarios completed.")
