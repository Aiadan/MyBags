local addonName, AddonNS = ...

AddonNS.ColumnResize = AddonNS.ColumnResize or {}

function AddonNS.ColumnResize:CalculateTarget(currentColumns, estimatedVisibleColumns, minColumns, maxColumns)
    local target = currentColumns

    while target < maxColumns and estimatedVisibleColumns >= target + 0.5 do
        target = target + 1
    end

    while target > minColumns and estimatedVisibleColumns < target - 0.5 do
        target = target - 1
    end

    if target < minColumns then
        target = minColumns
    end
    if target > maxColumns then
        target = maxColumns
    end

    return target
end

AddonNS._Test = AddonNS._Test or {}
AddonNS._Test.ColumnResize = {
    CalculateTarget = function(currentColumns, estimatedVisibleColumns, minColumns, maxColumns)
        return AddonNS.ColumnResize:CalculateTarget(currentColumns, estimatedVisibleColumns, minColumns, maxColumns)
    end,
}
