-- modules/inventory.lua - Inventory management logic
local addonName, ns = ...

ns.Modules.Inventory = {}

local eventFrame = nil
local currentFilter = ""
local allItems = {}
local updateTimer = nil -- Debounce timer for BAG_UPDATE

-- Initialize inventory module
function ns.Modules.Inventory.Initialize()
    -- Create frame
    ns.Core.Frame.Create()

    -- Create event handler
    eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("BAG_UPDATE")
    eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
    eventFrame:RegisterEvent("PLAYER_MONEY")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

    eventFrame:SetScript("OnEvent", function(self, event, ...)
        if event == "BAG_UPDATE" or event == "BAG_UPDATE_DELAYED" then
            -- Debounce: cancel previous timer and create new one
            if updateTimer then
                updateTimer:Cancel()
            end
            updateTimer = C_Timer.NewTimer(0.05, function()
                ns.Modules.Inventory.UpdateInventory()
                updateTimer = nil
            end)
        elseif event == "PLAYER_MONEY" then
            ns.Core.Frame.UpdateMoney()
        elseif event == "PLAYER_ENTERING_WORLD" then
            ns.Modules.Inventory.UpdateInventory()
            ns.Core.Frame.UpdateMoney()
        end
    end)

    -- Hook bag toggle (B key by default)
    hooksecurefunc("ToggleAllBags", function()
        -- Don't interfere with bank mode
        if ns.Modules.Bank and ns.Modules.Bank.IsBankOpen() then
            return
        end

        -- Toggle our frame
        ns.Core.Frame.Toggle()
    end)

    hooksecurefunc("OpenAllBags", function(frame, forceOpen)
        -- Don't interfere with bank mode
        if ns.Modules.Bank and ns.Modules.Bank.IsBankOpen() then
            return
        end

        -- Show our frame
        ns.Core.Frame.Show()
    end)

    hooksecurefunc("CloseAllBags", function(frame, forceClose)
        -- Don't interfere with bank mode
        if ns.Modules.Bank and ns.Modules.Bank.IsBankOpen() then
            return
        end

        -- Hide our frame
        ns.Core.Frame.Hide()
    end)

    -- Hook individual bag toggles (for bag button clicks)
    hooksecurefunc("ToggleBag", function(bagID)
        -- Don't interfere with bank mode
        if ns.Modules.Bank and ns.Modules.Bank.IsBankOpen() then
            return
        end

        -- Toggle our frame when any bag is toggled
        ns.Core.Frame.Toggle()
    end)

    -- Hook backpack toggle specifically
    hooksecurefunc("ToggleBackpack", function()
        -- Don't interfere with bank mode
        if ns.Modules.Bank and ns.Modules.Bank.IsBankOpen() then
            return
        end

        -- Toggle our frame
        ns.Core.Frame.Toggle()
    end)

    -- Hide default bag frames (delayed to ensure they exist)
    C_Timer.After(0.5, function()
        if ContainerFrameCombinedBags then
            ContainerFrameCombinedBags:SetScript("OnShow", function(self)
                self:Hide()
            end)
            ContainerFrameCombinedBags:Hide()
        end

        -- Hide individual bag frames
        for i = 1, 13 do
            local bagFrame = _G["ContainerFrame" .. i]
            if bagFrame then
                bagFrame:SetScript("OnShow", function(self)
                    self:Hide()
                end)
                bagFrame:Hide()
            end
        end
    end)

    -- Slash command
    SLASH_NIHUIIV1 = "/iv"
    SLASH_NIHUIIV2 = "/nihui_iv"
    SlashCmdList["NIHUIIV"] = function(msg)
        if msg == "show" then
            ns.Core.Frame.Show()
        elseif msg == "hide" then
            ns.Core.Frame.Hide()
        elseif msg == "reload" then
            ns.Modules.Inventory.UpdateInventory()
            ns:Print("Inventory reloaded")
        else
            ns.Core.Frame.Toggle()
        end
    end
end

-- Get all items from bags (optional bagID filter)
function ns.Modules.Inventory.GetAllItems(filterBagID)
    local items = {}
    local totalSlots = 0
    local usedSlots = 0

    -- Determine which bags to iterate
    local startBag, endBag
    if filterBagID ~= nil then
        -- Filter specific bag
        startBag = filterBagID
        endBag = filterBagID
    else
        -- All bags (0 = backpack, 1-4 = bags)
        startBag = 0
        endBag = 4
    end

    -- Iterate through bags
    for bagID = startBag, endBag do
        local numSlots = C_Container.GetContainerNumSlots(bagID)

        if numSlots and numSlots > 0 then
            totalSlots = totalSlots + numSlots

            for slotID = 1, numSlots do
                local info = C_Container.GetContainerItemInfo(bagID, slotID)

                if info then
                    usedSlots = usedSlots + 1
                end

                -- Add all slots (empty or not) to maintain grid layout
                table.insert(items, {
                    bagID = bagID,
                    slotID = slotID,
                    info = info,
                    isEmpty = not info
                })
            end
        end
    end

    return items, usedSlots, totalSlots
end

-- Filter items based on search text
function ns.Modules.Inventory.FilterItems(searchText)
    currentFilter = searchText and searchText:lower() or ""

    -- Re-update with current filter
    ns.Modules.Inventory.UpdateInventory()
end

-- Update the inventory display (optional bagID filter from sidebar)
function ns.Modules.Inventory.UpdateInventory(filterBagID)
    -- Get active bag filter from sidebar if not provided
    if filterBagID == nil and ns.UI.Sidebar and ns.UI.Sidebar.GetActiveBag then
        filterBagID = ns.UI.Sidebar.GetActiveBag()
    end

    -- Get items (with optional bag filter)
    local items, usedSlots, totalSlots = ns.Modules.Inventory.GetAllItems(filterBagID)

    -- If filtering by bag, fade items from other bags
    if filterBagID ~= nil then
        for _, itemData in ipairs(items) do
            if itemData.bagID == filterBagID then
                itemData.alpha = 1.0
            else
                itemData.alpha = 0.3 -- Fade items from other bags
            end
        end
    end

    -- Apply search filter if active
    if currentFilter and currentFilter ~= "" then
        local filteredItems = {}

        for _, itemData in ipairs(items) do
            if itemData.info then
                local itemName = C_Item.GetItemNameByID(itemData.info.itemID)

                if itemName and itemName:lower():find(currentFilter, 1, true) then
                    table.insert(filteredItems, itemData)
                    itemData.alpha = (itemData.alpha or 1.0) -- Keep existing alpha or 1.0
                else
                    table.insert(filteredItems, itemData)
                    itemData.alpha = 0.3 -- Fade non-matching items
                end
            else
                -- Keep empty slots
                table.insert(filteredItems, itemData)
            end
        end

        items = filteredItems
    end

    -- Store for reference
    allItems = items

    -- Update UI
    ns.Core.Frame.UpdateCount(usedSlots, totalSlots)

    -- Update grid
    local mainFrame = _G["NihuiIVFrame"]
    if mainFrame and mainFrame.itemGrid then
        ns.UI.Slots.CreateGrid(mainFrame.itemGrid, items)
    end
end

-- Get item at specific bag/slot
function ns.Modules.Inventory.GetItem(bagID, slotID)
    for _, item in ipairs(allItems) do
        if item.bagID == bagID and item.slotID == slotID then
            return item
        end
    end
    return nil
end

-- Cleanup
function ns.Modules.Inventory.Destroy()
    -- Cancel pending update timer
    if updateTimer then
        updateTimer:Cancel()
        updateTimer = nil
    end

    if eventFrame then
        eventFrame:UnregisterAllEvents()
        eventFrame:SetScript("OnEvent", nil)
    end

    -- Clean up all slots
    if ns.UI.Slots and ns.UI.Slots.Cleanup then
        ns.UI.Slots.Cleanup()
    end
end
