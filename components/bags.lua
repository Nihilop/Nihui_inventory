-- components/bags.lua - Bag management component (pure logic, no layout)
-- Extracted from BetterBags - handles bag opening/closing and Blizzard hooks
local addonName, ns = ...

ns.Components = ns.Components or {}
ns.Components.Bags = {}

local sneakyFrame = nil
local hooks = {}
local callbacks = {
    onToggleBags = nil,
    onOpenInteraction = nil,
    onCloseInteraction = nil,
}

-- Interaction events that should auto-open bags
local INTERACTION_EVENTS = {
    [Enum.PlayerInteractionType.TradePartner] = true,
    [Enum.PlayerInteractionType.Banker] = true,
    [Enum.PlayerInteractionType.Merchant] = true,
    [Enum.PlayerInteractionType.MailInfo] = true,
    [Enum.PlayerInteractionType.Auctioneer] = true,
    [Enum.PlayerInteractionType.GuildBanker] = true,
    [Enum.PlayerInteractionType.VoidStorageBanker] = true,
    [Enum.PlayerInteractionType.ScrappingMachine] = true,
    [Enum.PlayerInteractionType.ItemUpgrade] = true,
}

-- Add retail-only interactions
if Enum.PlayerInteractionType.AccountBanker then
    INTERACTION_EVENTS[Enum.PlayerInteractionType.AccountBanker] = true
end

-- Hide Blizzard bag frames by reparenting to hidden frame
function ns.Components.Bags.HideBlizzardBags()
    -- Create sneaky frame (exactly like BetterBags does)
    if not sneakyFrame then
        sneakyFrame = CreateFrame("Frame", addonName .. "SneakyFrame")
        sneakyFrame:Hide()
    end

    -- Reparent combined bags frame
    if ContainerFrameCombinedBags then
        ContainerFrameCombinedBags:SetParent(sneakyFrame)
        ContainerFrameCombinedBags:Hide()
    end

    -- Reparent individual bag frames (1-13)
    for i = 1, 13 do
        local bagFrame = _G["ContainerFrame" .. i]
        if bagFrame then
            bagFrame:SetParent(sneakyFrame)
            bagFrame:Hide()
        end
    end

    -- Hide Blizzard bag bar (the row of bag icons at bottom right)
    if BagBarFrame then
        BagBarFrame:SetParent(sneakyFrame)
        BagBarFrame:Hide()
    end

    -- Hide the backpack key ring button area
    if BackpackTokenFrame then
        BackpackTokenFrame:SetParent(sneakyFrame)
        BackpackTokenFrame:Hide()
    end

    -- Override backpack button click
    -- Note: We can't use SetScript on secure buttons, so we use the ToggleAllBags hook instead
    -- But we can hide the button's default behavior by making bags invisible

    -- Hide bank frame
    if BankFrame then
        BankFrame:SetParent(sneakyFrame)
        BankFrame:Hide()
        -- Removed SetScript(nil) calls to avoid taint issues
    end
end

-- Show Blizzard bag frames (restore original behavior)
function ns.Components.Bags.ShowBlizzardBags()
    if not sneakyFrame then return end

    -- Restore to UIParent
    if ContainerFrameCombinedBags then
        ContainerFrameCombinedBags:SetParent(UIParent)
    end

    for i = 1, 13 do
        local bagFrame = _G["ContainerFrame" .. i]
        if bagFrame then
            bagFrame:SetParent(UIParent)
        end
    end

    if BankFrame then
        BankFrame:SetParent(UIParent)
    end
end

-- Toggle bags open/closed
function ns.Components.Bags.ToggleBags()
    if callbacks.onToggleBags then
        -- Wrap in pcall to prevent errors from breaking the bag toggle
        local success, err = pcall(callbacks.onToggleBags)
        if not success then
            print("|cFFFF0000[Nihui_iv]|r Error toggling bags:", err)
        end
    else
        -- Callback not set yet - addon might not be fully loaded
        print("|cFFFFAA00[Nihui_iv]|r Bags not ready yet, try again in a moment")
    end
end

-- Handle player interaction opening (merchant, bank, etc.)
local function OnPlayerInteractionShow(event, interactionType)
    if not INTERACTION_EVENTS[interactionType] then return end

    if callbacks.onOpenInteraction then
        callbacks.onOpenInteraction(interactionType)
    end
end

-- Handle player interaction closing
local function OnPlayerInteractionHide(event, interactionType)
    if not INTERACTION_EVENTS[interactionType] then return end

    if callbacks.onCloseInteraction then
        callbacks.onCloseInteraction(interactionType)
    end
end

-- Hook global ToggleAllBags function (called when pressing B key)
local function HookToggleAllBags()
    if hooks.toggleAllBags then return end

    hooksecurefunc("ToggleAllBags", function()
        -- Close Blizzard bags immediately
        ns.Components.Bags.CloseBlizzardBags()

        -- Open our custom bags
        ns.Components.Bags.ToggleBags()
    end)

    hooks.toggleAllBags = true
end

-- Force close all Blizzard bag frames
function ns.Components.Bags.CloseBlizzardBags()
    -- Wrap in pcall to prevent errors from breaking bag operations
    pcall(function()
        -- Close combined bags
        if ContainerFrameCombinedBags and ContainerFrameCombinedBags:IsShown() then
            ContainerFrameCombinedBags:Hide()
        end

        -- Close individual bag frames
        for i = 1, 13 do
            local bagFrame = _G["ContainerFrame" .. i]
            if bagFrame and bagFrame:IsShown() then
                bagFrame:Hide()
            end
        end
    end)
end

-- Hook CloseSpecialWindows (called when pressing Escape)
local function HookCloseSpecialWindows()
    if hooks.closeSpecialWindows then return end

    hooksecurefunc("CloseSpecialWindows", function()
        if callbacks.onCloseBags then
            callbacks.onCloseBags()
        end
    end)

    hooks.closeSpecialWindows = true
end

-- Initialize bag hooks
function ns.Components.Bags.Initialize()
    -- Hide Blizzard bags immediately
    ns.Components.Bags.HideBlizzardBags()

    -- Use OnShow hooks instead of OnUpdate to prevent taint (event-driven approach)
    -- This only fires when Blizzard tries to show frames, not every frame
    local function HideBlizzardFrame(frame)
        if frame then
            frame:Hide()
        end
    end

    -- Hook OnShow for combined bags
    if ContainerFrameCombinedBags then
        ContainerFrameCombinedBags:HookScript("OnShow", function(self)
            HideBlizzardFrame(self)
        end)
    end

    -- Hook OnShow for individual bag frames
    for i = 1, 13 do
        local bagFrame = _G["ContainerFrame" .. i]
        if bagFrame then
            bagFrame:HookScript("OnShow", function(self)
                HideBlizzardFrame(self)
            end)
        end
    end

    -- Hook OnShow for bag bar
    if BagBarFrame then
        BagBarFrame:HookScript("OnShow", function(self)
            HideBlizzardFrame(self)
        end)
    end

    -- Hook ToggleAllBags
    HookToggleAllBags()

    -- Hook OpenAllBags
    hooksecurefunc("OpenAllBags", function()
        ns.Components.Bags.CloseBlizzardBags()
        -- Don't call ToggleBags here, ToggleAllBags will handle it
    end)

    -- Hook CloseAllBags
    hooksecurefunc("CloseAllBags", function()
        ns.Components.Bags.CloseBlizzardBags()
        if callbacks.onCloseBags then
            callbacks.onCloseBags()
        end
    end)

    -- Hook CloseSpecialWindows
    HookCloseSpecialWindows()

    -- Register interaction events
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
    eventFrame:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_HIDE")
    eventFrame:SetScript("OnEvent", function(self, event, ...)
        if event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then
            local interactionType = ...
            OnPlayerInteractionShow(event, interactionType)
        elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" then
            local interactionType = ...
            OnPlayerInteractionHide(event, interactionType)
        end
    end)

    hooks.eventFrame = eventFrame
end

-- Set callback for toggle bags
function ns.Components.Bags.SetToggleBagsCallback(callback)
    callbacks.onToggleBags = callback
end

-- Set callback for open interaction
function ns.Components.Bags.SetOpenInteractionCallback(callback)
    callbacks.onOpenInteraction = callback
end

-- Set callback for close interaction
function ns.Components.Bags.SetCloseInteractionCallback(callback)
    callbacks.onCloseInteraction = callback
end

-- Set callback for close bags
function ns.Components.Bags.SetCloseBagsCallback(callback)
    callbacks.onCloseBags = callback
end

-- Clean up hooks
function ns.Components.Bags.Destroy()
    if hooks.eventFrame then
        hooks.eventFrame:UnregisterAllEvents()
        hooks.eventFrame:SetScript("OnEvent", nil)
    end

    -- Clear callbacks
    callbacks = {
        onToggleBags = nil,
        onOpenInteraction = nil,
        onCloseInteraction = nil,
        onCloseBags = nil,
    }

    hooks = {}
end
