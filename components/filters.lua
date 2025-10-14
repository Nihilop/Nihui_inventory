-- components/filters.lua - Search and filter logic (pure logic, no layout)
-- Extracted from BetterBags - handles item filtering and search
local addonName, ns = ...

ns.Components = ns.Components or {}
ns.Components.Filters = {}

-- Filter items by search text
-- @param items - Table of item data {slotKey = itemData}
-- @param searchText - Search text (case insensitive)
-- @return filteredItems - Table with filtered items
function ns.Components.Filters.FilterBySearch(items, searchText)
    if not searchText or searchText == "" then
        -- No filter - return all items with full opacity
        for _, itemData in pairs(items) do
            itemData.alpha = 1.0
        end
        return items
    end

    searchText = searchText:lower()

    -- Apply filter (fade non-matching items)
    for _, itemData in pairs(items) do
        if itemData.isEmpty then
            itemData.alpha = 0.3 -- Fade empty slots
        else
            local itemName = (itemData.itemName or ""):lower()

            if itemName:find(searchText, 1, true) then
                itemData.alpha = 1.0 -- Match - full opacity
            else
                itemData.alpha = 0.3 -- No match - fade
            end
        end
    end

    return items
end

-- Filter items by item type
-- @param items - Table of item data
-- @param itemType - Item type to filter
-- @return filteredItems - Filtered items
function ns.Components.Filters.FilterByType(items, itemType)
    local filtered = {}

    for slotKey, itemData in pairs(items) do
        if itemData.isEmpty then
            filtered[slotKey] = itemData
        elseif itemType == nil or itemData.itemType == itemType then
            filtered[slotKey] = itemData
        end
    end

    return filtered
end

-- Filter items by quality
-- @param items - Table of item data
-- @param minQuality - Minimum quality (Enum.ItemQuality)
-- @return filteredItems - Filtered items
function ns.Components.Filters.FilterByQuality(items, minQuality)
    local filtered = {}

    for slotKey, itemData in pairs(items) do
        if itemData.isEmpty then
            filtered[slotKey] = itemData
        elseif minQuality == nil or (itemData.itemQuality and itemData.itemQuality >= minQuality) then
            filtered[slotKey] = itemData
        end
    end

    return filtered
end

-- Filter items by bag
-- @param items - Table of item data
-- @param bagID - Bag ID to filter
-- @return filteredItems - Items from specified bag only
function ns.Components.Filters.FilterByBag(items, bagID)
    local filtered = {}

    for slotKey, itemData in pairs(items) do
        if itemData.bagID == bagID then
            filtered[slotKey] = itemData
        end
    end

    return filtered
end

-- Group items by category
-- @param items - Table of item data
-- @return groups - Table {category = {items}}
function ns.Components.Filters.GroupByCategory(items)
    local groups = {}

    for slotKey, itemData in pairs(items) do
        if not itemData.isEmpty then
            local category = itemData.itemType or "Miscellaneous"

            if not groups[category] then
                groups[category] = {}
            end

            groups[category][slotKey] = itemData
        end
    end

    return groups
end

-- Sort items by name
-- @param items - Table of item data
-- @return sortedItems - Array of item data sorted by name
function ns.Components.Filters.SortByName(items)
    local sorted = {}

    for _, itemData in pairs(items) do
        table.insert(sorted, itemData)
    end

    table.sort(sorted, function(a, b)
        if a.isEmpty and not b.isEmpty then return false end
        if not a.isEmpty and b.isEmpty then return true end
        if a.isEmpty and b.isEmpty then return false end

        return (a.itemName or "") < (b.itemName or "")
    end)

    return sorted
end

-- Sort items by quality
-- @param items - Table of item data
-- @return sortedItems - Array of item data sorted by quality (descending)
function ns.Components.Filters.SortByQuality(items)
    local sorted = {}

    for _, itemData in pairs(items) do
        table.insert(sorted, itemData)
    end

    table.sort(sorted, function(a, b)
        if a.isEmpty and not b.isEmpty then return false end
        if not a.isEmpty and b.isEmpty then return true end
        if a.isEmpty and b.isEmpty then return false end

        local qualityA = a.itemQuality or 0
        local qualityB = b.itemQuality or 0

        if qualityA == qualityB then
            return (a.itemName or "") < (b.itemName or "")
        end

        return qualityA > qualityB -- Descending quality
    end)

    return sorted
end

-- Sort items by bag and slot (default order)
-- @param items - Table of item data
-- @return sortedItems - Array of item data sorted by bag/slot
function ns.Components.Filters.SortByBagSlot(items)
    local sorted = {}

    for _, itemData in pairs(items) do
        table.insert(sorted, itemData)
    end

    table.sort(sorted, function(a, b)
        if a.bagID == b.bagID then
            return a.slotID < b.slotID
        end
        return a.bagID < b.bagID
    end)

    return sorted
end
