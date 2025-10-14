-- modules/sort.lua - Custom sorting algorithms
local addonName, ns = ...

ns.Modules.Sort = {}

-- Sort items by name (alphabetical A-Z)
function ns.Modules.Sort.ByName(items)
    table.sort(items, function(a, b)
        if a.isEmpty and b.isEmpty then return false end
        if a.isEmpty then return false end
        if b.isEmpty then return true end

        local nameA = C_Item.GetItemNameByID(a.info.itemID) or ""
        local nameB = C_Item.GetItemNameByID(b.info.itemID) or ""

        return nameA < nameB
    end)
end

-- Sort items by quality (highest quality first)
function ns.Modules.Sort.ByQuality(items)
    table.sort(items, function(a, b)
        if a.isEmpty and b.isEmpty then return false end
        if a.isEmpty then return false end
        if b.isEmpty then return true end

        local qualityA = a.info.quality or 0
        local qualityB = b.info.quality or 0

        -- If same quality, sort by name
        if qualityA == qualityB then
            local nameA = C_Item.GetItemNameByID(a.info.itemID) or ""
            local nameB = C_Item.GetItemNameByID(b.info.itemID) or ""
            return nameA < nameB
        end

        return qualityA > qualityB -- Descending (highest first)
    end)
end

-- Sort items by item level (highest ilvl first)
function ns.Modules.Sort.ByItemLevel(items)
    table.sort(items, function(a, b)
        if a.isEmpty and b.isEmpty then return false end
        if a.isEmpty then return false end
        if b.isEmpty then return true end

        -- Get item level
        local itemLinkA = C_Container.GetContainerItemLink(a.bagID, a.slotID)
        local itemLinkB = C_Container.GetContainerItemLink(b.bagID, b.slotID)

        local ilvlA = 0
        local ilvlB = 0

        if itemLinkA then
            local effectiveLevel, _, _ = C_Item.GetDetailedItemLevelInfo(itemLinkA)
            ilvlA = effectiveLevel or 0
        end

        if itemLinkB then
            local effectiveLevel, _, _ = C_Item.GetDetailedItemLevelInfo(itemLinkB)
            ilvlB = effectiveLevel or 0
        end

        -- If same ilvl, sort by quality
        if ilvlA == ilvlB then
            local qualityA = a.info.quality or 0
            local qualityB = b.info.quality or 0
            return qualityA > qualityB
        end

        return ilvlA > ilvlB -- Descending (highest first)
    end)
end

-- Sort items by type (Armor, Weapon, Consumable, etc.)
function ns.Modules.Sort.ByType(items)
    -- Type priority order
    local typePriority = {
        ["Armor"] = 1,
        ["Weapon"] = 2,
        ["Consumable"] = 3,
        ["Trade Goods"] = 4,
        ["Quest"] = 5,
        ["Reagent"] = 6,
        ["Miscellaneous"] = 7,
        ["Container"] = 8,
    }

    table.sort(items, function(a, b)
        if a.isEmpty and b.isEmpty then return false end
        if a.isEmpty then return false end
        if b.isEmpty then return true end

        -- Get item type
        local itemLinkA = C_Container.GetContainerItemLink(a.bagID, a.slotID)
        local itemLinkB = C_Container.GetContainerItemLink(b.bagID, b.slotID)

        local typeA, subTypeA = select(6, C_Item.GetItemInfoInstant(a.info.itemID))
        local typeB, subTypeB = select(6, C_Item.GetItemInfoInstant(b.info.itemID))

        typeA = typeA or "Miscellaneous"
        typeB = typeB or "Miscellaneous"

        local priorityA = typePriority[typeA] or 99
        local priorityB = typePriority[typeB] or 99

        -- If same type, sort by subtype
        if priorityA == priorityB then
            if subTypeA == subTypeB then
                -- If same subtype, sort by quality
                local qualityA = a.info.quality or 0
                local qualityB = b.info.quality or 0
                return qualityA > qualityB
            end
            return (subTypeA or "") < (subTypeB or "")
        end

        return priorityA < priorityB
    end)
end

-- Sort items by vendor price (highest value first)
function ns.Modules.Sort.ByValue(items)
    table.sort(items, function(a, b)
        if a.isEmpty and b.isEmpty then return false end
        if a.isEmpty then return false end
        if b.isEmpty then return true end

        -- Get vendor price
        local itemLinkA = C_Container.GetContainerItemLink(a.bagID, a.slotID)
        local itemLinkB = C_Container.GetContainerItemLink(b.bagID, b.slotID)

        local priceA = 0
        local priceB = 0

        if itemLinkA then
            priceA = select(11, C_Item.GetItemInfo(itemLinkA)) or 0
        end

        if itemLinkB then
            priceB = select(11, C_Item.GetItemInfo(itemLinkB)) or 0
        end

        -- Account for stack size
        priceA = priceA * (a.info.stackCount or 1)
        priceB = priceB * (b.info.stackCount or 1)

        -- If same price, sort by quality
        if priceA == priceB then
            local qualityA = a.info.quality or 0
            local qualityB = b.info.quality or 0
            return qualityA > qualityB
        end

        return priceA > priceB -- Descending (highest first)
    end)
end

-- Sort items using Blizzard default
function ns.Modules.Sort.Default()
    -- Use Blizzard's built-in sort
    C_Container.SortBags()
end

-- Main sort function (uses ns.db.sortType)
function ns.Modules.Sort.SortInventory()
    local sortType = (ns.db and ns.db.sortType) or "default"

    if sortType == "default" then
        -- Use Blizzard sort
        ns.Modules.Sort.Default()
        return
    end

    -- Get all items
    local items, usedSlots, totalSlots = ns.Modules.Inventory.GetAllItems()

    if not items or #items == 0 then
        return
    end

    -- Sort items based on type
    if sortType == "name" then
        ns.Modules.Sort.ByName(items)
    elseif sortType == "quality" then
        ns.Modules.Sort.ByQuality(items)
    elseif sortType == "ilvl" then
        ns.Modules.Sort.ByItemLevel(items)
    elseif sortType == "type" then
        ns.Modules.Sort.ByType(items)
    elseif sortType == "value" then
        ns.Modules.Sort.ByValue(items)
    else
        ns:Print("Unknown sort type: " .. sortType)
        return
    end

    -- Now we need to physically move items to match the sorted order
    -- This is complex - we'll need to use C_Container.PickupContainerItem
    -- For now, just update the display with sorted order
    ns:Print("Sorting by " .. sortType .. "...")

    -- Update UI with sorted items
    local mainFrame = _G["NihuiIVFrame"]
    if mainFrame and mainFrame.itemGrid then
        ns.UI.Slots.CreateGrid(mainFrame.itemGrid, items)
    end
end
