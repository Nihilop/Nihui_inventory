-- config/defaults.lua - Default configuration values
local addonName, ns = ...

ns.Config = ns.Config or {}

-- Default database structure
ns.Config.defaults = {
    profile = {
        -- View modes
        backpackViewMode = "category",  -- "category" or "all"
        bankViewMode = "category",      -- "category" or "all"

        -- Auto-sort (middle-click, only in "all" view)
        enableAutoSort = true,
        sortType = "quality",  -- "quality", "name", "ilvl", "type"

        -- UI Settings (SEPARATE for backpack and bank)
        backpackShowEmptySlots = true,  -- Show empty slot stack in backpack
        bankShowEmptySlots = true,       -- Show empty slot stack in bank
        showBigHeader = true,            -- Show decorative big header on both
        compactMode = false,

        -- Icon size settings (SEPARATE for backpack and bank)
        backpackIconSize = 54,           -- Icon size in pixels for backpack (default: 37)
        bankIconSize = 48,               -- Icon size in pixels for bank (default: 37)
    }
}

-- Get default value
function ns.Config.GetDefault(key)
    return ns.Config.defaults.profile[key]
end
