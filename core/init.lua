-- core/init.lua - Addon initialization with component-based architecture
local addonName, ns = ...

-- Create namespace tables
ns.Components = ns.Components or {}
ns.Layouts = ns.Layouts or {}
ns.version = "0.2.0"
ns.db = nil

-- Print helper
function ns:Print(...)
    print("|cff9482c9Nihui IV:|r", ...)
end

-- Initialize addon
local function OnAddonLoaded(self, event, loadedAddonName)
    if loadedAddonName ~= addonName then
        return
    end

    ns:Print("Loading...")

    -- Initialize SavedVariables with defaults
    NihuiIVDB = NihuiIVDB or {}

    -- Apply default values for missing keys
    if ns.Config and ns.Config.defaults then
        for key, value in pairs(ns.Config.defaults.profile) do
            if NihuiIVDB[key] == nil then
                NihuiIVDB[key] = value
            end
        end
    end

    ns.db = NihuiIVDB

    -- Check if components are loaded
    if not ns.Components then
        ns:Print("|cffff0000ERROR: Components not loaded!|r")
        return
    end

    if not ns.Components.Bags or not ns.Components.Items then
        ns:Print("|cffff0000ERROR: Core components missing!|r")
        return
    end

    ns:Print("Initializing components...")

    -- 1. Initialize bag hooks (hides Blizzard bags)
    ns.Components.Bags.Initialize()

    -- 2. Initialize items system (events)
    ns.Components.Items.Initialize()

    -- 2.5. Initialize cache system (character inventory caching)
    if ns.Components.Cache then
        ns.Components.Cache.Initialize()
    end

    -- 3. Initialize backpack layout
    ns.Layouts.Backpack.Initialize()

    -- 4. Initialize bank layout
    ns.Layouts.Bank.Initialize()

    -- Wire bags component to backpack layout
    ns.Components.Bags.SetToggleBagsCallback(function()
        ns.Layouts.Backpack.Toggle()
    end)

    ns.Components.Bags.SetCloseBagsCallback(function()
        ns.Layouts.Backpack.Hide()
    end)

    -- Wire interaction callbacks (bank)
    ns.Components.Bags.SetOpenInteractionCallback(function(interactionType)
        -- Banker or GuildBanker should open bank
        if interactionType == Enum.PlayerInteractionType.Banker or
           interactionType == Enum.PlayerInteractionType.GuildBanker then
            ns.Layouts.Bank.Show()
        end
    end)

    ns.Components.Bags.SetCloseInteractionCallback(function(interactionType)
        if interactionType == Enum.PlayerInteractionType.Banker or
           interactionType == Enum.PlayerInteractionType.GuildBanker then
            ns.Layouts.Bank.Hide()
        end
    end)

    -- ESC key handling: We use OnKeyDown to intercept BEFORE WoW processes it
    -- This allows us to implement custom behavior (preview mode) without conflicts
    ns.Layouts.Backpack.SetEscapeHandler(function()
        if ns.Layouts.Backpack.IsViewingOther() then
            -- First ESC in preview mode: return to current character
            ns.Layouts.Backpack.ReturnToCurrent()
            return true  -- Handled, stop propagation
        else
            -- Second ESC (or first in normal mode): close the backpack
            ns.Layouts.Backpack.Hide()
            return true  -- Handled, stop propagation
        end
    end)

    ns.Layouts.Bank.SetEscapeHandler(function()
        if ns.Layouts.Bank.IsViewingOther() then
            -- First ESC in preview mode: return to current character
            ns.Layouts.Bank.ReturnToCurrent()
            return true  -- Handled, stop propagation
        else
            -- Second ESC (or first in normal mode): close the bank
            ns.Layouts.Bank.Hide()
            return true  -- Handled, stop propagation
        end
    end)

    -- Register slash commands
    SLASH_NIHUIIV1 = "/iv"
    SLASH_NIHUIIV2 = "/nihui_iv"
    SlashCmdList["NIHUIIV"] = function(msg)
        if msg == "test" then
            ns:Print("Backpack test - Opening backpack...")
            ns.Layouts.Backpack.Show()
        elseif msg == "reset" then
            ns:Print("Resetting backpack frame...")
            if ns.Layouts.Backpack then
                ns.Layouts.Backpack.Destroy()
            end
            ns:Print("Done! Do /reload to recreate the frame")
        elseif msg == "view" or msg == "toggle" then
            ns:Print("Toggling view mode...")
            ns.Layouts.Backpack.ToggleViewMode()
        elseif msg == "view all" or msg == "all" then
            ns:Print("Setting view to: All in one")
            ns.Layouts.Backpack.SetViewMode("all")
        elseif msg == "view category" or msg == "category" then
            ns:Print("Setting view to: By category")
            ns.Layouts.Backpack.SetViewMode("category")
        elseif msg == "bank" then
            ns:Print("Opening bank...")
            ns.Layouts.Bank.Show()
        elseif msg == "bank view" then
            ns:Print("Toggling bank view mode...")
            ns.Layouts.Bank.ToggleBankView()
        elseif msg == "options" or msg == "config" then
            ns:Print("Opening options...")
            -- Open backpack first if closed
            if not ns.Layouts.Backpack.IsShown() then
                ns.Layouts.Backpack.Show()
            end
            -- Then show options
            if ns.Layouts.Backpack.ShowOptions then
                ns.Layouts.Backpack.ShowOptions()
            end
        else
            ns:Print("Commands:")
            ns:Print("  /iv test - Open backpack")
            ns:Print("  /iv reset - Reset backpack frame (requires /reload after)")
            ns:Print("  /iv view - Toggle between all/category view")
            ns:Print("  /iv view all - Set all-in-one view")
            ns:Print("  /iv view category - Set category view")
            ns:Print("  /iv bank - Open bank")
            ns:Print("  /iv bank view - Toggle bank view mode")
            ns:Print("  /iv options - Open options panel")
            ns:Print("  Press B or click bag icon to toggle backpack")
        end
    end

    ns:Print("|cff00ff00Loaded successfully!|r Press B to open backpack")
end

-- Register events
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", OnAddonLoaded)
