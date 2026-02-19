local addonName, AddonNS = ...

AddonNS.ContainerItemInfoCache = AddonNS.ContainerItemInfoCache or {}

local NIL = {}
local cacheByBag = {}

function AddonNS.ContainerItemInfoCache:Get(bagID, slotID)
    local bagCache = cacheByBag[bagID]
    if not bagCache then
        bagCache = {}
        cacheByBag[bagID] = bagCache
    end

    local cached = bagCache[slotID]
    if cached == NIL then
        return nil
    end
    if cached ~= nil then
        return cached
    end

    local info = C_Container.GetContainerItemInfo(bagID, slotID)
    bagCache[slotID] = info or NIL
    return info
end

function AddonNS.ContainerItemInfoCache:InvalidateBag(bagID)
    cacheByBag[bagID] = nil
end

function AddonNS.ContainerItemInfoCache:InvalidateAll()
    cacheByBag = {}
end
