-- components/slots.lua - Slot creation and management (pure logic, no layout)
-- Extracted from BetterBags - handles item button creation and click handling
--
-- ⚠️ CRITICAL TAINT PREVENTION RULES - DO NOT MODIFY THESE OR RIGHT-CLICK WILL BREAK! ⚠️
--
-- 1. NEVER set properties directly on the ItemButton (the secure frame)
--    ❌ BAD:  itemButton.bagID = bagID
--    ✅ GOOD: parentFrame.bagID = bagID
--
-- 2. ALWAYS use the parent frame for custom properties (bagID, itemData, etc.)
--    The ItemButton must remain pristine - only use official APIs (SetID, SetHasItem, etc.)
--
-- 3. DO NOT call C_NewItems.RemoveNewItem() - it causes taint with UseContainerItem()
--
-- 4. DO NOT modify OnClick, OnDragStart, OnReceiveDrag handlers
--    ContainerFrameItemButtonTemplate sets these up securely
--
-- 5. DO NOT add custom tooltip scripts - the template handles tooltips automatically
--
-- Following these rules ensures consumables (food, potions) can be used via right-click!
--
local addonName, ns = ...

ns.Components = ns.Components or {}
ns.Components.Slots = {}

-- ========================================
-- SLOT STYLE CONFIGURATION (Nihui_ab inspired)
-- ========================================
-- Change these atlas names to customize the slot appearance
local SLOT_STYLE = {
    -- Mask for icon and quality border (circular)
    maskAtlas = "UI-HUD-CoolDownManager-Mask",

    -- Overlay texture (decorative border under quality border)
    overlayAtlas = "UI-HUD-CoolDownManager-IconOverlay",

    -- Quality/Rarity border (colored glow for item rarity)
    quality = {
        atlas = "perks-slot-glow",      -- Atlas for quality border glow
        sizeRatio = 0.9,                -- Size relative to slot (1.0 = same size)
        alpha = 0.5,                    -- Transparency (0-1)
        blendMode = "ADD",              -- Blend mode: "ADD" for glow effect
        drawLayer = "OVERLAY",          -- Draw layer (OVERLAY = on top of icon)
        sublevel = 0,                   -- Sublevel within draw layer
        useBrightness = true,          -- Multiply colors for extra brightness?
        brightnessMultiplier = 1.0,     -- Brightness multiplier (only if useBrightness = true)
    },

    -- Hover/Highlight effect
    hover = {
        atlas = "bags-newitem",  -- Texture for hover effect
        sizeRatio = 1.05,                               -- Size relative to slot (105% = slightly larger)
        alpha = 0.5,                                    -- Transparency (0-1)
        blendMode = "ADD",                              -- Blend mode: "BLEND", "ADD", "MOD", etc.
        vertexColor = { r = 1, g = 1, b = 1 },        -- Color tint (white by default)
    },

    -- Sizes (relative to slot size)
    maskSizeRatio = 0.94,      -- Mask is 94% of slot size (slightly smaller)
    overlaySizeRatio = 1.25,   -- Overlay is 125% of slot size (extends beyond)
}

local slotPool = {}
local activeSlots = {}
local buttonCount = 0

-- Create an item button (slot) - EXACTLY like BetterBags does
-- @param parent - Parent frame
-- @param itemData - Item data
-- @param size - Size of the slot in pixels (optional, default: 37)
-- @return parentFrame - Parent frame (contains the actual ItemButton)
function ns.Components.Slots.CreateSlot(parent, itemData, size)
    local slotSize = size or 37 -- Default size if not specified

    -- POOL COMPLETELY DISABLED - always create new slots
    local slot = nil

    if not slot then
        -- Generate unique name for button
        local name = string.format("NihuiIVItemButton%d", buttonCount)
        buttonCount = buttonCount + 1

        -- CRITICAL: Create a parent Button frame first (works around taint in 10.x+)
        local parentFrame = CreateFrame("Button", name .. "Parent")
        parentFrame:SetSize(slotSize, slotSize) -- IMPORTANT: Set explicit size on parent!

        -- Create the actual ItemButton inside the parent (SECURE)
        local itemButton = CreateFrame("ItemButton", name, parentFrame, "ContainerFrameItemButtonTemplate")
        itemButton:SetSize(slotSize, slotSize) -- Set size on ItemButton
        itemButton:SetAllPoints(parentFrame) -- ItemButton fills parent

        -- IMPORTANT: Adjust icon texture to fill most of the button (small inset for border)
        if itemButton.icon then
            -- Small fixed inset to leave room for quality border glow
            local inset = 1
            itemButton.icon:ClearAllPoints()
            itemButton.icon:SetPoint("TOPLEFT", itemButton, "TOPLEFT", inset, -inset)
            itemButton.icon:SetPoint("BOTTOMRIGHT", itemButton, "BOTTOMRIGHT", -inset, inset)

            -- Apply circular mask to icon (Nihui_ab style)
            local iconMask = itemButton:CreateMaskTexture()
            local maskSize = slotSize * SLOT_STYLE.maskSizeRatio
            iconMask:SetSize(maskSize, maskSize)
            iconMask:SetPoint("CENTER", itemButton, "CENTER", 0, 0)
            iconMask:SetAtlas(SLOT_STYLE.maskAtlas, false)
            itemButton.icon:AddMaskTexture(iconMask)
            itemButton.iconMask = iconMask
        end

        -- Create decorative overlay (black border base)
        local overlayTexture = itemButton:CreateTexture(nil, "ARTWORK", nil, 2)
        local overlaySize = slotSize * SLOT_STYLE.overlaySizeRatio
        overlayTexture:SetSize(overlaySize, overlaySize)
        overlayTexture:SetPoint("CENTER", itemButton, "CENTER", 0, 0)
        overlayTexture:SetAtlas(SLOT_STYLE.overlayAtlas, false)
        itemButton.nihuiOverlay = overlayTexture

        -- Create custom quality border texture (for rarity glow on top of black border)
        local qualityBorder = itemButton:CreateTexture(nil, SLOT_STYLE.quality.drawLayer, nil, SLOT_STYLE.quality.sublevel)
        local qualitySize = slotSize * SLOT_STYLE.quality.sizeRatio
        qualityBorder:SetSize(qualitySize, qualitySize)
        qualityBorder:SetPoint("CENTER", itemButton, "CENTER", 0, 0)
        -- Use WHITE atlas so SetVertexColor can colorize it properly (white * color = color)
        qualityBorder:SetAtlas(SLOT_STYLE.quality.atlas, false)  -- false = don't use atlas size, keep our custom size
        qualityBorder:SetBlendMode(SLOT_STYLE.quality.blendMode)
        qualityBorder:Hide()  -- Hidden by default, shown when item has quality
        itemButton.nihuiQualityBorder = qualityBorder

        -- Keep IconBorder at normal size (we'll use our custom quality border instead)
        if itemButton.IconBorder then
            itemButton.IconBorder:SetSize(slotSize, slotSize)
            itemButton.IconBorder:ClearAllPoints()
            itemButton.IconBorder:SetAllPoints(itemButton)
            itemButton.IconBorder:Hide()  -- Hide default IconBorder, we use custom one
        end

        -- IMPORTANT: Hide the inner black border (NormalTexture) - it doesn't scale well
        -- We keep only the quality border (IconBorder) which looks cleaner
        if itemButton:GetNormalTexture() then
            itemButton:GetNormalTexture():SetAlpha(0) -- Hide it completely
        end

        -- Keep PushedTexture but resize it
        if itemButton:GetPushedTexture() then
            itemButton:GetPushedTexture():SetSize(slotSize, slotSize)
            itemButton:GetPushedTexture():ClearAllPoints()
            itemButton:GetPushedTexture():SetAllPoints(itemButton)
        end

        -- Create custom hover/highlight texture (ItemButtons don't always have GetHighlightTexture)
        local highlight = itemButton:CreateTexture(nil, "HIGHLIGHT")

        -- Apply atlas
        if SLOT_STYLE.hover.atlas then
            highlight:SetAtlas(SLOT_STYLE.hover.atlas, false)
        end

        -- Size and position
        local hoverSize = slotSize * SLOT_STYLE.hover.sizeRatio
        highlight:SetSize(hoverSize, hoverSize)
        highlight:SetPoint("CENTER", itemButton, "CENTER", 0, 0)

        -- Visual properties
        highlight:SetAlpha(SLOT_STYLE.hover.alpha)
        highlight:SetBlendMode(SLOT_STYLE.hover.blendMode)

        if SLOT_STYLE.hover.vertexColor then
            local c = SLOT_STYLE.hover.vertexColor
            highlight:SetVertexColor(c.r, c.g, c.b, 1)
        end

        -- Set as highlight texture (appears on mouse over)
        itemButton:SetHighlightTexture(highlight)
        itemButton.nihuiHighlight = highlight

        -- Register for interactions (like BetterBags does)
        itemButton:RegisterForDrag("LeftButton")
        itemButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")

        -- Create item level text (like BetterBags)
        local ilvlText = itemButton:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
        ilvlText:SetPoint("BOTTOMLEFT", itemButton, "BOTTOMLEFT", 2, 2)
        ilvlText:Hide()

        -- Store references
        parentFrame.itemButton = itemButton
        parentFrame.ilvlText = ilvlText
        parentFrame.itemData = nil

        -- NO TOOLTIP HANDLING! ContainerFrameItemButtonTemplate does this automatically.
        -- Any manual tooltip handling causes taint with UseContainerItem().

        slot = parentFrame
    end

    -- CRITICAL: Clear all points BEFORE setting parent (important for reused slots)
    slot:ClearAllPoints()

    -- Set parent
    slot:SetParent(parent)

    -- IMPORTANT: Ensure size matches requested size (in case it was changed)
    local slotSize = size or 37
    slot:SetSize(slotSize, slotSize)

    -- Get the actual ItemButton
    local itemButton = slot.itemButton

    -- CRITICAL: Set bag and slot IDs for Blizzard's secure handlers (like BetterBags does)
    -- UNLESS this is cached data (preview mode) - then we use invalid IDs to prevent wrong tooltips
    if itemData.isCached then
        itemButton:SetID(0)  -- Invalid ID for cached items
        slot.bagID = -1      -- Invalid bag ID
        slot:SetID(-1)       -- Invalid frame ID
    else
        itemButton:SetID(itemData.slotID)  -- Slot ID on ItemButton
        slot.bagID = itemData.bagID        -- Bag ID on parent frame (IMPORTANT! - like BetterBags)
        slot:SetID(itemData.bagID)         -- Also set as frame ID
    end

    -- Store item data reference
    slot.itemData = itemData

    -- Add custom tooltip for cached items (and disable default tooltip)
    if itemData.isCached and itemData.itemLink then
        -- Disable default tooltip behavior
        itemButton:EnableMouse(true)
        itemButton:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(itemData.itemLink)
            -- Add "Cached Data" line to indicate this is preview mode
            GameTooltip:AddLine(" ", 1, 1, 1)
            GameTooltip:AddLine("|cff888888(Cached Data - Read Only)|r", 1, 1, 1, true)
            GameTooltip:Show()
        end)
        itemButton:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
        end)

        -- Override the default UpdateTooltip to prevent it from changing our tooltip
        itemButton.UpdateTooltip = function() end
    else
        -- Reset to default behavior for non-cached items
        itemButton.UpdateTooltip = nil
    end

    -- Update button with item data
    ns.Components.Slots.UpdateSlot(slot, itemData)

    -- Track active slot
    table.insert(activeSlots, slot)

    return slot
end

-- Update slot with item data
-- @param slot - Parent frame (contains itemButton)
-- @param itemData - Item data
function ns.Components.Slots.UpdateSlot(slot, itemData)
    slot.itemData = itemData

    -- Get the actual ItemButton (the secure one)
    local button = slot.itemButton

    if itemData.isEmpty then
        -- Empty slot
        button:SetHasItem(nil)  -- CRITICAL: Tell button it has no item
        SetItemButtonTexture(button, nil)
        SetItemButtonCount(button, 0)
        SetItemButtonDesaturated(button, false)
        slot.ilvlText:Hide()
        if button.UpgradeIcon then
            button.UpgradeIcon:Hide()
        end

        -- Disable all animations and glows for empty slots
        if button.NewItemTexture then
            button.NewItemTexture:Hide()
        end
        if button.BattlepayItemTexture then
            button.BattlepayItemTexture:Hide()
        end
        if button.ItemContextOverlay then
            button.ItemContextOverlay:Hide()
        end
        if button.flashAnim and button.flashAnim:IsPlaying() then
            button.flashAnim:Stop()
        end
        if button.newitemglowAnim and button.newitemglowAnim:IsPlaying() then
            button.newitemglowAnim:Stop()
        end

        slot:SetAlpha(itemData.alpha or 1.0)
    else
        -- CRITICAL: Tell button it HAS an item (like BetterBags does!)
        button:SetHasItem(itemData.itemTexture)

        -- Set item
        SetItemButtonTexture(button, itemData.itemTexture)

        -- Set count (show stacked count if applicable)
        local count = itemData.stackedCount or itemData.currentItemCount or 1
        SetItemButtonCount(button, count > 1 and count or 0)

        -- Special handling for "Empty Slots" stack
        if itemData.isEmptySlotStack then
            -- Desaturate (gray out) the icon to indicate empty slots
            SetItemButtonDesaturated(button, true)

            -- Hide quality border for empty slots
            button.IconBorder:Hide()

            -- Hide item level text
            if slot.ilvlText then
                slot.ilvlText:Hide()
            end

            -- Hide upgrade icon
            if button.UpgradeIcon then
                button.UpgradeIcon:Hide()
            end
        else
            -- Normal item display
            -- Ensure desaturation is off for regular items
            SetItemButtonDesaturated(button, itemData.isLocked or false)
        end

        -- Set custom quality border with standard WoW colors (skip for empty slot stacks)
        if not itemData.isEmptySlotStack and button.nihuiQualityBorder and itemData.itemQuality and itemData.itemQuality >= Enum.ItemQuality.Uncommon then
            local r, g, b = C_Item.GetItemQualityColor(itemData.itemQuality)

            -- Apply brightness multiplier if enabled
            if SLOT_STYLE.quality.useBrightness then
                local brightness = SLOT_STYLE.quality.brightnessMultiplier
                r = r * brightness
                g = g * brightness
                b = b * brightness
            end

            -- Apply colors with configured alpha
            button.nihuiQualityBorder:SetVertexColor(r, g, b, SLOT_STYLE.quality.alpha)
            button.nihuiQualityBorder:Show()
        else
            if button.nihuiQualityBorder then
                button.nihuiQualityBorder:Hide()
            end
        end

        -- Show item level for armor and weapons (skip for empty slot stacks)
        local ilvlText = slot.ilvlText
        if not itemData.isEmptySlotStack and ilvlText and itemData.currentItemLevel and itemData.currentItemLevel > 1 then
            -- Only show for armor and weapons
            if itemData.classID == Enum.ItemClass.Armor or itemData.classID == Enum.ItemClass.Weapon then
                local ilvl = itemData.currentItemLevel
                ilvlText:SetText(tostring(ilvl))

                -- Color based on item level (gradient from green to yellow to orange to red)
                -- Approximate player item level thresholds (adjust as needed)
                local r, g, b
                if ilvl < 400 then
                    -- Low: Green → Yellow (400-500)
                    local t = math.max(0, math.min(1, (ilvl - 300) / 100))
                    r, g, b = 0 + t * 1, 1, 0
                elseif ilvl < 500 then
                    -- Medium: Yellow → Orange (500-600)
                    local t = (ilvl - 400) / 100
                    r, g, b = 1, 1 - t * 0.5, 0
                elseif ilvl < 600 then
                    -- High: Orange → Red (600+)
                    local t = (ilvl - 500) / 100
                    r, g, b = 1, 0.5 - t * 0.5, 0
                else
                    -- Very high: Red
                    r, g, b = 1, 0, 0
                end

                ilvlText:SetTextColor(r, g, b, 1)
                ilvlText:Show()
            else
                ilvlText:Hide()
            end
        else
            if ilvlText then
                ilvlText:Hide()
            end
        end

        -- Show upgrade icon if this item is better than equipped (skip for empty slot stacks)
        if not itemData.isEmptySlotStack and button.UpgradeIcon then
            pcall(ns.Components.Slots.UpdateUpgradeIcon, button, itemData)
        end

        -- Disable "New item" animation and glow
        if button.NewItemTexture then
            button.NewItemTexture:Hide()
        end
        if button.BattlepayItemTexture then
            button.BattlepayItemTexture:Hide()
        end
        if button.ItemContextOverlay then
            button.ItemContextOverlay:Hide()
        end
        if button.flash then
            button.flash:Hide()
        end

        -- Remove from new items tracking
        -- DISABLED: This causes taint with UseContainerItem() when clicking items
        -- pcall(C_NewItems.RemoveNewItem, itemData.bagID, itemData.slotID)

        -- Clear any animations
        if button.flashAnim then
            button.flashAnim:Stop()
        end
        if button.newitemglowAnim then
            button.newitemglowAnim:Stop()
        end

        slot:SetAlpha(itemData.alpha or 1.0)
    end

    -- IMPORTANT: DO NOT touch OnClick, OnDragStart, OnReceiveDrag or tooltip scripts!
    -- The ContainerFrameItemButtonTemplate handles them securely!

    -- Show BOTH parent and ItemButton (like BetterBags does)
    slot:Show()
    button:Show()
end

-- Release a slot back to the pool
-- @param slot - Parent frame to release
function ns.Components.Slots.ReleaseSlot(slot)
    if not slot then return end

    -- Remove from active slots
    for i = #activeSlots, 1, -1 do
        if activeSlots[i] == slot then
            table.remove(activeSlots, i)
            break
        end
    end

    -- Get the ItemButton
    local button = slot.itemButton

    -- Clear slot
    slot:Hide()
    slot:ClearAllPoints()
    slot.itemData = nil

    -- Clear button
    if button then
        SetItemButtonTexture(button, nil)
        SetItemButtonCount(button, 0)
        -- DO NOT clear OnClick/OnDrag - they're managed by the template
    end

    -- DO NOT clear tooltip scripts - they're set once at creation and never modified!

    -- POOL DISABLED - don't add back to pool, let garbage collector handle it
    -- table.insert(slotPool, slot)
end

-- Release all active slots
function ns.Components.Slots.ReleaseAll()
    for i = #activeSlots, 1, -1 do
        local button = activeSlots[i]
        ns.Components.Slots.ReleaseSlot(button)
    end

    activeSlots = {}
end

-- Create a grid of slots
-- @param parent - Parent frame
-- @param items - Table of item data {slotKey = itemData}
-- @param columns - Number of columns
-- @param spacing - Spacing between slots
-- @param size - Size of each slot in pixels (optional, default: 37)
-- @return slots - Array of created slot buttons
function ns.Components.Slots.CreateGrid(parent, items, columns, spacing, size)
    columns = columns or 8
    spacing = spacing or 4
    local slotSize = size or 37

    local slots = {}
    local row = 0
    local col = 0

    -- Sort items by bag and slot, but put "Empty Slots" stack at the end
    local sortedItems = {}
    for slotKey, itemData in pairs(items) do
        table.insert(sortedItems, itemData)
    end

    table.sort(sortedItems, function(a, b)
        -- Always put "Empty Slots" stack at the end
        if a.isEmptySlotStack and not b.isEmptySlotStack then
            return false  -- a goes after b
        elseif not a.isEmptySlotStack and b.isEmptySlotStack then
            return true   -- a goes before b
        end

        -- Normal sorting for other items
        if a.bagID == b.bagID then
            return a.slotID < b.slotID
        end
        return a.bagID < b.bagID
    end)

    -- Create slots
    for i, itemData in ipairs(sortedItems) do
        local success, button = pcall(ns.Components.Slots.CreateSlot, parent, itemData, slotSize)

        if not success then
            -- Silent failure, slot creation error
            break
        end

        -- Position in grid
        local x = col * (slotSize + spacing)
        local y = -row * (slotSize + spacing)

        button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)

        table.insert(slots, button)

        -- Advance grid position
        col = col + 1
        if col >= columns then
            col = 0
            row = row + 1
        end
    end

    -- Update parent size
    local totalRows = math.ceil(#sortedItems / columns)
    local height = totalRows * (slotSize + spacing)
    parent:SetHeight(math.max(height, 50))

    return slots
end

-- Update upgrade icon for an item (show if better than equipped)
-- @param button - ItemButton
-- @param itemData - Item data
function ns.Components.Slots.UpdateUpgradeIcon(button, itemData)
    -- Create UpgradeIcon if it doesn't exist (ContainerFrameItemButtonTemplate should have it)
    if not button.UpgradeIcon then
        button.UpgradeIcon = button:CreateTexture(nil, "OVERLAY")
        button.UpgradeIcon:SetSize(15, 15)
        button.UpgradeIcon:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
        button.UpgradeIcon:SetAtlas("bags-greenarrow")
    end

    -- Hide by default
    button.UpgradeIcon:Hide()

    -- Only show for equippable items with inventory slots
    if not itemData.inventorySlots then
        return
    end

    -- Check if this item is better than what's equipped
    local currentItemLevel = itemData.currentItemLevel or 0
    if currentItemLevel <= 1 then
        return
    end

    -- Iterate through all possible inventory slots (like BetterBags does)
    for _, slot in ipairs(itemData.inventorySlots) do
        -- Special case: If this is an offhand, check if mainhand is a 2H weapon
        if slot == INVSLOT_OFFHAND then
            local mainhandLink = GetInventoryItemLink("player", INVSLOT_MAINHAND)
            if mainhandLink then
                local _, _, _, _, _, _, _, _, equipLoc = C_Item.GetItemInfo(mainhandLink)
                if equipLoc == "INVTYPE_2HWEAPON" or equipLoc == "INVTYPE_RANGED" then
                    -- Can't equip offhand with 2H weapon
                    button.UpgradeIcon:Hide()
                    break
                end
            end
        end

        -- Get equipped item in this slot
        local equippedLink = GetInventoryItemLink("player", slot)
        if equippedLink then
            -- Compare item levels
            local equippedLevel = C_Item.GetCurrentItemLevel(ItemLocation:CreateFromEquipmentSlot(slot)) or 0
            if currentItemLevel > equippedLevel then
                button.UpgradeIcon:Show()
                break
            end
        elseif slot >= INVSLOT_FIRST_EQUIPPED and slot <= INVSLOT_LAST_EQUIPPED then
            -- Empty slot, show upgrade icon
            button.UpgradeIcon:Show()
            break
        else
            button.UpgradeIcon:Hide()
        end
    end
end

-- Cleanup
function ns.Components.Slots.Destroy()
    ns.Components.Slots.ReleaseAll()
    slotPool = {}
    activeSlots = {}
end
