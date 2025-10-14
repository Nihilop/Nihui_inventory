-- components/categories.lua - Item categorization system (pure logic, no layout)
-- Simplified from BetterBags - provides custom categories and automatic categorization
local addonName, ns = ...

ns.Components = ns.Components or {}
ns.Components.Categories = {}

-- Get constants (lazy load)
local function getConst()
    return ns.Components.Constants.Get()
end

-- Category storage
local categories = {} -- {categoryName = CategoryData}
local categoryFunctions = {} -- {functionID = function}
local itemToCategory = {} -- {itemID = categoryName} (cache)
local itemsWithNoCategory = {} -- {itemID = true} (optimization)

-- Category data structure:
-- {
--   name = "Category Name",
--   itemList = {itemID = true, ...},
--   enabled = {[BAG_KIND.BACKPACK] = true, [BAG_KIND.BANK] = true},
--   priority = 10,
--   color = {r, g, b},
--   searchQuery = "ilvl>500",  -- Optional: for search-based categories
--   dynamic = false,  -- If true, created at runtime via function
-- }

-- Create a new category
-- @param name - Category name
-- @param options - Table {itemList, enabled, priority, color, searchQuery}
function ns.Components.Categories.CreateCategory(name, options)
    options = options or {}

    -- Default enabled for all bag types
    local const = getConst()
    local enabled = options.enabled or {
        [const.BAG_KIND.BACKPACK] = true,
        [const.BAG_KIND.BANK] = true,
    }

    categories[name] = {
        name = name,
        itemList = options.itemList or {},
        enabled = enabled,
        priority = options.priority or 10,
        color = options.color,
        searchQuery = options.searchQuery,
        dynamic = options.dynamic or false,
    }

    -- Update item-to-category cache
    if options.itemList then
        for itemID in pairs(options.itemList) do
            itemToCategory[itemID] = name
        end
    end

    -- Notify listeners
    ns.Components.Events.SendMessage("Categories/Changed", name)
end

-- Delete a category
-- @param name - Category name
function ns.Components.Categories.DeleteCategory(name)
    if not categories[name] then return end

    -- Clear item cache
    for itemID in pairs(categories[name].itemList) do
        if itemToCategory[itemID] == name then
            itemToCategory[itemID] = nil
        end
    end

    categories[name] = nil

    -- Notify listeners
    ns.Components.Events.SendMessage("Categories/Changed", name)
end

-- Add item to category
-- @param itemID - Item ID
-- @param categoryName - Category name
function ns.Components.Categories.AddItemToCategory(itemID, categoryName)
    if not categories[categoryName] then
        -- Create category if it doesn't exist
        ns.Components.Categories.CreateCategory(categoryName)
    end

    -- Add to category
    categories[categoryName].itemList[itemID] = true
    itemToCategory[itemID] = categoryName

    -- Remove from "no category" cache
    itemsWithNoCategory[itemID] = nil

    -- Notify listeners
    ns.Components.Events.SendMessage("Categories/ItemAdded", categoryName, itemID)
end

-- Remove item from category
-- @param itemID - Item ID
function ns.Components.Categories.RemoveItemFromCategory(itemID)
    local categoryName = itemToCategory[itemID]
    if not categoryName or not categories[categoryName] then return end

    -- Remove from category
    categories[categoryName].itemList[itemID] = nil
    itemToCategory[itemID] = nil

    -- Notify listeners
    ns.Components.Events.SendMessage("Categories/ItemRemoved", categoryName, itemID)
end

-- Get category for an item
-- @param itemData - Item data
-- @param bagKind - Bag type (BACKPACK or BANK)
-- @return categoryName - Category name or nil
function ns.Components.Categories.GetCategory(itemData, bagKind)
    local itemID = itemData.itemID
    if not itemID then return nil end

    -- Check cache
    local categoryName = itemToCategory[itemID]
    if categoryName then
        local category = categories[categoryName]
        if category and category.enabled[bagKind] then
            return categoryName
        end
        return nil
    end

    -- Check if already marked as having no category
    if itemsWithNoCategory[itemID] then return nil end

    -- Try registered functions
    for funcID, func in pairs(categoryFunctions) do
        local success, result = xpcall(func, geterrorhandler(), itemData)
        if success and result then
            -- Add to category
            ns.Components.Categories.AddItemToCategory(itemID, result)

            -- Check if enabled
            local category = categories[result]
            if category and category.enabled[bagKind] then
                return result
            end
            return nil
        end
    end

    -- No category found - mark it
    itemsWithNoCategory[itemID] = true
    return nil
end

-- Get all categories
-- @return categories - Table {name = CategoryData}
function ns.Components.Categories.GetAllCategories()
    return categories
end

-- Get category by name
-- @param name - Category name
-- @return category - CategoryData or nil
function ns.Components.Categories.GetCategoryByName(name)
    return categories[name]
end

-- Check if category exists
-- @param name - Category name
-- @return exists - Boolean
function ns.Components.Categories.DoesCategoryExist(name)
    return categories[name] ~= nil
end

-- Enable category for bag type
-- @param name - Category name
-- @param bagKind - Bag type (BACKPACK or BANK)
function ns.Components.Categories.EnableCategory(name, bagKind)
    if not categories[name] then return end

    categories[name].enabled[bagKind] = true

    -- Notify listeners
    ns.Components.Events.SendMessage("Categories/EnabledChanged", name, bagKind, true)
end

-- Disable category for bag type
-- @param name - Category name
-- @param bagKind - Bag type (BACKPACK or BANK)
function ns.Components.Categories.DisableCategory(name, bagKind)
    if not categories[name] then return end

    categories[name].enabled[bagKind] = false

    -- Notify listeners
    ns.Components.Events.SendMessage("Categories/EnabledChanged", name, bagKind, false)
end

-- Toggle category enabled state
-- @param name - Category name
-- @param bagKind - Bag type (BACKPACK or BANK)
function ns.Components.Categories.ToggleCategory(name, bagKind)
    if not categories[name] then return end

    local enabled = not categories[name].enabled[bagKind]
    categories[name].enabled[bagKind] = enabled

    -- Notify listeners
    ns.Components.Events.SendMessage("Categories/EnabledChanged", name, bagKind, enabled)
end

-- Check if category is enabled
-- @param name - Category name
-- @param bagKind - Bag type (BACKPACK or BANK)
-- @return enabled - Boolean
function ns.Components.Categories.IsCategoryEnabled(name, bagKind)
    if not categories[name] then return false end
    return categories[name].enabled[bagKind] == true
end

-- Register a function to automatically categorize items
-- Registered functions are called for items that don't have a category
-- Function should return category name or nil
-- @param functionID - Unique ID for this function
-- @param func - Function(itemData) -> categoryName or nil
function ns.Components.Categories.RegisterCategoryFunction(functionID, func)
    assert(not categoryFunctions[functionID], "Category function already registered: " .. functionID)

    categoryFunctions[functionID] = func

    -- Clear cache to reprocess items
    wipe(itemsWithNoCategory)
    wipe(itemToCategory)

    -- Notify listeners
    ns.Components.Events.SendMessage("Categories/FunctionRegistered", functionID)
end

-- Unregister a category function
-- @param functionID - Function ID to unregister
function ns.Components.Categories.UnregisterCategoryFunction(functionID)
    categoryFunctions[functionID] = nil

    -- Clear cache
    wipe(itemsWithNoCategory)
    wipe(itemToCategory)

    -- Notify listeners
    ns.Components.Events.SendMessage("Categories/FunctionUnregistered", functionID)
end

-- Group items by category
-- @param items - Table {slotKey = itemData}
-- @param bagKind - Bag type (BACKPACK or BANK)
-- @return groups - Table {categoryName = {slotKey = itemData}}
function ns.Components.Categories.GroupItemsByCategory(items, bagKind)
    local groups = {
        ["Uncategorized"] = {}
    }

    for slotKey, itemData in pairs(items) do
        if not itemData.isEmpty then
            local categoryName = ns.Components.Categories.GetCategory(itemData, bagKind)

            if categoryName then
                if not groups[categoryName] then
                    groups[categoryName] = {}
                end
                groups[categoryName][slotKey] = itemData
            else
                groups["Uncategorized"][slotKey] = itemData
            end
        end
    end

    -- Remove empty uncategorized group
    if not next(groups["Uncategorized"]) then
        groups["Uncategorized"] = nil
    end

    return groups
end

-- Get sorted list of categories by priority (highest first)
-- @return sorted - Array of {name, priority}
function ns.Components.Categories.GetSortedCategories()
    local sorted = {}

    for name, category in pairs(categories) do
        table.insert(sorted, {
            name = name,
            priority = category.priority or 10
        })
    end

    table.sort(sorted, function(a, b)
        return a.priority > b.priority
    end)

    return sorted
end

-- Clear all categories
function ns.Components.Categories.ClearAllCategories()
    wipe(categories)
    wipe(itemToCategory)
    wipe(itemsWithNoCategory)

    -- Notify listeners
    ns.Components.Events.SendMessage("Categories/Cleared")
end

-- Reprocess all items (clears cache, forces re-categorization)
function ns.Components.Categories.ReprocessAllItems()
    wipe(itemsWithNoCategory)
    wipe(itemToCategory)

    -- Notify listeners
    ns.Components.Events.SendMessage("Categories/Reprocessed")
end

-- Built-in categorization functions

-- Categorize by item quality
ns.Components.Categories.RegisterCategoryFunction("ByQuality", function(itemData)
    local const = getConst()
    if itemData.itemQuality and itemData.itemQuality >= const.ITEM_QUALITY.Epic then
        return "Epic & Legendary"
    end
    return nil
end)

-- Categorize consumables
ns.Components.Categories.RegisterCategoryFunction("Consumables", function(itemData)
    if itemData.classID == Enum.ItemClass.Consumable then
        return "Consumables"
    end
    return nil
end)

-- Categorize quest items
ns.Components.Categories.RegisterCategoryFunction("QuestItems", function(itemData)
    if itemData.isQuestItem then
        return "Quest Items"
    end
    return nil
end)

-- Categorize crafting reagents
ns.Components.Categories.RegisterCategoryFunction("Reagents", function(itemData)
    if itemData.isCraftingReagent then
        return "Reagents"
    end
    return nil
end)

-- Categorize by item type (fallback - simple type-based grouping)
ns.Components.Categories.RegisterCategoryFunction("ByType", function(itemData)
    -- Special case: Empty slot stack
    if itemData.isEmptySlotStack then
        return "Empty Slots"
    end

    -- Use itemType as category (Armor, Weapon, Quest, etc.)
    if itemData.itemType and itemData.itemType ~= "" then
        return itemData.itemType
    end

    return "Miscellaneous"
end)
