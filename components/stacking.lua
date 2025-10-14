-- components/stacking.lua - Item stacking logic (pure logic, no layout)
-- Extracted from BetterBags - handles identical items stacking (like chests)
local addonName, ns = ...

ns.Components = ns.Components or {}
ns.Components.Stacking = {}

-- Stack info: tracks identical items (same hash) across multiple slots
local stackInfo = {}

-- Stack an item hash and track all slots containing it
-- @param itemHash - Hash identifying identical items
-- @param itemData - Item data with bagID, slotID, currentItemCount
function ns.Components.Stacking.AddToStack(itemHash, itemData)
    if not stackInfo[itemHash] then
        stackInfo[itemHash] = {
            rootItem = itemData.slotKey,
            slotKeys = {},
            totalCount = 0,
            stackCount = 0,
        }
    end

    local stack = stackInfo[itemHash]

    -- Add this slot to the stack
    stack.slotKeys[itemData.slotKey] = true
    stack.totalCount = stack.totalCount + (itemData.currentItemCount or 1)
    stack.stackCount = stack.stackCount + 1

    -- Update root item (use first slot as root)
    if not stack.rootItem then
        stack.rootItem = itemData.slotKey
    end
end

-- Get stack info for an item hash
-- @param itemHash - Hash identifying identical items
-- @return stackInfo - Table with rootItem, slotKeys, totalCount, stackCount
function ns.Components.Stacking.GetStackInfo(itemHash)
    return stackInfo[itemHash]
end

-- Filter items to hide duplicates (show only root item per stack)
-- @param items - Table of item data {slotKey = itemData}
-- @return filteredItems - Table with duplicates hidden
function ns.Components.Stacking.FilterStackedItems(items)
    -- Clear previous stacks
    stackInfo = {}

    -- Build stacks
    for slotKey, itemData in pairs(items) do
        if not itemData.isEmpty and itemData.itemHash then
            ns.Components.Stacking.AddToStack(itemData.itemHash, itemData)
        end
    end

    -- Filter items: only show root items for stacks
    local filtered = {}

    for slotKey, itemData in pairs(items) do
        if itemData.isEmpty then
            -- Always show empty slots
            filtered[slotKey] = itemData
        else
            local stack = stackInfo[itemData.itemHash]

            if stack and stack.stackCount > 1 then
                -- This item is part of a stack
                if stack.rootItem == slotKey then
                    -- This is the root item - show it with stack info
                    itemData.stacks = stack.stackCount
                    itemData.stackedCount = stack.totalCount
                    filtered[slotKey] = itemData
                end
                -- Non-root items are hidden (not added to filtered)
            else
                -- Not stacked - show normally
                itemData.stacks = 0
                itemData.stackedCount = itemData.currentItemCount or 1
                filtered[slotKey] = itemData
            end
        end
    end

    return filtered
end

-- Get all stacks
-- @return stackInfo - Table of all stacks {itemHash = stackInfo}
function ns.Components.Stacking.GetAllStacks()
    return stackInfo
end

-- Clear all stack data
function ns.Components.Stacking.Clear()
    stackInfo = {}
end

-- Check if an item is stacked
-- @param itemData - Item data
-- @return isStacked - true if item is part of a multi-slot stack
function ns.Components.Stacking.IsStacked(itemData)
    if itemData.isEmpty or not itemData.itemHash then
        return false
    end

    local stack = stackInfo[itemData.itemHash]
    return stack and stack.stackCount > 1
end

-- Get stack count for an item
-- @param itemData - Item data
-- @return stackCount - Number of slots containing this item
function ns.Components.Stacking.GetStackCount(itemData)
    if itemData.isEmpty or not itemData.itemHash then
        return 0
    end

    local stack = stackInfo[itemData.itemHash]
    return stack and stack.stackCount or 0
end
