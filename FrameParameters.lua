local addonName, AddonNS = ...

FrameParametersOverride = {};
local DEFAULT_CONTAINER_SCALE = 0.3;
local BANK_FRAME_SCREEN_PADDING = 24
local function GetContainerScaleSingleBag(bag)
    local containerFrameOffsetX = EditModeUtil:GetRightActionBarWidth() + 10
    local screenWidth = GetScreenWidth()
    local screenHeight = GetScreenHeight()
    local containerScale = 1
    local leftLimit = 0

    if BankFrame:IsShown() then
        leftLimit = BankFrame:GetRight()
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
    containerScale = math.min(scaleByHeight, scaleByWidth, 1)

    return containerScale;
end

local function getBankFrameScale(frame)
    local frameWidth = frame:GetWidth(true)
    local frameHeight = frame:GetHeight(true)
    if not frameWidth or not frameHeight or frameWidth <= 0 or frameHeight <= 0 then
        return 1
    end

    local screenWidth = GetScreenWidth()
    local screenHeight = GetScreenHeight()
    local availableWidth = screenWidth - BANK_FRAME_SCREEN_PADDING * 2
    local availableHeight = screenHeight - BANK_FRAME_SCREEN_PADDING * 2
    local scaleByWidth = availableWidth / frameWidth
    local scaleByHeight = availableHeight / frameHeight
    local scale = math.min(scaleByWidth, scaleByHeight, 1)
    if scale < 0 then
        scale = 0
    end
    return scale
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
        if self == BankFrame then
            scale = getBankFrameScale(self)
        end
        AddonNS.printDebug("SetScale", scale);
        return oldSetScale(self, scale);
    end
end



function FrameParametersOverride:OverrideHeight(frame, ignoreFile)
    local oldSetHeight = frame.SetHeight
    function frame:SetHeight(height)
        local stack = debugstack(2, 1, 0) -- Skip 2 levels to get the caller's stack trace
        AddonNS.printDebug("SetHeight", stack);
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
        AddonNS.printDebug("SetWidth", stack);
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
        AddonNS.printDebug("SetPoint", stack);
        AddonNS.printDebug("SetPoint", debugstack());
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
        AddonNS.printDebug("SetSize", stack);
        AddonNS.printDebug("SetSize", debugstack());
        self:SetWidth(width)
        self:SetHeight(height)
    end
end


FrameParametersOverride:OverrideScale(ContainerFrameCombinedBags, "ContainerFrame.lua")
if BankFrame then
    FrameParametersOverride:OverrideScale(BankFrame, "BankFrame.lua")
    BankFrame.myBagsScaleOverridden = true
else
    AddonNS.Events:RegisterEvent("BANKFRAME_OPENED", function()
        if BankFrame and not BankFrame.myBagsScaleOverridden then
            FrameParametersOverride:OverrideScale(BankFrame, "BankFrame.lua")
            BankFrame.myBagsScaleOverridden = true
            RunNextFrame(function()
                AddonNS.ApplyBankFrameScale()
            end)
        end
    end)
end

function AddonNS.ApplyBankFrameScale()
    if not BankFrame then
        return
    end
    BankFrame:SetScale(BankFrame:GetScale())
end

function AddonNS.ApplyContainerFrameScale()
    if not ContainerFrameCombinedBags then
        return
    end
    ContainerFrameCombinedBags:SetScale(ContainerFrameCombinedBags:GetScale())
end
-- -- Example of applying the overrides
-- FrameParametersOverride:OverrideHeight(ContainerFrameCombinedBags, "ContainerFrame.lua")
-- FrameParametersOverride:OverrideWidth(ContainerFrameCombinedBags, "ContainerFrame.lua")
-- FrameParametersOverride:OverridePoint(ContainerFrameCombinedBags, "ContainerFrame.lua")
-- FrameParametersOverride:OverrideSize(ContainerFrameCombinedBags, "ContainerFrame.lua")
