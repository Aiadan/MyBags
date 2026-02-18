package.path = package.path .. ";./?.lua;./?/init.lua"

local addonEnv = {
  ColumnResize = {},
  ResizeHandle = {},
  _Test = {},
  Const = {
    COLUMN_SPACING = 2,
    MIN_NUM_COLUMNS = 3,
    MAX_NUM_COLUMNS = 8,
  },
}

local columnResizeChunk = assert(loadfile("columnResize.lua"))
columnResizeChunk("MyBags", addonEnv)

local resizeHandleChunk = assert(loadfile("resizeHandle.lua"))
resizeHandleChunk("MyBags", addonEnv)

local testHooks = addonEnv._Test.ResizeHandle

local function assertEqual(expected, actual, message)
  if expected ~= actual then
    error((message or "values differ") .. ": expected " .. tostring(expected) .. " got " .. tostring(actual), 2)
  end
end

local chromeOffset, minWidth, maxWidth = testHooks.CalculateWidthBounds(620, 4, 166, 3, 8)
assertEqual(-44, chromeOffset, "chrome offset")
assertEqual(454, minWidth, "minimum width")
assertEqual(1284, maxWidth, "maximum width")

assertEqual(454, testHooks.ClampWidth(300, minWidth, maxWidth), "clamps low widths")
assertEqual(700, testHooks.ClampWidth(700, minWidth, maxWidth), "keeps in-range widths")
assertEqual(1284, testHooks.ClampWidth(2000, minWidth, maxWidth), "clamps high widths")

local target = testHooks.CalculateTargetColumns(702, chromeOffset, 166, 4, 3, 8)
assertEqual(4, target, "stays at current column count below +0.5 threshold")

target = testHooks.CalculateTargetColumns(703, chromeOffset, 166, 4, 3, 8)
assertEqual(5, target, "grows at +0.5 threshold")

local previewTarget, previewDelta = testHooks.ClassifyPreviewTarget(536, chromeOffset, 166, 4, 3, 8)
assertEqual(3, previewTarget, "preview shrinks below -0.5 threshold")
assertEqual(-1, previewDelta, "preview shrink delta")

print("All resize handle helper scenarios completed.")
