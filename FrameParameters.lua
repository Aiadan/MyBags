local addonName, AddonNS = ...

FrameParametersOverride = {};
local DEFAULT_CONTAINER_SCALE = 0.05;
local BANK_FRAME_SCREEN_PADDING = 24

local function clampScale(scale)
    if scale < DEFAULT_CONTAINER_SCALE then
        return DEFAULT_CONTAINER_SCALE
    end
    if scale > 1 then
        return 1
    end
    return scale
end

local function computeWidthScale(screenWidth, containerFrameOffsetX, bagVisible, bagWidth, bankVisible, bankWidth)
    local visibleBagWidth = bagVisible and bagWidth or 0
    local visibleBankWidth = bankVisible and bankWidth or 0
    local totalVisibleWidth = visibleBagWidth + visibleBankWidth
    if totalVisibleWidth <= 0 then
        return 1
    end
    local availableWidth = screenWidth - containerFrameOffsetX - BANK_FRAME_SCREEN_PADDING * 2
    return availableWidth / totalVisibleWidth
end

local function computeHeightScale(visible, availableHeight, frameHeight)
    if not visible then
        return 1
    end
    if not frameHeight or frameHeight <= 0 then
        return 1
    end
    return availableHeight / frameHeight
end

local function computeFrameScales(screenWidth, screenHeight, containerFrameOffsetX, bagVisible, bagWidth, bagHeight, bankVisible, bankWidth, bankHeight)
    local widthScale = computeWidthScale(screenWidth, containerFrameOffsetX, bagVisible, bagWidth, bankVisible, bankWidth)
    local bagHeightScale = computeHeightScale(bagVisible, screenHeight - CONTAINER_OFFSET_Y, bagHeight)
    local bankHeightScale = computeHeightScale(bankVisible, screenHeight - BANK_FRAME_SCREEN_PADDING * 2, bankHeight)
    local bagScale = clampScale(math.min(widthScale, bagHeightScale))
    local bankScale = clampScale(math.min(widthScale, bankHeightScale))
    return bagScale, bankScale
end

local function getFrameScale(frame)
    local containerFrameOffsetX = EditModeUtil:GetRightActionBarWidth() + 10
    local screenWidth = GetScreenWidth()
    local screenHeight = GetScreenHeight()

    local bagVisible = ContainerFrameCombinedBags and ContainerFrameCombinedBags:IsShown() or false
    local bagWidth = ContainerFrameCombinedBags and ContainerFrameCombinedBags:GetWidth(true) or 0
    local bagHeight = ContainerFrameCombinedBags and ContainerFrameCombinedBags:GetHeight(true) or 0
    local bankVisible = BankFrame and BankFrame:IsShown() or false
    local bankWidth = BankFrame and BankFrame:GetWidth(true) or 0
    local bankHeight = BankFrame and BankFrame:GetHeight(true) or 0
    local bagScale, bankScale = computeFrameScales(
        screenWidth,
        screenHeight,
        containerFrameOffsetX,
        bagVisible,
        bagWidth,
        bagHeight,
        bankVisible,
        bankWidth,
        bankHeight
    )

    if frame == BankFrame then
        return bankScale
    end
    return bagScale
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
        scale = getFrameScale(self)
        AddonNS.printDebug("SetScale", scale);
        return oldSetScale(self, scale);
    end
end

AddonNS._Test = AddonNS._Test or {}
AddonNS._Test.FrameParameters = {
    ComputeFrameScales = computeFrameScales,
    ComputeWidthScale = computeWidthScale,
    ComputeHeightScale = computeHeightScale,
    ClampScale = clampScale,
}



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
