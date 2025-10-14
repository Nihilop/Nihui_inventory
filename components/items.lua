-- components/items.lua - Item data management component (pure logic, no layout)
-- Extracted from BetterBags - handles item retrieval, caching, and events
local addonName, ns = ...

ns.Components = ns.Components or {}
ns.Components.Items = {}

local itemCache = {}
local eventFrame = nil
local callbacks = {
    onBagUpdate = nil,
    onItemsChanged = {},  -- Array of callbacks instead of single callback
}

-- Get bag constants from constants component (lazy load)
local function getConst()
    return ns.Components.Constants.Get()
end

-- Get all items from specified bags
-- @param bags - Table of bag IDs {bagID = true}
-- @return items - Table of item data {slotKey = itemData}
function ns.Components.Items.GetAllItems(bags)
    local items = {}

    for bagID in pairs(bags) do
        local numSlots = C_Container.GetContainerNumSlots(bagID)

        if numSlots and numSlots > 0 then
            for slotID = 1, numSlots do
                local itemID = C_Container.GetContainerItemID(bagID, slotID)
                local slotKey = bagID .. "_" .. slotID

                if itemID then
                    -- Item exists in this slot
                    local itemData = ns.Components.Items.GetItemData(bagID, slotID)
                    items[slotKey] = itemData
                else
                    -- Empty slot
                    items[slotKey] = {
                        bagID = bagID,
                        slotID = slotID,
                        slotKey = slotKey,
                        isEmpty = true,
                    }
                end
            end
        end
    end

    return items
end

-- Get item data for a specific bag and slot
-- @param bagID - Bag ID
-- @param slotID - Slot ID
-- @return itemData - Table with item information
function ns.Components.Items.GetItemData(bagID, slotID)
    local itemID = C_Container.GetContainerItemID(bagID, slotID)
    local itemLink = C_Container.GetContainerItemLink(bagID, slotID)
    local containerInfo = C_Container.GetContainerItemInfo(bagID, slotID)

    if not itemID or not containerInfo then
        return {
            bagID = bagID,
            slotID = slotID,
            slotKey = bagID .. "_" .. slotID,
            isEmpty = true,
        }
    end

    -- Get item info (can return nil if not in cache, but we have containerInfo as fallback)
    local itemName, _, itemQuality, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount,
          itemEquipLoc, itemTexture, sellPrice, classID, subclassID, bindType, expacID, setID, isCraftingReagent = C_Item.GetItemInfo(itemID)

    -- If item info is not cached, request it (will trigger GET_ITEM_INFO_RECEIVED later)
    if not itemName then
        C_Item.RequestLoadItemDataByID(itemID)
    end

    -- Get REAL quality from itemLink (handles variants and upgrades!)
    -- containerInfo.quality can be wrong for upgraded items
    if itemLink then
        local linkQuality = C_Item.GetItemQualityByID(itemLink)
        if linkQuality and linkQuality > 0 then
            itemQuality = linkQuality
        end
    end

    -- Use containerInfo for most data (it's synchronous and always available)
    local currentItemCount = containerInfo.stackCount or 1

    -- Get REAL current item level using ItemLocation (handles variants!)
    -- This is critical for items that scale (PvP, M+, raid difficulty, etc.)
    local currentItemLevel = itemLevel or 0
    local itemLocation = ItemLocation:CreateFromBagAndSlot(bagID, slotID)
    if itemLocation and itemLocation:IsValid() then
        local realItemLevel = C_Item.GetCurrentItemLevel(itemLocation)
        if realItemLevel and realItemLevel > 0 then
            currentItemLevel = realItemLevel
        end
    end

    local isQuestItem = containerInfo.hasNoValue or false
    local isBound = false -- We'll set this to false for now to avoid blocking calls
    local itemGUID = nil -- Not critical for display

    -- Parse item link for hash generation
    local itemLinkInfo = ns.Components.Items.ParseItemLink(itemLink or "")

    -- Generate item hash (for stacking)
    local itemHash = ns.Components.Items.GenerateItemHash(itemLinkInfo, currentItemLevel)

    -- Get inventory slots for equippable items (for upgrade icon)
    -- Uses ItemMixin like BetterBags does to get Enum.InventoryType
    local inventorySlots = nil
    if itemLink then
        local success, isEquippable = pcall(C_Item.IsEquippableItem, itemLink)
        if success and isEquippable then
            -- Get inventory type enum (like BetterBags does)
            local itemMixin = Item:CreateFromBagAndSlot(bagID, slotID)
            local invType = itemMixin:GetInventoryType()

            -- Map inventory type to slots using same table as BetterBags
            local INVENTORY_TYPE_TO_SLOTS = {
                [Enum.InventoryType.IndexHeadType] = {INVSLOT_HEAD},
                [Enum.InventoryType.IndexNeckType] = {INVSLOT_NECK},
                [Enum.InventoryType.IndexShoulderType] = {INVSLOT_SHOULDER},
                [Enum.InventoryType.IndexBodyType] = {INVSLOT_BODY},
                [Enum.InventoryType.IndexChestType] = {INVSLOT_CHEST},
                [Enum.InventoryType.IndexWaistType] = {INVSLOT_WAIST},
                [Enum.InventoryType.IndexLegsType] = {INVSLOT_LEGS},
                [Enum.InventoryType.IndexFeetType] = {INVSLOT_FEET},
                [Enum.InventoryType.IndexWristType] = {INVSLOT_WRIST},
                [Enum.InventoryType.IndexHandType] = {INVSLOT_HAND},
                [Enum.InventoryType.IndexFingerType] = {INVSLOT_FINGER1, INVSLOT_FINGER2},
                [Enum.InventoryType.IndexTrinketType] = {INVSLOT_TRINKET1, INVSLOT_TRINKET2},
                [Enum.InventoryType.IndexWeaponType] = {INVSLOT_MAINHAND, INVSLOT_OFFHAND},
                [Enum.InventoryType.IndexShieldType] = {INVSLOT_OFFHAND},
                [Enum.InventoryType.IndexRangedType] = {INVSLOT_MAINHAND},
                [Enum.InventoryType.IndexCloakType] = {INVSLOT_BACK},
                [Enum.InventoryType.Index2HweaponType] = {INVSLOT_MAINHAND},
                [Enum.InventoryType.IndexTabardType] = {INVSLOT_TABARD},
                [Enum.InventoryType.IndexRobeType] = {INVSLOT_CHEST},
                [Enum.InventoryType.IndexWeaponmainhandType] = {INVSLOT_MAINHAND},
                [Enum.InventoryType.IndexWeaponoffhandType] = {INVSLOT_OFFHAND},
                [Enum.InventoryType.IndexHoldableType] = {INVSLOT_OFFHAND},
                [Enum.InventoryType.IndexThrownType] = {INVSLOT_MAINHAND},
                [Enum.InventoryType.IndexRangedrightType] = {INVSLOT_MAINHAND},
            }

            inventorySlots = INVENTORY_TYPE_TO_SLOTS[invType] or nil
        end
    end

    -- CRITICAL: Use containerInfo as primary source since it's always available
    return {
        bagID = bagID,
        slotID = slotID,
        slotKey = bagID .. "_" .. slotID,
        isEmpty = false,
        itemID = itemID,
        itemLink = itemLink,
        itemName = itemName or "",  -- Can be empty if not cached yet
        itemQuality = itemQuality or containerInfo.quality or 0,
        itemLevel = itemLevel or 0,
        currentItemLevel = currentItemLevel,
        itemType = itemType,
        itemSubType = itemSubType,
        itemStackCount = itemStackCount or 1,
        itemEquipLoc = itemEquipLoc,
        itemTexture = containerInfo.iconFileID,  -- ALWAYS use containerInfo for texture (it's reliable)
        classID = classID,
        subclassID = subclassID,
        bindType = bindType,
        expacID = expacID,
        isCraftingReagent = isCraftingReagent,
        isQuestItem = isQuestItem,
        isBound = isBound,
        itemGUID = itemGUID,
        currentItemCount = containerInfo.stackCount or 1,  -- ALWAYS use containerInfo
        isLocked = containerInfo.isLocked or false,
        itemLinkInfo = itemLinkInfo,
        itemHash = itemHash,
        containerInfo = containerInfo,
        inventorySlots = inventorySlots,  -- Pre-calculated slots for upgrade icon
    }
end

-- Parse item link into components (for hash generation)
-- @param link - Item link string
-- @return linkInfo - Table with parsed components
function ns.Components.Items.ParseItemLink(link)
    if not link or link == "" then
        return {
            itemID = 0,
            enchantID = "",
            gemID1 = "",
            gemID2 = "",
            gemID3 = "",
            gemID4 = "",
            suffixID = "",
            uniqueID = "",
            linkLevel = "",
            specializationID = "",
            modifiersMask = "",
            itemContext = "",
            bonusIDs = {},
            modifierIDs = {},
            crafterGUID = "",
            extraEnchantID = "",
        }
    end

    -- Parse basic elements
    local _, _, itemID, enchantID, gemID1, gemID2, gemID3, gemID4, suffixID, uniqueID, linkLevel, specializationID, modifiersMask, itemContext, rest =
        strsplit(":", link, 15)

    -- Parse bonus IDs
    local bonusIDs = {}
    if rest then
        local numBonusIDs
        numBonusIDs, rest = strsplit(":", rest, 2)
        if numBonusIDs and numBonusIDs ~= "" and rest then
            local splits = tonumber(numBonusIDs) + 1
            bonusIDs = { strsplit(":", rest, splits) }
            rest = table.remove(bonusIDs, splits)
        end
    end

    return {
        itemID = tonumber(itemID) or 0,
        enchantID = enchantID or "",
        gemID1 = gemID1 or "",
        gemID2 = gemID2 or "",
        gemID3 = gemID3 or "",
        gemID4 = gemID4 or "",
        suffixID = suffixID or "",
        uniqueID = uniqueID or "",
        linkLevel = linkLevel or "",
        specializationID = specializationID or "",
        modifiersMask = modifiersMask or "",
        itemContext = itemContext or "",
        bonusIDs = bonusIDs,
        modifierIDs = {},
        crafterGUID = "",
        extraEnchantID = "",
    }
end

-- Generate item hash for stacking identical items
-- @param linkInfo - Parsed item link info
-- @param itemLevel - Item level
-- @return hash - String hash for this item
function ns.Components.Items.GenerateItemHash(linkInfo, itemLevel)
    return string.format(
        "%d%s%s%s%s%s%s%d",
        linkInfo.itemID,
        linkInfo.enchantID,
        linkInfo.suffixID,
        table.concat(linkInfo.bonusIDs or {}, ","),
        linkInfo.crafterGUID or "",
        linkInfo.extraEnchantID or "",
        linkInfo.specializationID or "",
        itemLevel or 0
    )
end

-- Get backpack items
function ns.Components.Items.GetBackpackItems()
    local const = getConst()
    return ns.Components.Items.GetAllItems(const.BACKPACK_BAGS)
end

-- Get bank items
function ns.Components.Items.GetBankItems()
    local const = getConst()
    return ns.Components.Items.GetAllItems(const.BANK_BAGS)
end

-- Get account bank items
function ns.Components.Items.GetAccountBankItems()
    local const = getConst()
    return ns.Components.Items.GetAllItems(const.ACCOUNT_BANK_BAGS)
end

-- Get free slot count for bags
function ns.Components.Items.GetFreeSlots(bags)
    local freeSlots = 0

    for bagID in pairs(bags) do
        local free = C_Container.GetContainerNumFreeSlots(bagID) or 0
        freeSlots = freeSlots + free
    end

    return freeSlots
end

-- Get total slot count for bags
function ns.Components.Items.GetTotalSlots(bags)
    local totalSlots = 0

    for bagID in pairs(bags) do
        local numSlots = C_Container.GetContainerNumSlots(bagID) or 0
        totalSlots = totalSlots + numSlots
    end

    return totalSlots
end

-- Get cached backpack items for a specific character
function ns.Components.Items.GetCachedBackpackItems(charKey)
    if not charKey then
        charKey = ns.Components.Cache.GetCurrentCharacterKey()
    end

    return ns.Components.Cache.GetCachedInventory(charKey, "backpack")
end

-- Get cached bank items for a specific character
function ns.Components.Items.GetCachedBankItems(charKey)
    if not charKey then
        charKey = ns.Components.Cache.GetCurrentCharacterKey()
    end

    return ns.Components.Cache.GetCachedInventory(charKey, "bank")
end

-- Check if bank is open
function ns.Components.Items.IsBankOpen()
    return ns.Components.Events and ns.Components.Events.IsBankOpen and ns.Components.Events.IsBankOpen() or false
end

-- Check if character has cached bank data
function ns.Components.Items.HasCachedBank(charKey)
    if not charKey then
        charKey = ns.Components.Cache.GetCurrentCharacterKey()
    end
    return ns.Components.Cache.HasCachedBank(charKey)
end

-- Initialize item system with event handling
function ns.Components.Items.Initialize()
    -- Create event frame
    eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("BAG_UPDATE")
    eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
    eventFrame:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
    eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")  -- Refresh when equipping items

    eventFrame:SetScript("OnEvent", function(self, event, bagID)
        if event == "BAG_UPDATE" and callbacks.onBagUpdate then
            callbacks.onBagUpdate(bagID)
        elseif event == "BAG_UPDATE_DELAYED" or event == "PLAYERBANKSLOTS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            -- Call all registered callbacks
            for _, callback in ipairs(callbacks.onItemsChanged) do
                if callback then
                    callback()
                end
            end
        end
    end)
end

-- Set callback for bag updates
function ns.Components.Items.SetBagUpdateCallback(callback)
    callbacks.onBagUpdate = callback
end

-- Set callback for items changed
function ns.Components.Items.SetItemsChangedCallback(callback)
    table.insert(callbacks.onItemsChanged, callback)
end

-- Get bag constants
function ns.Components.Items.GetBagConstants()
    local const = getConst()
    return {
        BACKPACK = const.BACKPACK_BAGS,
        BANK = const.BANK_BAGS,
        ACCOUNT_BANK = const.ACCOUNT_BANK_BAGS,
    }
end

-- Cleanup
function ns.Components.Items.Destroy()
    if eventFrame then
        eventFrame:UnregisterAllEvents()
        eventFrame:SetScript("OnEvent", nil)
    end

    itemCache = {}
    callbacks = {
        onBagUpdate = nil,
        onItemsChanged = {},
    }
end
