-- modules/bank.lua - Bank and guild bank management
local addonName, ns = ...

ns.Modules.Bank = {}

local eventFrame = nil
local isBankOpen = false
local isGuildBankOpen = false
local currentBankMode = "personal" -- "personal" or "guild"
local currentBankTab = 1
local bankCheckTimer = nil -- Timer to poll bank state

-- Initialize bank module
function ns.Modules.Bank.Initialize()
    -- Create event handler
    eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("BANKFRAME_OPENED")
    eventFrame:RegisterEvent("BANKFRAME_CLOSED")
    eventFrame:RegisterEvent("GUILDBANKFRAME_OPENED")
    eventFrame:RegisterEvent("GUILDBANKFRAME_CLOSED")
    eventFrame:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
    eventFrame:RegisterEvent("PLAYER_MONEY")
    -- Modern interaction events (more reliable)
    eventFrame:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
    eventFrame:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_HIDE")

    eventFrame:SetScript("OnEvent", function(self, event, ...)
        if event == "BANKFRAME_OPENED" then
            ns:Print("DEBUG: BANKFRAME_OPENED event")
            ns.Modules.Bank.OnBankOpened()
        elseif event == "BANKFRAME_CLOSED" then
            ns:Print("DEBUG: BANKFRAME_CLOSED event - calling OnBankClosed()")
            ns.Modules.Bank.OnBankClosed()
        elseif event == "GUILDBANKFRAME_OPENED" then
            ns:Print("DEBUG: GUILDBANKFRAME_OPENED event")
            ns.Modules.Bank.OnGuildBankOpened()
        elseif event == "GUILDBANKFRAME_CLOSED" then
            ns:Print("DEBUG: GUILDBANKFRAME_CLOSED event")
            ns.Modules.Bank.OnGuildBankClosed()
        elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then
            local interactionType = ...
            -- Banker = 8, GuildBanker = 10, AccountBanker = 66
            if interactionType == 8 then -- Enum.PlayerInteractionType.Banker
                ns.Modules.Bank.OnBankOpened()
            elseif interactionType == 10 then -- Enum.PlayerInteractionType.GuildBanker
                ns.Modules.Bank.OnGuildBankOpened()
            end
        elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" then
            local interactionType = ...
            -- Close bank when interaction ends
            if interactionType == 8 then -- Enum.PlayerInteractionType.Banker
                if isBankOpen then
                    ns.Modules.Bank.OnBankClosed()
                end
            elseif interactionType == 10 then -- Enum.PlayerInteractionType.GuildBanker
                if isGuildBankOpen then
                    ns.Modules.Bank.OnGuildBankClosed()
                end
            end
        elseif event == "PLAYERBANKSLOTS_CHANGED" then
            -- Only update if bank is actually open AND bankGrid exists
            -- Otherwise this fires too early before frame is ready
            if (isBankOpen or isGuildBankOpen) then
                local mainFrame = _G["NihuiIVFrame"]
                if mainFrame and mainFrame.bankGrid then
                    ns.Modules.Bank.UpdateBank()
                end
            end
        elseif event == "PLAYER_MONEY" then
            ns.Core.Frame.UpdateMoney()
        end
    end)

    -- BetterBags approach: Hide Blizzard frames by reparenting to a hidden frame
    -- This allows them to Show() (for WoW initialization) but remain invisible
    -- CRITICAL: This prevents CLOSED events from firing immediately
    local sneakyFrame = CreateFrame("Frame", "NihuiIVSneakyFrame")
    sneakyFrame:Hide()

    if BankFrame then
        -- Reparent to hidden frame (BetterBags method)
        BankFrame:SetParent(sneakyFrame)
        -- Clear scripts to prevent interference
        BankFrame:SetScript("OnHide", nil)
        BankFrame:SetScript("OnShow", nil)
        BankFrame:SetScript("OnEvent", nil)
    end

    if GuildBankFrame then
        -- Same for guild bank
        GuildBankFrame:SetParent(sneakyFrame)
        GuildBankFrame:SetScript("OnHide", nil)
        GuildBankFrame:SetScript("OnShow", nil)
        GuildBankFrame:SetScript("OnEvent", nil)
    end

    -- Hook CloseSpecialWindows (called when ESC is pressed)
    -- Call CloseBankFrame() to trigger proper BANKFRAME_CLOSED events (BetterBags approach)
    hooksecurefunc("CloseSpecialWindows", function()
        if isBankOpen or isGuildBankOpen then
            -- This will trigger BANKFRAME_CLOSED and PLAYER_INTERACTION_MANAGER_FRAME_HIDE
            if C_Bank and C_Bank.CloseBankFrame then
                C_Bank.CloseBankFrame()
            else
                CloseBankFrame()
            end
        end
    end)

    return true
end

-- Start polling bank state (checks if bank is still open)
local function StartBankPolling()
    if bankCheckTimer then
        bankCheckTimer:Cancel()
    end

    -- Check every 0.1 seconds if bank interaction is still active
    local function checkBankState()
        -- C_PlayerInteractionManager.IsInteractingWithNpcOfType checks if we're still at the banker
        local atBanker = C_PlayerInteractionManager and C_PlayerInteractionManager.IsInteractingWithNpcOfType
            and C_PlayerInteractionManager.IsInteractingWithNpcOfType(8) -- 8 = Banker
        local atGuildBanker = C_PlayerInteractionManager and C_PlayerInteractionManager.IsInteractingWithNpcOfType
            and C_PlayerInteractionManager.IsInteractingWithNpcOfType(10) -- 10 = GuildBanker

        -- If bank is marked open but we're not interacting anymore, close it
        if isBankOpen and not atBanker then
            ns:Print("DEBUG: Bank closed detected by polling")
            ns.Modules.Bank.OnBankClosed()
            return -- Stop polling
        end

        if isGuildBankOpen and not atGuildBanker then
            ns:Print("DEBUG: Guild bank closed detected by polling")
            ns.Modules.Bank.OnGuildBankClosed()
            return -- Stop polling
        end

        -- Continue polling if bank is still open
        if isBankOpen or isGuildBankOpen then
            bankCheckTimer = C_Timer.NewTimer(0.1, checkBankState)
        end
    end

    -- Start first check
    bankCheckTimer = C_Timer.NewTimer(0.1, checkBankState)
end

-- Bank opened (personal bank)
function ns.Modules.Bank.OnBankOpened()
    isBankOpen = true
    currentBankMode = "personal"

    -- Create frame if it doesn't exist
    if not ns.Core.Frame then
        ns:Print("ERROR: Core.Frame module not found!")
        isBankOpen = false
        return
    end

    -- IMPORTANT: Show() must be called BEFORE SetBankMode() to ensure frame exists
    -- Otherwise SetBankMode() will return early if mainFrame doesn't exist yet
    ns.Core.Frame.Show()

    -- Switch to bank mode (split view)
    ns.Core.Frame.SetBankMode(true)

    -- Start polling to detect when bank closes
    StartBankPolling()

    -- Force immediate update - bankGrid should exist now
    -- SetBankMode creates the split view and bankGrid synchronously
    local mainFrame = _G["NihuiIVFrame"]
    if mainFrame and mainFrame.bankGrid then
        ns:Print("DEBUG: Bank grid exists, calling UpdateBank() immediately")
        ns.Modules.Bank.UpdateBank()
    else
        ns:Print("ERROR: Bank grid does not exist after SetBankMode(true)!")
    end
end

-- Bank closed
function ns.Modules.Bank.OnBankClosed()
    isBankOpen = false

    -- Stop polling timer
    if bankCheckTimer then
        bankCheckTimer:Cancel()
        bankCheckTimer = nil
    end

    -- Switch back to normal mode
    ns.Core.Frame.SetBankMode(false)

    -- Hide frame
    ns.Core.Frame.Hide()
end

-- Guild bank opened
function ns.Modules.Bank.OnGuildBankOpened()
    isGuildBankOpen = true
    currentBankMode = "guild"

    -- IMPORTANT: Show() must be called BEFORE SetBankMode() to ensure frame exists
    ns.Core.Frame.Show()

    -- Switch to bank mode (split view)
    ns.Core.Frame.SetBankMode(true)

    -- Show guild bank tabs in sidebar
    if ns.UI.Sidebar and ns.UI.Sidebar.ShowBankTabs then
        ns.UI.Sidebar.ShowBankTabs()
    end

    -- Start polling to detect when guild bank closes
    StartBankPolling()

    -- Force immediate update - bankGrid should exist now
    local mainFrame = _G["NihuiIVFrame"]
    if mainFrame and mainFrame.bankGrid then
        ns:Print("DEBUG: Guild bank grid exists, calling UpdateBank() immediately")
        ns.Modules.Bank.UpdateBank()
    else
        ns:Print("ERROR: Guild bank grid does not exist after SetBankMode(true)!")
    end
end

-- Guild bank closed
function ns.Modules.Bank.OnGuildBankClosed()
    isGuildBankOpen = false

    -- Stop polling timer
    if bankCheckTimer then
        bankCheckTimer:Cancel()
        bankCheckTimer = nil
    end

    -- Hide bank tabs
    if ns.UI.Sidebar and ns.UI.Sidebar.HideBankTabs then
        ns.UI.Sidebar.HideBankTabs()
    end

    -- Switch back to normal mode
    ns.Core.Frame.SetBankMode(false)

    -- Hide frame
    ns.Core.Frame.Hide()
end

-- Get all bank items (for personal bank)
function ns.Modules.Bank.GetBankItems(tabIndex)
    local items = {}
    local totalSlots = 0
    local usedSlots = 0

    -- Bank bags (IDs: -1 = main bank, 5-11 = bank bags)
    local bags = {-1, 5, 6, 7, 8, 9, 10, 11}

    for _, bagID in ipairs(bags) do
        local numSlots = C_Container.GetContainerNumSlots(bagID)

        if numSlots and numSlots > 0 then
            totalSlots = totalSlots + numSlots

            for slotID = 1, numSlots do
                local info = C_Container.GetContainerItemInfo(bagID, slotID)

                if info then
                    usedSlots = usedSlots + 1
                end

                -- Add all slots (empty or not)
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

-- Get guild bank items
function ns.Modules.Bank.GetGuildBankItems(tabIndex)
    local items = {}
    local totalSlots = 98 -- Guild bank tabs have 98 slots (7 columns x 14 rows)
    local usedSlots = 0

    tabIndex = tabIndex or 1

    -- Check if guild bank is available
    if not isGuildBankOpen then
        return items, 0, 0
    end

    -- Query guild bank tab
    QueryGuildBankTab(tabIndex)

    for slotID = 1, totalSlots do
        local info = C_Container.GetContainerItemInfo(Enum.BagIndex.GuildBank, slotID)

        if info then
            usedSlots = usedSlots + 1
        end

        table.insert(items, {
            bagID = Enum.BagIndex.GuildBank,
            slotID = slotID,
            tabIndex = tabIndex,
            info = info,
            isEmpty = not info
        })
    end

    return items, usedSlots, totalSlots
end

-- Update bank display
function ns.Modules.Bank.UpdateBank(tabIndex)
    if not isBankOpen and not isGuildBankOpen then
        return
    end

    local items, usedSlots, totalSlots

    if currentBankMode == "personal" then
        items, usedSlots, totalSlots = ns.Modules.Bank.GetBankItems(tabIndex)
        ns:Print(string.format("DEBUG: GetBankItems() returned %d items, %d/%d slots", #items, usedSlots, totalSlots))

        -- Count non-empty items
        local nonEmptyCount = 0
        for _, item in ipairs(items) do
            if item.info then
                nonEmptyCount = nonEmptyCount + 1
            end
        end
        ns:Print(string.format("DEBUG: %d items have info (non-empty)", nonEmptyCount))

    elseif currentBankMode == "guild" then
        items, usedSlots, totalSlots = ns.Modules.Bank.GetGuildBankItems(tabIndex or currentBankTab)
        ns:Print(string.format("DEBUG: GetGuildBankItems() returned %d items, %d/%d slots", #items, usedSlots, totalSlots))

        -- Count non-empty items
        local nonEmptyCount = 0
        for _, item in ipairs(items) do
            if item.info then
                nonEmptyCount = nonEmptyCount + 1
            end
        end
        ns:Print(string.format("DEBUG: %d items have info (non-empty)", nonEmptyCount))
    end

    -- Update split view left pane with bank items
    local mainFrame = _G["NihuiIVFrame"]
    if not mainFrame or not mainFrame.bankGrid then
        ns:Print("DEBUG: mainFrame or bankGrid not found!")
        return
    end

    ns:Print(string.format("DEBUG: mainFrame.bankGrid exists: %s", tostring(mainFrame.bankGrid ~= nil)))
    ns:Print(string.format("DEBUG: Calling CreateGrid with %d items on bankGrid", #items))
    ns.UI.Slots.CreateGrid(mainFrame.bankGrid, items)
    ns:Print("DEBUG: CreateGrid returned")

    -- Update inventory in right pane
    if ns.Modules.Inventory and ns.Modules.Inventory.UpdateInventory then
        ns.Modules.Inventory.UpdateInventory()
    end
end

-- Switch bank mode (personal <-> guild)
function ns.Modules.Bank.SwitchBankMode(mode)
    if mode ~= "personal" and mode ~= "guild" then
        return
    end

    currentBankMode = mode

    -- Show/hide bank tabs in sidebar based on mode
    if mode == "guild" then
        if ns.UI.Sidebar and ns.UI.Sidebar.ShowBankTabs then
            ns.UI.Sidebar.ShowBankTabs()
        end
    else
        if ns.UI.Sidebar and ns.UI.Sidebar.HideBankTabs then
            ns.UI.Sidebar.HideBankTabs()
        end
    end

    ns.Modules.Bank.UpdateBank()
end

-- Select bank tab (for guild bank)
function ns.Modules.Bank.SelectBankTab(tabIndex)
    currentBankTab = tabIndex
    ns.Modules.Bank.UpdateBank(tabIndex)
end

-- Get current bank mode
function ns.Modules.Bank.GetBankMode()
    return currentBankMode
end

-- Check if bank is open
function ns.Modules.Bank.IsBankOpen()
    return isBankOpen or isGuildBankOpen
end

-- Cleanup
function ns.Modules.Bank.Destroy()
    -- Cancel polling timer
    if bankCheckTimer then
        bankCheckTimer:Cancel()
        bankCheckTimer = nil
    end

    if eventFrame then
        eventFrame:UnregisterAllEvents()
        eventFrame:SetScript("OnEvent", nil)
    end
end
