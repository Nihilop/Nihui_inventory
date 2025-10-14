-- components/constants.lua - Complete constants from BetterBags
local addonName, ns = ...

ns.Components = ns.Components or {}
ns.Components.Constants = {}

local const = ns.Components.Constants

-- WoW Version detection
const.isRetail = WOW_PROJECT_ID == WOW_PROJECT_MAINLINE
const.isClassic = WOW_PROJECT_ID == WOW_PROJECT_CLASSIC

-- Bag types
const.BAG_KIND = {
    BACKPACK = 0,
    BANK = 1,
}

-- Backpack bags
const.BACKPACK_BAGS = {
    [Enum.BagIndex.Backpack] = Enum.BagIndex.Backpack,
    [Enum.BagIndex.Bag_1] = Enum.BagIndex.Bag_1,
    [Enum.BagIndex.Bag_2] = Enum.BagIndex.Bag_2,
    [Enum.BagIndex.Bag_3] = Enum.BagIndex.Bag_3,
    [Enum.BagIndex.Bag_4] = Enum.BagIndex.Bag_4,
}

if Enum.BagIndex.ReagentBag then
    const.BACKPACK_BAGS[Enum.BagIndex.ReagentBag] = Enum.BagIndex.ReagentBag
end

-- Bank bags
if const.isRetail then
    const.BANK_BAGS = {
        [Enum.BagIndex.Characterbanktab] = Enum.BagIndex.Characterbanktab,
        [Enum.BagIndex.CharacterBankTab_1] = Enum.BagIndex.CharacterBankTab_1,
        [Enum.BagIndex.CharacterBankTab_2] = Enum.BagIndex.CharacterBankTab_2,
        [Enum.BagIndex.CharacterBankTab_3] = Enum.BagIndex.CharacterBankTab_3,
        [Enum.BagIndex.CharacterBankTab_4] = Enum.BagIndex.CharacterBankTab_4,
        [Enum.BagIndex.CharacterBankTab_5] = Enum.BagIndex.CharacterBankTab_5,
        [Enum.BagIndex.CharacterBankTab_6] = Enum.BagIndex.CharacterBankTab_6,
    }
else
    const.BANK_BAGS = {
        [Enum.BagIndex.Bank] = Enum.BagIndex.Bank,
        [Enum.BagIndex.BankBag_1] = Enum.BagIndex.BankBag_1,
        [Enum.BagIndex.BankBag_2] = Enum.BagIndex.BankBag_2,
        [Enum.BagIndex.BankBag_3] = Enum.BagIndex.BankBag_3,
        [Enum.BagIndex.BankBag_4] = Enum.BagIndex.BankBag_4,
        [Enum.BagIndex.BankBag_5] = Enum.BagIndex.BankBag_5,
        [Enum.BagIndex.BankBag_6] = Enum.BagIndex.BankBag_6,
        [Enum.BagIndex.BankBag_7] = Enum.BagIndex.BankBag_7,
    }
end

-- Account bank (Warband)
const.ACCOUNT_BANK_BAGS = {}
if Enum.BagIndex.AccountBankTab_1 then
    for i = 1, 5 do
        local bagIndex = Enum.BagIndex["AccountBankTab_" .. i]
        if bagIndex then
            const.ACCOUNT_BANK_BAGS[bagIndex] = bagIndex
        end
    end
end

-- Item quality constants
const.ITEM_QUALITY = {
    Poor = Enum.ItemQuality.Poor,
    Common = Enum.ItemQuality.Common,
    Uncommon = Enum.ItemQuality.Uncommon,
    Rare = Enum.ItemQuality.Rare,
    Epic = Enum.ItemQuality.Epic,
    Legendary = Enum.ItemQuality.Legendary,
    Artifact = Enum.ItemQuality.Artifact,
    Heirloom = Enum.ItemQuality.Heirloom,
}

if Enum.ItemQuality.WoWToken then
    const.ITEM_QUALITY.WoWToken = Enum.ItemQuality.WoWToken
end

-- Item quality colors
const.ITEM_QUALITY_COLOR = {
    [const.ITEM_QUALITY.Poor] = {0.62, 0.62, 0.62, 1},
    [const.ITEM_QUALITY.Common] = {1, 1, 1, 1},
    [const.ITEM_QUALITY.Uncommon] = {0.12, 1, 0, 1},
    [const.ITEM_QUALITY.Rare] = {0.00, 0.44, 0.87, 1},
    [const.ITEM_QUALITY.Epic] = {0.64, 0.21, 0.93, 1},
    [const.ITEM_QUALITY.Legendary] = {1, 0.50, 0, 1},
    [const.ITEM_QUALITY.Artifact] = {0.90, 0.80, 0.50, 1},
    [const.ITEM_QUALITY.Heirloom] = {0, 0.8, 1, 1},
}

if Enum.ItemQuality.WoWToken then
    const.ITEM_QUALITY_COLOR[const.ITEM_QUALITY.WoWToken] = {0, 0.8, 1, 1}
end

-- Expansion map
const.EXPANSION_MAP = {
    [_G.LE_EXPANSION_CLASSIC] = _G.EXPANSION_NAME0,
    [_G.LE_EXPANSION_BURNING_CRUSADE] = _G.EXPANSION_NAME1,
    [_G.LE_EXPANSION_WRATH_OF_THE_LICH_KING] = _G.EXPANSION_NAME2,
    [_G.LE_EXPANSION_CATACLYSM] = _G.EXPANSION_NAME3,
    [_G.LE_EXPANSION_MISTS_OF_PANDARIA] = _G.EXPANSION_NAME4,
    [_G.LE_EXPANSION_WARLORDS_OF_DRAENOR] = _G.EXPANSION_NAME5,
    [_G.LE_EXPANSION_LEGION] = _G.EXPANSION_NAME6,
    [_G.LE_EXPANSION_BATTLE_FOR_AZEROTH] = _G.EXPANSION_NAME7,
    [_G.LE_EXPANSION_SHADOWLANDS] = _G.EXPANSION_NAME8,
    [_G.LE_EXPANSION_DRAGONFLIGHT] = _G.EXPANSION_NAME9,
}

if const.isRetail and _G.LE_EXPANSION_WAR_WITHIN then
    const.EXPANSION_MAP[_G.LE_EXPANSION_WAR_WITHIN] = _G.EXPANSION_NAME10
end

-- Tradeskill map (for categorization)
const.TRADESKILL_MAP = {
    [0] = "Trade Goods",
    [1] = "Engineering",  -- Parts
    [4] = "Jewelcrafting",
    [5] = "Tailoring",  -- Cloth
    [6] = "Leatherworking",  -- Leather
    [7] = "Mining",  -- Metal & Stone
    [8] = "Cooking",
    [9] = "Herbalism",  -- Herb
    [10] = "Elemental",
    [11] = "Other",
    [12] = "Enchanting",
    [16] = "Inscription",
    [18] = "Optional Reagents",
    [19] = "Finishing Reagents",
}

-- Equipment slots
const.EQUIPMENT_SLOTS = {
    INVSLOT_HEAD,
    INVSLOT_NECK,
    INVSLOT_SHOULDER,
    INVSLOT_BACK,
    INVSLOT_CHEST,
    INVSLOT_WRIST,
    INVSLOT_HAND,
    INVSLOT_WAIST,
    INVSLOT_LEGS,
    INVSLOT_FEET,
    INVSLOT_FINGER1,
    INVSLOT_FINGER2,
    INVSLOT_TRINKET1,
    INVSLOT_TRINKET2,
    INVSLOT_MAINHAND,
    INVSLOT_OFFHAND,
    INVSLOT_RANGED,
    INVSLOT_TABARD,
    INVSLOT_BODY,
}

-- Inventory type to slots mapping
const.INVENTORY_TYPE_TO_SLOTS = {
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
}

-- Grid compact style
const.GRID_COMPACT_STYLE = {
    NONE = 0,
    SIMPLE = 1,
    COMPACT = 2,
}

-- Bag view types
const.BAG_VIEW = {
    ONE_BAG = 1,           -- All items in one grid
    SECTION_GRID = 2,      -- Items grouped by category in grid
    LIST = 3,              -- List view
    SECTION_ALL_BAGS = 4,  -- All bags with sections
}

-- Sort types for sections
const.SECTION_SORT_TYPE = {
    ALPHABETICALLY = 1,
    SIZE_DESCENDING = 2,
    SIZE_ASCENDING = 3,
}

-- Sort types for items
const.ITEM_SORT_TYPE = {
    ALPHABETICALLY_THEN_QUALITY = 1,
    QUALITY_THEN_ALPHABETICALLY = 2,
    ITEM_LEVEL = 3,
}

-- Offsets for UI positioning
const.OFFSETS = {
    BAG_TOP_INSET = -42,
    BAG_LEFT_INSET = 6,
    BAG_RIGHT_INSET = -6,
    BAG_BOTTOM_INSET = 3,
    BOTTOM_BAR_HEIGHT = 20,
    SEARCH_TOP_INSET = -30,
}

-- Item class names (for categorization) - lazy loaded
const.ITEM_CLASS_NAMES = {}
const.ITEM_SUBCLASS_NAMES = {}

-- Initialize item class/subclass names (call this after PLAYER_LOGIN)
function ns.Components.Constants.InitializeItemNames()
    -- Item class names
    for i = 0, 20 do
        local success, className = pcall(C_Item.GetItemClassInfo, i)
        if success and className then
            const.ITEM_CLASS_NAMES[i] = className
        end
    end

    -- Item subclass names
    for classID = 0, 20 do
        const.ITEM_SUBCLASS_NAMES[classID] = {}
        for subclassID = 0, 30 do
            local success, subclassName = pcall(C_Item.GetItemSubClassInfo, classID, subclassID)
            if success and subclassName and subclassName ~= "" then
                const.ITEM_SUBCLASS_NAMES[classID][subclassID] = subclassName
            end
        end
    end
end

-- Grid spacing default
const.GRID_SPACING = 4

-- Slot size default
const.SLOT_SIZE = 48

-- Get constants (for external access)
function ns.Components.Constants.Get()
    return const
end
