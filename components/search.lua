-- components/search.lua - Advanced search with indexing (pure logic, no layout)
-- Simplified from BetterBags - provides fast indexed search across item properties
local addonName, ns = ...

ns.Components = ns.Components or {}
ns.Components.Search = {}

-- Get constants (lazy load)
local function getConst()
    return ns.Components.Constants.Get()
end

-- Search indices
local indices = {
    -- String indices (with prefix matching)
    name = {},          -- Item names
    type = {},          -- Item types
    subtype = {},       -- Item subtypes
    expansion = {},     -- Expansion names

    -- Number indices
    itemID = {},        -- Item IDs
    quality = {},       -- Item quality (0-7)
    ilvl = {},          -- Item level
    stackCount = {},    -- Stack count

    -- Boolean indices
    bound = {},         -- Is bound
    quest = {},         -- Is quest item
    reagent = {},       -- Is crafting reagent
}

-- Helper: Build prefix index for fast string searching
-- @param text - Text to index
-- @param slotKey - Slot key to associate
-- @param index - Index table to update
local function addToStringIndex(text, slotKey, index)
    if not text or text == "" then return end

    text = string.lower(text)

    -- Add full text
    index[text] = index[text] or {}
    index[text][slotKey] = true

    -- Add prefixes for fast prefix matching
    local prefix = ""
    for i = 1, #text do
        prefix = prefix .. text:sub(i, i)
        index[prefix] = index[prefix] or {}
        index[prefix][slotKey] = true
    end
end

-- Helper: Remove from string index
-- @param text - Text that was indexed
-- @param slotKey - Slot key to remove
-- @param index - Index table to update
local function removeFromStringIndex(text, slotKey, index)
    if not text or text == "" then return end

    text = string.lower(text)

    -- Remove full text
    if index[text] then
        index[text][slotKey] = nil
    end

    -- Remove prefixes
    local prefix = ""
    for i = 1, #text do
        prefix = prefix .. text:sub(i, i)
        if index[prefix] then
            index[prefix][slotKey] = nil
        end
    end
end

-- Helper: Add to number index
-- @param value - Number value
-- @param slotKey - Slot key to associate
-- @param index - Index table to update
local function addToNumberIndex(value, slotKey, index)
    if not value then return end

    index[value] = index[value] or {}
    index[value][slotKey] = true
end

-- Helper: Remove from number index
-- @param value - Number value
-- @param slotKey - Slot key to remove
-- @param index - Index table to update
local function removeFromNumberIndex(value, slotKey, index)
    if not value then return end

    if index[value] then
        index[value][slotKey] = nil
    end
end

-- Helper: Add to boolean index
-- @param value - Boolean value
-- @param slotKey - Slot key to associate
-- @param index - Index table to update
local function addToBoolIndex(value, slotKey, index)
    if value == nil then return end

    local key = value and "true" or "false"
    index[key] = index[key] or {}
    index[key][slotKey] = true
end

-- Helper: Remove from boolean index
-- @param value - Boolean value
-- @param slotKey - Slot key to remove
-- @param index - Index table to update
local function removeFromBoolIndex(value, slotKey, index)
    if value == nil then return end

    local key = value and "true" or "false"
    if index[key] then
        index[key][slotKey] = nil
    end
end

-- Add item to search indices
-- @param itemData - Item data from Items component
function ns.Components.Search.AddItem(itemData)
    if itemData.isEmpty then return end

    local slotKey = itemData.bagID .. "_" .. itemData.slotID

    -- Index strings
    addToStringIndex(itemData.itemName, slotKey, indices.name)
    addToStringIndex(itemData.itemType, slotKey, indices.type)
    addToStringIndex(itemData.itemSubType, slotKey, indices.subtype)

    -- Index expansion (if available)
    local const = getConst()
    if itemData.expacID and const.EXPANSION_MAP[itemData.expacID] then
        addToStringIndex(const.EXPANSION_MAP[itemData.expacID], slotKey, indices.expansion)
    end

    -- Index numbers
    addToNumberIndex(itemData.itemID, slotKey, indices.itemID)
    addToNumberIndex(itemData.itemQuality, slotKey, indices.quality)
    addToNumberIndex(itemData.currentItemLevel, slotKey, indices.ilvl)
    addToNumberIndex(itemData.currentItemCount, slotKey, indices.stackCount)

    -- Index booleans
    addToBoolIndex(itemData.isBound, slotKey, indices.bound)
    addToBoolIndex(itemData.isQuestItem, slotKey, indices.quest)
    addToBoolIndex(itemData.isCraftingReagent, slotKey, indices.reagent)
end

-- Remove item from search indices
-- @param itemData - Item data from Items component
function ns.Components.Search.RemoveItem(itemData)
    if itemData.isEmpty then return end

    local slotKey = itemData.bagID .. "_" .. itemData.slotID

    -- Remove strings
    removeFromStringIndex(itemData.itemName, slotKey, indices.name)
    removeFromStringIndex(itemData.itemType, slotKey, indices.type)
    removeFromStringIndex(itemData.itemSubType, slotKey, indices.subtype)

    -- Remove expansion
    local const = getConst()
    if itemData.expacID and const.EXPANSION_MAP[itemData.expacID] then
        removeFromStringIndex(const.EXPANSION_MAP[itemData.expacID], slotKey, indices.expansion)
    end

    -- Remove numbers
    removeFromNumberIndex(itemData.itemID, slotKey, indices.itemID)
    removeFromNumberIndex(itemData.itemQuality, slotKey, indices.quality)
    removeFromNumberIndex(itemData.currentItemLevel, slotKey, indices.ilvl)
    removeFromNumberIndex(itemData.currentItemCount, slotKey, indices.stackCount)

    -- Remove booleans
    removeFromBoolIndex(itemData.isBound, slotKey, indices.bound)
    removeFromBoolIndex(itemData.isQuestItem, slotKey, indices.quest)
    removeFromBoolIndex(itemData.isCraftingReagent, slotKey, indices.reagent)
end

-- Update all indices with current items
-- @param items - Table of item data {slotKey = itemData}
function ns.Components.Search.RebuildIndex(items)
    -- Clear all indices
    ns.Components.Search.ClearIndex()

    -- Add all items
    for _, itemData in pairs(items) do
        ns.Components.Search.AddItem(itemData)
    end
end

-- Clear all search indices
function ns.Components.Search.ClearIndex()
    for _, index in pairs(indices) do
        wipe(index)
    end
end

-- Search for items by text (searches name, type, subtype)
-- @param searchText - Text to search for
-- @return results - Table {slotKey = true} of matching items
function ns.Components.Search.SearchText(searchText)
    if not searchText or searchText == "" then
        return {}
    end

    searchText = string.lower(searchText)
    local results = {}

    -- Search name index
    if indices.name[searchText] then
        for slotKey in pairs(indices.name[searchText]) do
            results[slotKey] = true
        end
    end

    -- Search type index
    if indices.type[searchText] then
        for slotKey in pairs(indices.type[searchText]) do
            results[slotKey] = true
        end
    end

    -- Search subtype index
    if indices.subtype[searchText] then
        for slotKey in pairs(indices.subtype[searchText]) do
            results[slotKey] = true
        end
    end

    return results
end

-- Search by property with comparison
-- Supports: property:value, property>value, property<value, property>=value, property<=value
-- Examples: "quality:4", "ilvl>500", "bound:true"
-- @param property - Property name (quality, ilvl, bound, etc.)
-- @param operator - Comparison operator (=, >, <, >=, <=)
-- @param value - Value to compare
-- @return results - Table {slotKey = true} of matching items
function ns.Components.Search.SearchProperty(property, operator, value)
    local results = {}
    local index = indices[property]

    if not index then return results end

    -- Boolean search
    if property == "bound" or property == "quest" or property == "reagent" then
        local boolValue = (value == "true" or value == "1")
        local key = boolValue and "true" or "false"

        if index[key] then
            for slotKey in pairs(index[key]) do
                results[slotKey] = true
            end
        end
        return results
    end

    -- Number search
    local numValue = tonumber(value)
    if not numValue then return results end

    if operator == "=" or operator == ":" then
        -- Exact match
        if index[numValue] then
            for slotKey in pairs(index[numValue]) do
                results[slotKey] = true
            end
        end
    elseif operator == ">" then
        -- Greater than
        for val, slots in pairs(index) do
            if val > numValue then
                for slotKey in pairs(slots) do
                    results[slotKey] = true
                end
            end
        end
    elseif operator == ">=" then
        -- Greater than or equal
        for val, slots in pairs(index) do
            if val >= numValue then
                for slotKey in pairs(slots) do
                    results[slotKey] = true
                end
            end
        end
    elseif operator == "<" then
        -- Less than
        for val, slots in pairs(index) do
            if val < numValue then
                for slotKey in pairs(slots) do
                    results[slotKey] = true
                end
            end
        end
    elseif operator == "<=" then
        -- Less than or equal
        for val, slots in pairs(index) do
            if val <= numValue then
                for slotKey in pairs(slots) do
                    results[slotKey] = true
                end
            end
        end
    end

    return results
end

-- Parse and execute simple search query
-- Supports:
--   - Simple text search: "sword"
--   - Property search: "quality:4", "ilvl>500", "bound:true"
--   - Multiple terms (OR logic): "sword epic"
-- @param query - Search query
-- @return results - Table {slotKey = true} of matching items
function ns.Components.Search.Search(query)
    if not query or query == "" then
        return {}
    end

    query = string.lower(query)
    local results = {}

    -- Parse query for property searches
    local propertyPattern = "(%w+)([:<>=]+)([%w%.]+)"
    local hasPropertySearch = false

    for property, operator, value in string.gmatch(query, propertyPattern) do
        hasPropertySearch = true
        local propertyResults = ns.Components.Search.SearchProperty(property, operator, value)

        -- Merge results (OR logic)
        for slotKey in pairs(propertyResults) do
            results[slotKey] = true
        end
    end

    -- If no property search, do text search
    if not hasPropertySearch then
        -- Split by spaces for multiple terms
        for term in string.gmatch(query, "%S+") do
            local textResults = ns.Components.Search.SearchText(term)

            -- Merge results (OR logic)
            for slotKey in pairs(textResults) do
                results[slotKey] = true
            end
        end
    end

    return results
end

-- Apply search results to items (set alpha for filtering)
-- @param items - Table of item data {slotKey = itemData}
-- @param searchResults - Table {slotKey = true} from Search()
-- @return items - Modified items with alpha values set
function ns.Components.Search.ApplySearchResults(items, searchResults)
    -- If no search results, show all items
    if not searchResults or not next(searchResults) then
        for _, itemData in pairs(items) do
            itemData.alpha = 1.0
        end
        return items
    end

    -- Apply filter
    for slotKey, itemData in pairs(items) do
        if searchResults[slotKey] then
            itemData.alpha = 1.0 -- Match
        else
            itemData.alpha = 0.1 -- No match - fade
        end
    end

    return items
end

-- Get search statistics (for debugging/info)
-- @return stats - Table with index sizes
function ns.Components.Search.GetStats()
    local stats = {
        totalIndexes = 0,
        indexSizes = {}
    }

    for name, index in pairs(indices) do
        local count = 0
        for _ in pairs(index) do
            count = count + 1
        end
        stats.indexSizes[name] = count
        stats.totalIndexes = stats.totalIndexes + count
    end

    return stats
end
