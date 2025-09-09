local dummy = function() end

function LibStub()
  return {}
end

-- generic frame stub
local function makeFrame()
  local frame = { text = nil }
  local mt = { __index = function(t, k)
      if k == "CreateFontString" then
        return function(self)
          local fs = { text = nil }
          local fsmt = { __index = function(ft, fk)
              if fk == "SetText" then
                return function(self, txt) self.text = txt end
              else
                return dummy
              end
          end }
          setmetatable(fs, fsmt)
          return fs
        end
      elseif k == "SetText" then
        return function(self, txt) self.text = txt end
      else
        return dummy
      end
  end }
  setmetatable(frame, mt)
  return frame
end

CreateFrame = function()
  return makeFrame()
end

UIParent = {}
GameTooltip = { SetOwner = dummy, Show = dummy, Hide = dummy }
GameTooltip_SetTitle = dummy
GameTooltip_AddNormalLine = dummy

local addonEnv = {
  Const = {
    CATEGORY_HEIGHT = 10,
    COLUMN_SPACING = 0,
    ITEM_SPACING = 0,
  },
  Collapsed = { isCollapsed = function() return true end },
  container = { MoneyFrame = makeFrame() },
  printDebug = dummy,
  DragAndDrop = { backgroundOnReceiveDrag = dummy, categoryOnMouseUp = dummy, categoryOnReceiveDrag = dummy, categoryStartDrag = dummy },
}

local chunk = assert(loadfile("gui.lua"))
chunk("MyBags", addonEnv)

local info = { { category = { name = "Test" }, x = 0, y = 0, width = 10, height = 10, itemsCount = 5 } }
addonEnv.gui:RegenerateCategories(0, info)

local text = addonEnv.gui.categoriesFrames[1].fs.text
assert(text == "Test (5) |A:glues-characterSelect-icon-arrowDown:19:19:0:4|a", "label missing item count")
