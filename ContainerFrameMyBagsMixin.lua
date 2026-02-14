local addonName, AddonNS = ...
local isCollapsed = AddonNS.Collapsed.isCollapsed;
local ITEM_SPACING = AddonNS.Const.ITEM_SPACING;

local ContainerFrameMyBagsMixin = {};
local TaintingContainerFrameMyBagsMixin = {};

function ContainerFrameMyBagsMixin:MyBagsInit()
    self.MyBags = {};
    self.MyBags.categorizeItems = true;
    self.MyBags.arrangedItems = {};
    self.MyBags.positionsInBags = {};
    self.MyBags.categoryPositions = {};
    self.MyBags.rows = 0;
    self.MyBags.height = 0;
    self.MyBags.updateItemLayoutCalledAtLeastOnce = false
end

function ContainerFrameMyBagsMixin:UpdateItemLayout()
    AddonNS.printDebug("UpdateItemLayout")
    self.MyBags.updateItemLayoutCalledAtLeastOnce = true;
    self.MyBags.categorizeItems = true;
    local itemButtons = {}
    for i, itemButton in self:EnumerateValidItems() do -- todo: can refactor this to single loop once I stop using enumerate to assign positions in bags. Otherwsie I have to run over this function first before putting items into proper places
        table.insert(itemButtons, itemButton);
    end
    local yFrameOffset = self:CalculateHeight() - self:GetPaddingHeight() -
        self:CalculateExtraHeight() + ITEM_SPACING + self:CalculateHeightForCategoriesTitles();

    local anchor = self:GetInitialItemAnchor();

    local _, relativeTo = anchor:Get();
    anchor:Set("TOPLEFT", relativeTo, "TOPLEFT", 0, 0);
    local point, relativeTo, relativePoint, x, y = anchor:Get();
    AddonNS.printDebug("Anchor", x, y)

    self:UpdateFrameSize();
    for i, itemButton in ipairs(itemButtons) do
        if (itemButton.ItemCategory and not isCollapsed(itemButton.ItemCategory)) then
            local newXOffset = self.MyBags.positionsInBags[itemButton:GetBagID()][itemButton:GetID()].x;
            local newYOffset = -self.MyBags.positionsInBags[itemButton:GetBagID()][itemButton:GetID()].y + yFrameOffset;
            itemButton:ClearAllPoints();
            itemButton:SetPoint(point, relativeTo, relativePoint, x + newXOffset, y + newYOffset);
            itemButton:Show();
        else
            itemButton:Hide();
        end
    end

    AddonNS.gui:RegenerateCategories(yFrameOffset, self.MyBags.categoryPositions);
end

function ContainerFrameMyBagsMixin:EnumerateValidItems()
    if self.MyBags.categorizeItems then
        AddonNS.printDebug("EnumerateValidItems override used")
        self.MyBags.categorizeItems = false;
        self.MyBags.arrangedItems = {}
        return AddonNS.newEnumerateValidItems(self);
    end
    AddonNS.printDebug("EnumerateValidItems default used")
    return ContainerFrameCombinedBagsMixin.EnumerateValidItems(self);
end

--[[
Note:
this expansion allows to get reagent bags. It cannot overwrite functions of bags,
and has to be hooked as otherwise when player is in combat and opens the bags for
the first time the path gets tainted and it is no longer possible to use items like
potions during combat
]]
local function updateItemSlots(self, ...)
    AddonNS.printDebug("UpdateItemSlots")

    local bagSize = ContainerFrame_GetContainerNumSlots(Enum.BagIndex.ReagentBag);
    for i = 1, bagSize do
        local itemButton = self:AcquireNewItemButton();
        local slotID = bagSize - i + 1;
        itemButton:Initialize(Enum.BagIndex.ReagentBag, slotID);
    end
end;
hooksecurefunc(ContainerFrameCombinedBags, "UpdateItemSlots", updateItemSlots)

-- Workaround: forcing OpenAllBags before the default bank open flow resolves the observed bank taint path.
local oldBankFrame_Open = BankFrame_Open
function BankFrame_Open()
    OpenAllBags(BankFrame)
    oldBankFrame_Open()
end

-- need to overwrite this as it is used during enumeration of items in the bags so otherwise it would not incorporate reagentsContainer
local function setBagSize(self)
    self.size = 0;
    for i = 0, Enum.BagIndex.ReagentBag, 1 do
        self.size = self.size + ContainerFrame_GetContainerNumSlots(i);
    end
end
hooksecurefunc(ContainerFrameCombinedBags, "SetBagSize", setBagSize)



function TaintingContainerFrameMyBagsMixin:MatchesBagID(id) -- override to include reagent bags, marked as something that can still easily taint.
    return id >= Enum.BagIndex.Backpack and id <= Enum.BagIndex.ReagentBag;
end

function ContainerFrameMyBagsMixin:CalculateHeightForCategoriesTitles()
    return self.MyBags.height - self.MyBags.rows * (self.Items[1]:GetHeight() + ITEM_SPACING);
end

function ContainerFrameMyBagsMixin:CalculateExtraHeight()
    return self:CalculateHeightForCategoriesTitles() + ContainerFrameCombinedBagsMixin.CalculateExtraHeight(self);
end

function ContainerFrameMyBagsMixin:CalculateWidth()
    return ContainerFrameCombinedBagsMixin.CalculateWidth(self) +
        (AddonNS.Const.NUM_COLUMNS - 1) * AddonNS.Const.COLUMN_SPACING -
        self:GetColumns() * (AddonNS.Const.ORIGINAL_SPACING - ITEM_SPACING);
end

function ContainerFrameMyBagsMixin:GetRows()
    return self.MyBags.rows;
end

Mixin(ContainerFrameCombinedBags, ContainerFrameMyBagsMixin);

--[[ 
This is a workaround for quite and interesting tainting. MatchesBagID is called by MainMenuBarBagButtons (currently line 140)
When this is done during during combat this flow gets tainted. Hence we would need to check if bag was opened in a safe space, ie. making sure all
calls were made and then, and only then we can hook those functions. As matchesBagID does not seem to be critical, users might not notice it not working
as expected during combat - this is impacting reagents after all and low chances are someone will try to use / do something with them while fighting.
There is a chance that with recent changes to handling item movements that might not be needed, as I am not sure at current time what would
be caused by remove of that overriding that function. Nontheless this shows how this can be done if needed.
This functionality currently checks for calls to itself, but probably to make it more generic we should just check if bag was open in safe environment and
then hook / mixing / overwrite all needed functions.
]]
local taintingContainerFrameMyBagsMixinMatchesBagIDHooked = false;
local function tryHook(self, id)
    if (not taintingContainerFrameMyBagsMixinMatchesBagIDHooked and id > 0 and not InCombatLockdown()) then
        Mixin(ContainerFrameCombinedBags, TaintingContainerFrameMyBagsMixin);
        taintingContainerFrameMyBagsMixinMatchesBagIDHooked = true;
    end
end
hooksecurefunc(ContainerFrameCombinedBags, "MatchesBagID", tryHook)

ContainerFrameCombinedBags:MyBagsInit();
