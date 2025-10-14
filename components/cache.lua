-- components/cache.lua - Inventory caching system for cross-character viewing
local addonName, ns = ...

ns.Components = ns.Components or {}
ns.Components.Cache = {}

-- Get current character key (Realm-Name format)
local function GetCurrentCharacterKey()
    local name = UnitName("player")
    local realm = GetRealmName()
    return realm .. "-" .. name
end

-- Get current character info for display
local function GetCurrentCharacterInfo()
    local name = UnitName("player")
    local realm = GetRealmName()
    local _, className = UnitClass("player")
    local level = UnitLevel("player")
    local factionGroup = UnitFactionGroup("player")

    return {
        name = name,
        realm = realm,
        class = className,
        level = level,
        faction = factionGroup,
        key = GetCurrentCharacterKey()
    }
end

-- Save item data (compact format to reduce SavedVariables size)
local function SerializeItem(itemData)
    if not itemData or itemData.isEmpty then
        return nil
    end

    return {
        id = itemData.itemID,           -- Item ID
        link = itemData.itemLink,       -- Item link
        tex = itemData.itemTexture,     -- Texture path
        count = itemData.currentItemCount or 1,
        quality = itemData.itemQuality,
        bagID = itemData.bagID,
        slotID = itemData.slotID,
        name = itemData.itemName,
        type = itemData.itemType,
        subType = itemData.itemSubType,
        stackCount = itemData.itemStackCount,
        equipLoc = itemData.itemEquipLoc,
        isBound = itemData.isSoulbound,
    }
end

-- Deserialize item data back to our format
local function DeserializeItem(cachedItem, bagID, slotID)
    if not cachedItem then
        return nil
    end

    return {
        itemID = cachedItem.id,
        itemLink = cachedItem.link,
        itemTexture = cachedItem.tex,
        currentItemCount = cachedItem.count or 1,
        itemQuality = cachedItem.quality,
        bagID = bagID,
        slotID = slotID,
        slotKey = bagID .. "_" .. slotID,
        itemName = cachedItem.name,
        itemType = cachedItem.type,
        itemSubType = cachedItem.subType,
        itemStackCount = cachedItem.stackCount,
        itemEquipLoc = cachedItem.equipLoc,
        isSoulbound = cachedItem.isBound,
        isEmpty = false,
        isCached = true,  -- Flag to indicate this is from cache
    }
end

-- Save current character's inventory to cache
function ns.Components.Cache.UpdateCache()
    if not NihuiIVDB then
        NihuiIVDB = {}
    end

    if not NihuiIVDB.characters then
        NihuiIVDB.characters = {}
    end

    local charKey = GetCurrentCharacterKey()
    local charInfo = GetCurrentCharacterInfo()

    -- Initialize character entry
    NihuiIVDB.characters[charKey] = NihuiIVDB.characters[charKey] or {}
    local charData = NihuiIVDB.characters[charKey]

    -- Save character info
    charData.info = charInfo
    charData.lastUpdate = time()

    -- Save backpack items
    charData.backpack = {}
    local backpackItems = ns.Components.Items.GetBackpackItems()
    for slotKey, itemData in pairs(backpackItems) do
        if not itemData.isEmpty then
            local serialized = SerializeItem(itemData)
            if serialized then
                charData.backpack[slotKey] = serialized
            end
        end
    end

    -- Save bank items (only if bank is open)
    if ns.Components.Items.IsBankOpen() then
        charData.bank = {}
        local bankItems = ns.Components.Items.GetBankItems()
        for slotKey, itemData in pairs(bankItems) do
            if not itemData.isEmpty then
                local serialized = SerializeItem(itemData)
                if serialized then
                    charData.bank[slotKey] = serialized
                end
            end
        end
    end
end

-- Get list of all cached characters
function ns.Components.Cache.GetCachedCharacters()
    if not NihuiIVDB or not NihuiIVDB.characters then
        return {}
    end

    local characters = {}
    for charKey, charData in pairs(NihuiIVDB.characters) do
        if charData.info then
            table.insert(characters, {
                key = charKey,
                name = charData.info.name,
                realm = charData.info.realm,
                class = charData.info.class,
                level = charData.info.level,
                faction = charData.info.faction,
                lastUpdate = charData.lastUpdate,
                isCurrent = (charKey == GetCurrentCharacterKey()),
            })
        end
    end

    -- Sort by last update (most recent first)
    table.sort(characters, function(a, b)
        return (a.lastUpdate or 0) > (b.lastUpdate or 0)
    end)

    return characters
end

-- Get cached inventory for a specific character
function ns.Components.Cache.GetCachedInventory(charKey, bagType)
    if not NihuiIVDB or not NihuiIVDB.characters then
        return {}
    end

    local charData = NihuiIVDB.characters[charKey]
    if not charData then
        return {}
    end

    local cachedItems = {}
    local sourceData = (bagType == "backpack") and charData.backpack or charData.bank

    if not sourceData then
        return {}
    end

    -- Deserialize items
    for slotKey, cachedItem in pairs(sourceData) do
        local bagID, slotID = slotKey:match("^(%d+)_(%d+)$")
        if bagID and slotID then
            bagID = tonumber(bagID)
            slotID = tonumber(slotID)
            local item = DeserializeItem(cachedItem, bagID, slotID)
            if item then
                cachedItems[slotKey] = item
            end
        end
    end

    return cachedItems
end

-- Get character info from cache
function ns.Components.Cache.GetCharacterInfo(charKey)
    if not NihuiIVDB or not NihuiIVDB.characters then
        return nil
    end

    local charData = NihuiIVDB.characters[charKey]
    if not charData or not charData.info then
        return nil
    end

    return charData.info
end

-- Check if character has cached bank data
function ns.Components.Cache.HasCachedBank(charKey)
    if not NihuiIVDB or not NihuiIVDB.characters then
        return false
    end

    local charData = NihuiIVDB.characters[charKey]
    return charData and charData.bank ~= nil
end

-- Initialize cache system
function ns.Components.Cache.Initialize()
    -- Create global DB if it doesn't exist
    if not NihuiIVDB then
        NihuiIVDB = {
            characters = {}
        }
    end

    -- Register events for automatic cache updates
    ns.Components.Events.RegisterEvent("BAG_UPDATE", function()
        -- Debounce updates (wait 1 second after last bag update)
        if ns.Components.Cache.updateTimer then
            ns.Components.Cache.updateTimer:Cancel()
        end

        ns.Components.Cache.updateTimer = C_Timer.NewTimer(1, function()
            ns.Components.Cache.UpdateCache()
            ns.Components.Cache.updateTimer = nil
        end)
    end)

    -- Update cache when bank opens
    ns.Components.Events.RegisterEvent("BANKFRAME_OPENED", function()
        C_Timer.After(0.5, function()
            ns.Components.Cache.UpdateCache()
        end)
    end)

    -- Also update on bank slots changed (more reliable detection)
    ns.Components.Events.RegisterEvent("PLAYERBANKSLOTS_CHANGED", function()
        -- Debounce bank updates
        if ns.Components.Cache.bankUpdateTimer then
            ns.Components.Cache.bankUpdateTimer:Cancel()
        end

        ns.Components.Cache.bankUpdateTimer = C_Timer.NewTimer(2, function()
            if ns.Components.Items.IsBankOpen() then
                ns.Components.Cache.UpdateCache()
            end
            ns.Components.Cache.bankUpdateTimer = nil
        end)
    end)

    -- Initial cache update
    C_Timer.After(2, function()
        ns.Components.Cache.UpdateCache()
    end)

    ns:Print("Cache system initialized")
end

-- Get current character key (exposed for other components)
function ns.Components.Cache.GetCurrentCharacterKey()
    return GetCurrentCharacterKey()
end
