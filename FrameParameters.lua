local addonName, AddonNS = ...

FrameParametersOverride = {};
local DEFAULT_CONTAINER_SCALE = 0.3;
local function GetContainerScaleSingleBag(bag)
    local containerFrameOffsetX = EditModeUtil:GetRightActionBarWidth() + 10
    local screenWidth = GetScreenWidth()
    local screenHeight = GetScreenHeight()
    local containerScale = 1
    local leftLimit = 0

    if BankFrame:IsShown() then
        leftLimit = BankFrame:GetRight() - 25
    end

    -- Get the first (only) bag from the settings manager
    -- local bag = ContainerFrameSettingsManager:GetBagsShown()[1]
    if not bag then
        return DEFAULT_CONTAINER_SCALE -- Default scale if no bag is found
    end

    local bagWidth = bag:GetWidth(true)
    local bagHeight = bag:GetHeight(true)
    local xOffset = containerFrameOffsetX
    local yOffset = CONTAINER_OFFSET_Y

    -- Calculate potential scales based on width & height constraints
    local scaleByHeight = (screenHeight - yOffset) / bagHeight
    local scaleByWidth = (screenWidth - xOffset) / bagWidth

    -- Apply bank frame restriction
    local leftMostPoint = screenWidth - (bagWidth * scaleByWidth) - xOffset
    if leftMostPoint < leftLimit then
        scaleByWidth = (screenWidth - leftLimit - xOffset) / bagWidth
    end

    -- Choose the most restrictive scaling factor
    containerScale = math.min(scaleByHeight, scaleByWidth)

    return containerScale;
end

function FrameParametersOverride:OverrideScale(frame, ignoreFile)
    local oldSetScale = frame.SetScale;
    -- function frame:SetScale(scale)
    --     local stack = debugstack(2, 1, 0) -- Skip 2 levels to get the caller's stack trace
    --     if string.find(stack, ignoreFile) then
    --         scale = frame:GetScale();     -- ignore the change
    --     end
    --     scale = scale > 0.75 and 0.75 or scale;
    --     return oldSetScale(self, scale);
    -- end
    function frame:SetScale(scale)
        -- local stack = debugstack(2, 1, 0) -- Skip 2 levels to get the caller's stack trace
        -- if string.find(stack, ignoreFile) then
        --     scale = frame:GetScale();     -- ignore the change
        -- end
        scale = GetContainerScaleSingleBag(self)
        print("SetScale", scale);
        return oldSetScale(self, scale);
    end
end



function FrameParametersOverride:OverrideHeight(frame, ignoreFile)
    local oldSetHeight = frame.SetHeight
    function frame:SetHeight(height)
        local stack = debugstack(2, 1, 0) -- Skip 2 levels to get the caller's stack trace
        print("SetHeight", stack);
        -- if string.find(stack, ignoreFile) then
        --     height = frame:GetHeight() -- ignore the change
        -- end
        -- height = height < 300 and 300 or height -- Enforce minimum height of 300
        return oldSetHeight(self, height)
    end
end

function FrameParametersOverride:OverrideWidth(frame, ignoreFile)
    local oldSetWidth = frame.SetWidth
    function frame:SetWidth(width)
        local stack = debugstack(2, 1, 0) -- Skip 2 levels to get the caller's stack trace
        print("SetWidth", stack);
        -- if string.find(stack, ignoreFile) then
        --     width = frame:GetWidth() -- ignore the change
        -- end
        -- width = width < 400 and 400 or width -- Enforce minimum width of 400
        return oldSetWidth(self, width)
    end
end

function FrameParametersOverride:OverridePoint(frame, ignoreFile)
   -- local oldSetPoint = frame.SetPoint
    function frame:SetPoint(...)
        local stack = debugstack(2, 1, 0) -- Skip 2 levels to get the caller's stack trace
        print("SetPoint", stack);
        print("SetPoint", debugstack());
        -- if string.find(stack, ignoreFile) then
        --     width = frame:GetWidth() -- ignore the change
        -- end
        -- width = width < 400 and 400 or width -- Enforce minimum width of 400
       -- return oldSetPoint(self, ...)
    end
end

function FrameParametersOverride:OverrideSize(frame, ignoreFile)
    local oldSetSize = frame.SetSize
    function frame:SetSize(width, height)
        local stack = debugstack(2, 1, 0) -- Skip 2 levels to get the caller's stack trace
        print("SetSize", stack);
        print("SetSize", debugstack());
        self:SetWidth(width)
        self:SetHeight(height)
    end
end


FrameParametersOverride:OverrideScale(ContainerFrameCombinedBags, "ContainerFrame.lua")
-- -- Example of applying the overrides
-- FrameParametersOverride:OverrideHeight(ContainerFrameCombinedBags, "ContainerFrame.lua")
-- FrameParametersOverride:OverrideWidth(ContainerFrameCombinedBags, "ContainerFrame.lua")
-- FrameParametersOverride:OverridePoint(ContainerFrameCombinedBags, "ContainerFrame.lua")
-- FrameParametersOverride:OverrideSize(ContainerFrameCombinedBags, "ContainerFrame.lua")
