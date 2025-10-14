-- layouts/bank.lua - Beautiful Nihui-themed bank layout (70% bank / 30% backpack)
local addonName, ns = ...

ns.Layouts = ns.Layouts or {}
ns.Layouts.Bank = {}

-- Get constants (lazy load)
local function getConst()
    return ns.Components.Constants.Get()
end

-- Detect player faction (Horde or Alliance)
local function GetPlayerFaction()
    local factionGroup = UnitFactionGroup("player")
    if factionGroup == "Horde" then
        return "Horde"
    elseif factionGroup == "Alliance" then
        return "Alliance"
    end
    return "Horde" -- Default to Horde if detection fails
end

-- Get faction-specific atlas names
local function GetFactionAtlas()
    local faction = GetPlayerFaction()

    -- Alliance uses different naming (no dash between Frame and Corner)
    local cornerPrefix = faction == "Alliance" and (faction .. "FrameCorner-") or (faction .. "Frame-Corner-")

    return {
        cornerTopLeft = cornerPrefix .. "TopLeft",
        cornerTopRight = cornerPrefix .. "TopRight",
        cornerBottomLeft = cornerPrefix .. "BottomLeft",
        cornerBottomRight = cornerPrefix .. "BottomRight",
        header = faction .. "Frame-Header",
        bottom = "_" .. faction .. "FrameTile-Bottom",
        left = "!" .. faction .. "FrameTile-Left",
        titleLeft = faction .. "Frame_Title-End",
        titleCenter = "_" .. faction .. "Frame_Title-Tile",
        titleRight = faction .. "Frame_Title-End-2",
    }
end

-- Scale for borders and corners
local BORDER_SCALE = 0.45

-- Bank state
local bankFrame = nil
local contentContainer = nil  -- NEW: Wrapper for all normal content
local optionsView = nil        -- NEW: Options panel
local titleBar = nil           -- NEW: Reference to titleBar for close button hide/show
local viewContainer = nil  -- VIEW CONTAINER (contient bankContainer + backpackContainer)
local bankContainer = nil  -- Container pour bank (progress bar + scroll frame)
local backpackContainer = nil  -- Container pour backpack (progress bar + scroll frame)
local bankContentFrame = nil  -- ScrollFrame pour bank items
local backpackContentFrame = nil  -- ScrollFrame pour backpack items
local searchBox = nil  -- Une seule search box pour les deux côtés
local warbankMoneyFrame = nil  -- Warband bank money (left)
local playerMoneyFrame = nil   -- Player money (right)
local bankProgressBar = nil  -- Progress bar for bank
local backpackProgressBar = nil  -- Progress bar for backpack
local currentSearchText = ""  -- Une seule recherche
local bankCategoryHeaders = {}
local backpackCategoryHeaders = {}
local characterSelector = nil  -- Character selection dropdown
local viewingCharKey = nil     -- Current character being viewed (nil = current player)
local returnButton = nil       -- Button to return to current character

-- Dropzone state
local bankDropzone = nil  -- Dropzone overlay for bank (70% left)
local backpackDropzone = nil  -- Dropzone overlay for backpack (30% right)
local dropzoneUpdateFrame = nil  -- Frame for OnUpdate cursor detection

-- View mode (single mode for both bank and backpack in bank view)
-- Initialize from saved DB or default to category
local bankViewMode = nil  -- Will be initialized from ns.db.bankViewMode
local activeBankType = "regular"  -- "regular" or "warband"
local bankTabs = nil  -- Reference to bank type tabs
local purchaseButton = nil  -- Button to purchase bank slots

-- Flag to prevent recursive close calls
local isClosing = false

-- Check if viewing another character
local function IsViewingOther()
    if not viewingCharKey then return false end
    return viewingCharKey ~= ns.Components.Cache.GetCurrentCharacterKey()
end

-- Forward declarations (fonctions définies plus tard)
local TransferCategoryToBank
local TransferCategoryToBags
local FindFirstEmptySlot

-- Transfer modal overlay
local transferModal = nil

-- Create main bank frame with 70/30 split
local function CreateBankFrame()
    -- Main frame (larger than backpack)
    local frame = CreateFrame("Frame", "NihuiIVBank", UIParent)
    frame:SetSize(1000, 700)  -- Wider to accommodate 70/30 split
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetFrameStrata("HIGH")
    frame:SetFrameLevel(100)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:SetResizable(true)
    frame:SetResizeBounds(800, 500, 1400, 1000)
    frame:RegisterForDrag("LeftButton")
    frame:SetClampedToScreen(true)

    -- Background
    frame.bg = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    frame.bg:SetAllPoints()
    frame.bg:SetAtlas("characterupdate_background", true)
    frame.bg:SetAlpha(0.8)

    -- Darker overlay
    frame.overlay = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
    frame.overlay:SetAllPoints()
    frame.overlay:SetColorTexture(0, 0, 0, 0.5)

    -- Get faction atlas
    local atlas = GetFactionAtlas()

    -- Borders
    local borderSize = 40 * BORDER_SCALE

    -- Corners (decorative) - Always 80px larger than borders for perfect fit
    local cornerSize = borderSize + 80

    frame.cornerTL = frame:CreateTexture(nil, "OVERLAY", nil, 7)
    frame.cornerTL:SetSize(cornerSize, cornerSize)
    frame.cornerTL:SetPoint("TOPLEFT", frame, "TOPLEFT", -4, 4)
    frame.cornerTL:SetAtlas(atlas.cornerTopLeft, false)

    frame.cornerTR = frame:CreateTexture(nil, "OVERLAY", nil, 7)
    frame.cornerTR:SetSize(cornerSize, cornerSize)
    frame.cornerTR:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 4, 4)
    frame.cornerTR:SetAtlas(atlas.cornerTopLeft, false)
    frame.cornerTR:SetRotation(math.rad(270))

    frame.cornerBR = frame:CreateTexture(nil, "OVERLAY", nil, 7)
    frame.cornerBR:SetSize(cornerSize, cornerSize)
    frame.cornerBR:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 4, -4)
    frame.cornerBR:SetAtlas(atlas.cornerTopLeft, false)
    frame.cornerBR:SetRotation(math.rad(180))

    frame.cornerBL = frame:CreateTexture(nil, "OVERLAY", nil, 7)
    frame.cornerBL:SetSize(cornerSize, cornerSize)
    frame.cornerBL:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", -4, -4)
    frame.cornerBL:SetAtlas(atlas.cornerTopLeft, false)
    frame.cornerBL:SetRotation(math.rad(90))

    frame.borderBottom = frame:CreateTexture(nil, "BORDER", nil, 1)
    frame.borderBottom:SetHeight(borderSize)
    frame.borderBottom:SetPoint("BOTTOMLEFT", frame.cornerBL, "BOTTOMRIGHT", 0, 0)
    frame.borderBottom:SetPoint("BOTTOMRIGHT", frame.cornerBR, "BOTTOMLEFT", 0, 0)
    frame.borderBottom:SetAtlas(atlas.bottom, false)
    frame.borderBottom:SetHorizTile(true)

    frame.borderTop = frame:CreateTexture(nil, "BORDER", nil, 1)
    frame.borderTop:SetHeight(borderSize)
    frame.borderTop:SetPoint("TOPLEFT", frame.cornerTL, "TOPRIGHT", 0, 0)
    frame.borderTop:SetPoint("TOPRIGHT", frame.cornerTR, "TOPLEFT", 0, 0)
    frame.borderTop:SetAtlas(atlas.bottom, false)
    frame.borderTop:SetHorizTile(true)
    frame.borderTop:SetRotation(math.rad(180))

    frame.borderLeft = frame:CreateTexture(nil, "BORDER", nil, 1)
    frame.borderLeft:SetWidth(borderSize)
    frame.borderLeft:SetPoint("TOPLEFT", frame.cornerTL, "BOTTOMLEFT", 0, 0)
    frame.borderLeft:SetPoint("BOTTOMLEFT", frame.cornerBL, "TOPLEFT", 0, 0)
    frame.borderLeft:SetAtlas(atlas.left, false)
    frame.borderLeft:SetVertTile(true)

    frame.borderRight = frame:CreateTexture(nil, "BORDER", nil, 1)
    frame.borderRight:SetWidth(borderSize)
    frame.borderRight:SetPoint("TOPRIGHT", frame.cornerTR, "BOTTOMRIGHT", 0, 0)
    frame.borderRight:SetPoint("BOTTOMRIGHT", frame.cornerBR, "TOPRIGHT", 0, 0)
    frame.borderRight:SetAtlas(atlas.left, false)
    frame.borderRight:SetVertTile(true)
    frame.borderRight:SetRotation(math.rad(180))

    -- IMPORTANT: Create a separate high-level frame for borders/corners to stay above modal
    -- This frame will have a very high frameLevel so it's always on top
    local borderOverlay = CreateFrame("Frame", nil, frame)
    borderOverlay:SetAllPoints(frame)
    borderOverlay:SetFrameLevel(frame:GetFrameLevel() + 200)  -- WAY above everything (modal is +50)
    borderOverlay:EnableMouse(false)  -- Don't block mouse events

    -- Re-create corners on the overlay frame (copy from above)
    borderOverlay.cornerTL = borderOverlay:CreateTexture(nil, "OVERLAY", nil, 7)
    borderOverlay.cornerTL:SetSize(cornerSize, cornerSize)
    borderOverlay.cornerTL:SetPoint("TOPLEFT", frame, "TOPLEFT", -4, 4)
    borderOverlay.cornerTL:SetAtlas(atlas.cornerTopLeft, false)

    borderOverlay.cornerTR = borderOverlay:CreateTexture(nil, "OVERLAY", nil, 7)
    borderOverlay.cornerTR:SetSize(cornerSize, cornerSize)
    borderOverlay.cornerTR:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 4, 4)
    borderOverlay.cornerTR:SetAtlas(atlas.cornerTopLeft, false)
    borderOverlay.cornerTR:SetRotation(math.rad(270))

    borderOverlay.cornerBR = borderOverlay:CreateTexture(nil, "OVERLAY", nil, 7)
    borderOverlay.cornerBR:SetSize(cornerSize, cornerSize)
    borderOverlay.cornerBR:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 4, -4)
    borderOverlay.cornerBR:SetAtlas(atlas.cornerTopLeft, false)
    borderOverlay.cornerBR:SetRotation(math.rad(180))

    borderOverlay.cornerBL = borderOverlay:CreateTexture(nil, "OVERLAY", nil, 7)
    borderOverlay.cornerBL:SetSize(cornerSize, cornerSize)
    borderOverlay.cornerBL:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", -4, -4)
    borderOverlay.cornerBL:SetAtlas(atlas.cornerTopLeft, false)
    borderOverlay.cornerBL:SetRotation(math.rad(90))

    -- Re-create borders on the overlay frame
    borderOverlay.borderBottom = borderOverlay:CreateTexture(nil, "BORDER", nil, 1)
    borderOverlay.borderBottom:SetHeight(borderSize)
    borderOverlay.borderBottom:SetPoint("BOTTOMLEFT", borderOverlay.cornerBL, "BOTTOMRIGHT", 0, 0)
    borderOverlay.borderBottom:SetPoint("BOTTOMRIGHT", borderOverlay.cornerBR, "BOTTOMLEFT", 0, 0)
    borderOverlay.borderBottom:SetAtlas(atlas.bottom, false)
    borderOverlay.borderBottom:SetHorizTile(true)

    borderOverlay.borderTop = borderOverlay:CreateTexture(nil, "BORDER", nil, 1)
    borderOverlay.borderTop:SetHeight(borderSize)
    borderOverlay.borderTop:SetPoint("TOPLEFT", borderOverlay.cornerTL, "TOPRIGHT", 0, 0)
    borderOverlay.borderTop:SetPoint("TOPRIGHT", borderOverlay.cornerTR, "TOPLEFT", 0, 0)
    borderOverlay.borderTop:SetAtlas(atlas.bottom, false)
    borderOverlay.borderTop:SetHorizTile(true)
    borderOverlay.borderTop:SetRotation(math.rad(180))

    borderOverlay.borderLeft = borderOverlay:CreateTexture(nil, "BORDER", nil, 1)
    borderOverlay.borderLeft:SetWidth(borderSize)
    borderOverlay.borderLeft:SetPoint("TOPLEFT", borderOverlay.cornerTL, "BOTTOMLEFT", 0, 0)
    borderOverlay.borderLeft:SetPoint("BOTTOMLEFT", borderOverlay.cornerBL, "TOPLEFT", 0, 0)
    borderOverlay.borderLeft:SetAtlas(atlas.left, false)
    borderOverlay.borderLeft:SetVertTile(true)

    borderOverlay.borderRight = borderOverlay:CreateTexture(nil, "BORDER", nil, 1)
    borderOverlay.borderRight:SetWidth(borderSize)
    borderOverlay.borderRight:SetPoint("TOPRIGHT", borderOverlay.cornerTR, "BOTTOMRIGHT", 0, 0)
    borderOverlay.borderRight:SetPoint("BOTTOMRIGHT", borderOverlay.cornerBR, "TOPRIGHT", 0, 0)
    borderOverlay.borderRight:SetAtlas(atlas.left, false)
    borderOverlay.borderRight:SetVertTile(true)
    borderOverlay.borderRight:SetRotation(math.rad(180))

    -- Re-create bigHeader on the overlay frame (so it stays on top during modal)
    local faction = GetPlayerFaction()
    local headerYOffset = faction == "Horde" and 80 or 107

    borderOverlay.bigHeader = borderOverlay:CreateTexture(nil, "OVERLAY", nil, 7)
    borderOverlay.bigHeader:SetSize(512, 128)
    borderOverlay.bigHeader:SetPoint("TOP", frame, "TOP", 0, headerYOffset)
    borderOverlay.bigHeader:SetAtlas(atlas.header, true)
    borderOverlay.bigHeader:SetAlpha(1.0)

    frame.borderOverlay = borderOverlay

    -- Drag handlers
    frame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)

    -- Resize grip
    local resizeGrip = CreateFrame("Button", nil, frame)
    resizeGrip:SetSize(16, 16)
    resizeGrip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    resizeGrip:EnableMouse(true)
    resizeGrip:RegisterForDrag("LeftButton")
    resizeGrip:SetFrameLevel(frame:GetFrameLevel() + 1)

    resizeGrip.texture = resizeGrip:CreateTexture(nil, "OVERLAY")
    resizeGrip.texture:SetAllPoints()
    resizeGrip.texture:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")

    resizeGrip:SetScript("OnDragStart", function(self)
        frame:StartSizing("BOTTOMRIGHT")
    end)

    resizeGrip:SetScript("OnDragStop", function(self)
        frame:StopMovingOrSizing()
        if bankContentFrame and backpackContentFrame and bankFrame:IsShown() then
            ns.Layouts.Bank.RefreshAll()
        end
    end)

    frame:SetScript("OnSizeChanged", function(self, width, height)
        if bankContentFrame and backpackContentFrame and self:IsShown() then
            -- Hide all slots immediately to prevent overflow
            ns.Components.Slots.ReleaseAll()

            -- IMPORTANT: Update everything after a short delay
            -- to let WoW recalculate viewContainer:GetWidth() after bankFrame resize
            if self.resizeTimer then
                self.resizeTimer:Cancel()
            end
            self.resizeTimer = C_Timer.NewTimer(0.05, function()
                if self:IsShown() then
                    -- Update container sizes FIRST (now viewContainer has correct width!)
                    UpdateContentFrameSizes()

                    -- Update progress bars
                    if bankProgressBar and backpackProgressBar then
                        UpdateBankProgress()
                        UpdateBackpackProgress()
                    end

                    -- Refresh grids (APRÈS UpdateContentFrameSizes!)
                    RefreshBankItems()
                    RefreshBackpackItems()

                    -- Update money displays
                    if warbankMoneyFrame then warbankMoneyFrame:Update() end
                    if playerMoneyFrame then playerMoneyFrame:Update() end
                end
                self.resizeTimer = nil
            end)
        end
    end)

    frame.resizeGrip = resizeGrip

    -- ESC key handling via OnKeyDown
    frame:EnableKeyboard(true)
    frame:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            local handler = ns.Layouts.Bank._escapeHandler
            if handler then
                local handled = handler()
                if handled then
                    self:SetPropagateKeyboardInput(false)  -- Stop ESC from opening menu
                    return
                end
            end
            -- If not handled, let WoW process it (open menu)
            self:SetPropagateKeyboardInput(true)
        else
            -- Other keys: propagate normally
            self:SetPropagateKeyboardInput(true)
        end
    end)

    -- Handle OnHide to close bank interaction
    frame:SetScript("OnHide", function(self)
        -- Prevent recursive calls for bank closing logic
        if isClosing then return end
        isClosing = true

        -- When frame is hidden (ESC or programmatically), close bank interaction
        if C_Bank and C_Bank.CloseBankFrame then
            C_Bank.CloseBankFrame()
        end

        -- Reset flag after a short delay
        C_Timer.After(0.1, function() isClosing = false end)
    end)

    frame:Hide()
    return frame
end

-- Helper to create a tab with WoW atlas textures
local function CreateTab(parent, text, isActive)
    local tab = CreateFrame("Button", nil, parent)
    tab:SetSize(150, 32)

    -- Left part
    local left = tab:CreateTexture(nil, "BACKGROUND")
    left:SetSize(20, 32)
    left:SetPoint("LEFT", tab, "LEFT", 0, 0)
    left:SetAtlas(isActive and "uiframe-activetab-left" or "uiframe-tab-left", true)

    -- Center part (stretches)
    local center = tab:CreateTexture(nil, "BACKGROUND")
    center:SetPoint("LEFT", left, "RIGHT", 0, 0)
    center:SetPoint("RIGHT", tab, "RIGHT", -20, 0)
    center:SetHeight(32)
    center:SetAtlas(isActive and "_uiframe-activetab-center" or "_uiframe-tab-center", true)
    center:SetHorizTile(true)

    -- Right part
    local right = tab:CreateTexture(nil, "BACKGROUND")
    right:SetSize(20, 32)
    right:SetPoint("RIGHT", tab, "RIGHT", 0, 0)
    right:SetAtlas(isActive and "uiframe-activetab-right" or "uiframe-tab-right", true)

    -- Text label
    local label = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("CENTER", tab, "CENTER", 0, 0)
    label:SetText(text)

    -- Store textures for later updates
    tab.left = left
    tab.center = center
    tab.right = right
    tab.label = label

    return tab
end

-- Set tab as active or inactive
local function SetTabActive(tab, isActive)
    tab.left:SetAtlas(isActive and "uiframe-activetab-left" or "uiframe-tab-left", true)
    tab.center:SetAtlas(isActive and "_uiframe-activetab-center" or "_uiframe-tab-center", true)
    tab.right:SetAtlas(isActive and "uiframe-activetab-right" or "uiframe-tab-right", true)
end

-- Create bank type tabs (Regular / Warband)
local function CreateBankTabs(parent)
    local tabContainer = CreateFrame("Frame", nil, parent)
    tabContainer:SetSize(310, 32)
    -- Position at BOTTOM LEFT, outside the parent frame
    tabContainer:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", -5, -35)
    tabContainer:SetFrameStrata("HIGH")
    tabContainer:SetFrameLevel(parent:GetFrameLevel() + 10)

    local tabs = {}

    -- Regular Bank Tab (active by default)
    local regularTab = CreateTab(tabContainer, "Banque", true)
    regularTab:SetPoint("LEFT", tabContainer, "LEFT", 0, 0)

    -- Warband Bank Tab (inactive by default)
    local warbandTab = CreateTab(tabContainer, "Banque de bataille", false)
    warbandTab:SetPoint("LEFT", regularTab, "RIGHT", -5, 0)

    -- Tab click handlers
    regularTab:SetScript("OnClick", function()
        if activeBankType == "regular" then return end
        activeBankType = "regular"

        -- Update tab appearance
        SetTabActive(regularTab, true)
        SetTabActive(warbandTab, false)

        -- Update purchase button visibility
        if purchaseButton and purchaseButton.UpdateVisibility then
            purchaseButton.UpdateVisibility()
        end

        -- Refresh bank content
        ns.Layouts.Bank.RefreshAll()
    end)

    warbandTab:SetScript("OnClick", function()
        if activeBankType == "warband" then return end

        -- Check if warband bank is available
        local const = ns.Components.Constants.Get()
        if not const.ACCOUNT_BANK_BAGS or not next(const.ACCOUNT_BANK_BAGS) then
            ns:Print("Warband Bank is not available")
            return
        end

        activeBankType = "warband"

        -- Update tab appearance
        SetTabActive(warbandTab, true)
        SetTabActive(regularTab, false)

        -- Update purchase button visibility
        if purchaseButton and purchaseButton.UpdateVisibility then
            purchaseButton.UpdateVisibility()
        end

        -- Refresh bank content
        ns.Layouts.Bank.RefreshAll()
    end)

    tabs.container = tabContainer
    tabs.regularTab = regularTab
    tabs.warbandTab = warbandTab

    return tabs
end

-- Create purchase button for buying bank slots
local function CreatePurchaseButton(parent)
    -- Container for the native purchase button
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(28, 28)
    container:SetPoint("TOPLEFT", parent, "TOPLEFT", -35, -80)
    container:SetFrameStrata("HIGH")
    container:SetFrameLevel(parent:GetFrameLevel() + 10)

    -- Use WoW's native BankPanelPurchaseButtonScriptTemplate (has built-in purchase behavior)
    local btn = CreateFrame("Button", nil, container, "BankPanelPurchaseButtonScriptTemplate")
    btn:SetSize(28, 28)
    btn:SetPoint("CENTER")
    btn:SetAttribute("overrideBankType", Enum.BankType.Character)

    -- Black transparent background
    local bgTex = btn:CreateTexture(nil, "BACKGROUND", nil, -1)
    bgTex:SetAllPoints()
    bgTex:SetColorTexture(0, 0, 0, 0.7)  -- Black with 70% opacity

    -- Add button textures for visual style
    local normalTex = btn:CreateTexture(nil, "BACKGROUND")
    normalTex:SetAtlas("UI-HUD-ActionBar-IconFrame-AddRow", true)
    normalTex:SetAllPoints()
    normalTex:SetVertexColor(0.8, 0.8, 0.8, 1)
    btn:SetNormalTexture(normalTex)

    local hoverTex = btn:CreateTexture(nil, "HIGHLIGHT")
    hoverTex:SetAtlas("UI-HUD-ActionBar-IconFrame-AddRow", true)
    hoverTex:SetAllPoints()
    hoverTex:SetVertexColor(1, 1, 0.8, 1)
    hoverTex:SetBlendMode("ADD")
    btn:SetHighlightTexture(hoverTex)

    local pushedTex = btn:CreateTexture(nil, "ARTWORK")
    pushedTex:SetAtlas("UI-HUD-ActionBar-IconFrame-AddRow", true)
    pushedTex:SetAllPoints()
    pushedTex:SetVertexColor(0.6, 0.6, 0.6, 1)
    btn:SetPushedTexture(pushedTex)

    -- Simple "+" text on top
    local plusText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    plusText:SetPoint("CENTER", 0, 1)
    plusText:SetText("+")
    plusText:SetTextColor(0, 1, 0, 1)  -- Green color
    plusText:SetDrawLayer("OVERLAY", 7)  -- Make sure it's on top

    -- Store references
    container.btn = btn
    container.plusText = plusText

    -- Update button visibility based on purchase status
    local function UpdateVisibility()
        if activeBankType == "regular" then
            -- Update attribute for character bank
            btn:SetAttribute("overrideBankType", Enum.BankType.Character)
            -- Check if max tabs reached
            if C_Bank and C_Bank.HasMaxBankTabs and C_Bank.HasMaxBankTabs(Enum.BankType.Character) then
                container:Hide()
            else
                container:Show()
            end
        else
            -- Update attribute for warband bank
            btn:SetAttribute("overrideBankType", Enum.BankType.Account)
            -- Check if max tabs reached
            if C_Bank and C_Bank.HasMaxBankTabs and C_Bank.HasMaxBankTabs(Enum.BankType.Account) then
                container:Hide()
            else
                container:Show()
            end
        end
    end

    -- Hover effect for the "+" text
    btn:HookScript("OnEnter", function(self)
        plusText:SetTextColor(1, 1, 0, 1)  -- Yellow on hover
    end)

    btn:HookScript("OnLeave", function(self)
        plusText:SetTextColor(0, 1, 0, 1)  -- Back to green
    end)

    -- Store update function for external calls
    container.UpdateVisibility = UpdateVisibility

    -- Initial visibility check
    UpdateVisibility()

    return container
end

-- Create title bar
local function CreateTitleBar(parent)
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetPoint("TOPLEFT", parent, "TOPLEFT", 33, -45)
    bar:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -33, -45)
    bar:SetHeight(32)

    local atlas = GetFactionAtlas()

    -- Big decorative header
    local faction = GetPlayerFaction()
    local headerYOffset = faction == "Horde" and 80 or 107

    local bigHeader = parent:CreateTexture(nil, "OVERLAY", nil, 7)
    bigHeader:SetSize(512, 128)
    bigHeader:SetPoint("TOP", parent, "TOP", 0, headerYOffset)
    bigHeader:SetAtlas(atlas.header, true)
    bigHeader:SetAlpha(1.0)
    bar.bigHeader = bigHeader

    -- Create invisible button on top of bigHeader for dragging
    local bigHeaderButton = CreateFrame("Button", nil, bar)
    bigHeaderButton:SetSize(512, 128)
    bigHeaderButton:SetPoint("TOP", parent, "TOP", 0, headerYOffset)
    bigHeaderButton:EnableMouse(true)
    bigHeaderButton:RegisterForDrag("LeftButton")
    bigHeaderButton:SetFrameLevel(bar:GetFrameLevel() + 10)

    -- Drag handlers for bigHeader
    bigHeaderButton:SetScript("OnDragStart", function(self)
        parent:StartMoving()
    end)
    bigHeaderButton:SetScript("OnDragStop", function(self)
        parent:StopMovingOrSizing()
    end)

    bar.bigHeaderButton = bigHeaderButton

    -- Character selector (portrait + name dropdown) - LEFT side
    if ns.Components.CharacterSelect then
        characterSelector = ns.Components.CharacterSelect.Create(bar, "bank")
        characterSelector:SetPoint("LEFT", bar, "LEFT", 0, 0)

        -- Set callback for character change
        characterSelector:SetCallback(function(charKey, bagType)
            viewingCharKey = charKey
            ns.Layouts.Bank.RefreshAll()

            -- Show/hide return button
            if returnButton then
                if IsViewingOther() then
                    returnButton:Show()
                else
                    returnButton:Hide()
                end
            end

            -- Disable sort button when viewing another character
            if bar.sortButton then
                if IsViewingOther() then
                    bar.sortButton:Hide()
                else
                    if bankViewMode == "all" then
                        bar.sortButton:Show()
                    end
                end
            end
        end)
    end

    -- Return button (returns to current character, shown only when viewing another character)
    returnButton = CreateFrame("Button", nil, bar)
    returnButton:SetSize(120, 24)
    returnButton:SetPoint("LEFT", characterSelector or bar, characterSelector and "RIGHT" or "LEFT", characterSelector and 16 or 0, 0)

    -- Button background
    local returnBg = returnButton:CreateTexture(nil, "BACKGROUND")
    returnBg:SetAllPoints()
    returnBg:SetColorTexture(0.2, 0.2, 0.2, 0.7)
    returnButton.bg = returnBg

    -- Button text
    local returnText = returnButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    returnText:SetPoint("CENTER", returnButton, "CENTER", 0, 0)
    returnText:SetText("Return to Current")
    returnText:SetTextColor(1, 0.82, 0, 1)
    returnButton.text = returnText

    -- Hover effect with tooltip
    returnButton:SetScript("OnEnter", function(self)
        self.bg:SetColorTexture(0.3, 0.3, 0.3, 0.9)
        self.text:SetTextColor(1, 1, 1, 1)

        -- Show tooltip
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Return to Your Inventory", 1, 0.82, 0, 1)
        GameTooltip:AddLine("Stop viewing cached data and return to your current character", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    returnButton:SetScript("OnLeave", function(self)
        self.bg:SetColorTexture(0.2, 0.2, 0.2, 0.7)
        self.text:SetTextColor(1, 0.82, 0, 1)
        GameTooltip:Hide()
    end)

    -- Click handler
    returnButton:SetScript("OnClick", function()
        if characterSelector and characterSelector.ReturnToCurrent then
            characterSelector:ReturnToCurrent()
        end
    end)

    -- Hide by default (only shown when viewing another character)
    returnButton:Hide()

    -- Sort button (bag icon, LEFT of options button)
    bar.sortButton = CreateFrame("Button", nil, bar)
    bar.sortButton:SetSize(24, 24)
    bar.sortButton:SetPoint("RIGHT", bar, "RIGHT", -60, 0) -- 60px before right edge (30 for close, 30 for options)

    -- Sort icon
    bar.sortButton.icon = bar.sortButton:CreateTexture(nil, "ARTWORK")
    bar.sortButton.icon:SetAllPoints()
    bar.sortButton.icon:SetAtlas("bags-icon")
    bar.sortButton.icon:SetVertexColor(1, 0.82, 0, 1)

    -- Hover effect
    bar.sortButton:SetScript("OnEnter", function(self)
        self.icon:SetVertexColor(1, 1, 1, 1)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Sort All Items", 1, 1, 1)
        GameTooltip:AddLine("Sorts all items in bank and bags by quality", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine("Tip: You can also middle-click inside to sort", 0.5, 0.8, 1, true)
        GameTooltip:Show()
    end)
    bar.sortButton:SetScript("OnLeave", function(self)
        self.icon:SetVertexColor(1, 0.82, 0, 1)
        GameTooltip:Hide()
    end)

    bar.sortButton:SetScript("OnClick", function()
        ns.Layouts.Bank.SortItems()
    end)

    -- Options button (gear icon, aligned RIGHT before close button)
    bar.optionsButton = CreateFrame("Button", nil, bar)
    bar.optionsButton:SetSize(24, 24)
    bar.optionsButton:SetPoint("RIGHT", bar, "RIGHT", -30, 0) -- 30px before right edge (leave room for close button)

    -- Gear icon (atlas: GarrMission_MissionIcon-Engineering)
    bar.optionsButton.icon = bar.optionsButton:CreateTexture(nil, "ARTWORK")
    bar.optionsButton.icon:SetAllPoints()
    bar.optionsButton.icon:SetAtlas("GarrMission_MissionIcon-Engineering")  -- Engineering icon (gear)
    bar.optionsButton.icon:SetVertexColor(1, 0.82, 0, 1) -- Gold color

    -- Hover effect
    bar.optionsButton:SetScript("OnEnter", function(self)
        self.icon:SetVertexColor(1, 1, 1, 1) -- White on hover
    end)
    bar.optionsButton:SetScript("OnLeave", function(self)
        self.icon:SetVertexColor(1, 0.82, 0, 1) -- Gold normally
    end)

    bar.optionsButton:SetScript("OnClick", function()
        ns.Layouts.Bank.ToggleOptions()
    end)

    -- Close button
    bar.closeButton = CreateFrame("Button", nil, bar)
    bar.closeButton:SetSize(24, 24)
    bar.closeButton:SetPoint("RIGHT", bar, "RIGHT", 0, 0)

    local hasTexture = false
    pcall(function()
        bar.closeButton:SetNormalTexture("Interface\\AddOns\\Nihui_iv\\media\\close")
        bar.closeButton:SetHighlightTexture("Interface\\AddOns\\Nihui_iv\\media\\close")
        if bar.closeButton:GetNormalTexture():GetTexture() then
            bar.closeButton:GetHighlightTexture():SetAlpha(0.5)
            hasTexture = true
        end
    end)

    if not hasTexture then
        bar.closeButton:SetNormalFontObject("GameFontNormalLarge")
        bar.closeButton:SetText("×")
        local fontString = bar.closeButton:GetFontString()
        if fontString then
            fontString:SetTextColor(1, 0.82, 0, 1)
        end
    end

    bar.closeButton:SetScript("OnClick", function()
        -- Prevent recursive calls
        if isClosing then return end
        isClosing = true

        -- Close the bank interaction properly (like BetterBags does)
        if C_Bank and C_Bank.CloseBankFrame then
            C_Bank.CloseBankFrame()
        end
        -- The SetCloseInteractionCallback will then hide our frame

        -- Reset flag after a short delay
        C_Timer.After(0.1, function() isClosing = false end)
    end)

    return bar
end

-- Create centered search box (above both bank and backpack)
local function CreateSearchBox(parent, onTextChanged)
    local container = CreateFrame("Frame", nil, parent)
    container:SetPoint("TOPLEFT", parent, "TOPLEFT", 33, -85)  -- Après le titre
    container:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -33, -85)
    container:SetHeight(48)

    -- Background (black panel)
    local bg = container:CreateTexture(nil, "BACKGROUND", nil, 0)
    bg:SetHeight(40)
    bg:SetPoint("LEFT", container, "LEFT", 0, 0)
    bg:SetPoint("RIGHT", container, "RIGHT", 0, 0)
    bg:SetColorTexture(0, 0, 0, 0.45) -- Black background, 45% opacity
    container.bg = bg

    -- Border frame (extended beyond container like progress bars)
    local border = CreateFrame("Frame", nil, container, "BackdropTemplate")
    border:SetPoint("TOPLEFT", bg, "TOPLEFT", -12, 12)
    border:SetPoint("BOTTOMRIGHT", bg, "BOTTOMRIGHT", 12, -12)
    border:SetBackdrop({
        edgeFile = "Interface\\AddOns\\Nihui_uf\\textures\\MirroredFrameSingleUF.tga",
        edgeSize = 16,
        insets = {left = 1, right = 1, top = 1, bottom = 1}
    })
    border:SetBackdropBorderColor(0.5, 0.5, 0.5, 1) -- Gray border
    border:SetFrameLevel(container:GetFrameLevel() + 5) -- Above content

    local box = CreateFrame("EditBox", nil, container)
    box:SetPoint("LEFT", bg, "LEFT", 12, 0) -- 12px left padding
    box:SetPoint("RIGHT", bg, "RIGHT", -12, 0) -- 12px right padding
    box:SetHeight(40)
    box:SetAutoFocus(false)
    box:SetFontObject("GameFontNormal")
    box:SetTextInsets(0, 0, 0, 0)
    box:SetTextColor(1, 0.82, 0, 1)
    box:SetMaxLetters(50)

    if box.Left then box.Left:Hide() end
    if box.Right then box.Right:Hide() end
    if box.Middle then box.Middle:Hide() end

    box.placeholder = box:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    box.placeholder:SetPoint("LEFT", box, "LEFT", 0, 0)
    box.placeholder:SetText("Search in bank and bags...")
    box.placeholder:SetTextColor(1, 0.82, 0, 0.5)
    box.placeholder:SetJustifyH("LEFT")

    box:SetScript("OnTextChanged", function(self, userInput)
        if userInput then
            local text = self:GetText()
            if text == "" then
                box.placeholder:Show()
            else
                box.placeholder:Hide()
            end

            if onTextChanged then
                onTextChanged(text)
            end
        end
    end)

    box:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        self:SetText("")
        -- IMPORTANT: Reset search text and refresh to clear opacity filter
        currentSearchText = ""
        ns.Layouts.Bank.RefreshAll()
    end)

    box:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)

    box:SetScript("OnEditFocusGained", function(self)
        self:HighlightText(0, 0)
    end)

    container.editBox = box
    return container
end

-- Create progress bar (EXACT comme Nihui_uf/ui/bar.lua)
local function CreateProgressBar(parent)
    -- Container frame (pour le statusBar)
    local container = CreateFrame("Frame", nil, parent)
    container:SetHeight(14)  -- Augmenté de 12 à 14 pour meilleur rendu du glass

    -- Background (texture g1 assombrie comme bar.lua)
    local bg = container:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\AddOns\\Nihui_uf\\textures\\g1.tga")
    bg:SetAllPoints(container)
    bg:SetVertexColor(0.1, 0.1, 0.1, 0.8)  -- Assombri comme bar.lua

    -- Status bar (main bar)
    local statusBar = CreateFrame("StatusBar", nil, container)
    statusBar:SetAllPoints()
    statusBar:SetStatusBarTexture("Interface\\AddOns\\Nihui_uf\\textures\\g1.tga")
    statusBar:SetMinMaxValues(0, 1)
    statusBar:SetValue(0)

    -- Glass overlay (effet brillant comme bar.lua)
    local glass = statusBar:CreateTexture(nil, "ARTWORK", nil, 7)
    glass:SetTexture("Interface\\AddOns\\Nihui_uf\\textures\\HPglass.tga")
    glass:SetPoint("TOPLEFT", statusBar, "TOPLEFT", 0, 0)
    glass:SetPoint("BOTTOMRIGHT", statusBar, "BOTTOMRIGHT", 0, 0)
    glass:SetTextureSliceMargins(16, 16, 16, 16)
    glass:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
    glass:SetAlpha(0.2)
    glass:SetBlendMode("ADD")

    -- Border (EXACT comme bar.lua - frame séparé avec insets)
    local border = CreateFrame("Frame", nil, container, "BackdropTemplate")
    local leftInset = -12
    local topInset = 12
    local rightInset = 12
    local bottomInset = -12

    border:SetPoint("TOPLEFT", container, "TOPLEFT", leftInset, topInset)
    border:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", rightInset, bottomInset)
    border:SetBackdrop({
        edgeFile = "Interface\\AddOns\\Nihui_uf\\textures\\MirroredFrameSingleUF.tga",
        edgeSize = 16,
        insets = {left = 1, right = 1, top = 1, bottom = 1}
    })
    border:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    border:SetFrameLevel(container:GetFrameLevel() + 2)
    border:Show()

    -- Spark (animated glow at fill position)
    local spark = statusBar:CreateTexture(nil, "OVERLAY", nil, 6)
    spark:SetTexture("Interface\\AddOns\\Nihui_uf\\textures\\orangespark.tga")
    spark:SetSize(20, 14)  -- Hauteur fixe à 14px (même que la progress bar)
    spark:SetBlendMode("ADD")
    spark:Show()

    -- Text (X/Y) - positioned to the right of the bar
    local text = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("LEFT", container, "RIGHT", 5, 0)
    text:SetText("0/0")
    text:SetTextColor(1, 0.82, 0, 1)
    text:SetJustifyH("LEFT")

    container.statusBar = statusBar
    container.spark = spark
    container.text = text
    container.bg = bg
    container.glass = glass
    container.border = border

    return container
end

-- Update progress bar with free/total slots
local function UpdateProgressBar(progressBar, freeSlots, totalSlots)
    if not progressBar then return end

    local usedSlots = totalSlots - freeSlots
    local usedPercent = usedSlots / totalSlots

    -- Update bar value
    progressBar.statusBar:SetMinMaxValues(0, totalSlots)
    progressBar.statusBar:SetValue(usedSlots)

    -- Update text
    progressBar.text:SetText(string.format("%d/%d", usedSlots, totalSlots))

    -- Calculate color based on % free
    local freePercent = freeSlots / totalSlots
    local r, g, b

    if freePercent >= 0.4 then
        -- 40%+ free = Green
        r, g, b = 0.2, 1, 0.2
    elseif freePercent >= 0.1 then
        -- 10-40% free = Orange
        r, g, b = 1, 0.7, 0
    else
        -- <10% free = Red
        r, g, b = 1, 0.2, 0.2
    end

    progressBar.statusBar:SetStatusBarColor(r, g, b, 1)

    -- Update spark position
    local barWidth = progressBar.statusBar:GetWidth()
    local sparkPos = barWidth * usedPercent
    progressBar.spark:ClearAllPoints()
    progressBar.spark:SetPoint("CENTER", progressBar.statusBar, "LEFT", sparkPos, 0)
end

-- Create VIEW container (parent de 70/30 split, entre search et footer)
local function CreateViewContainer(parent)
    local view = CreateFrame("Frame", nil, parent)
    -- Positionné entre search box (-159) et footer (+65 depuis le bas)
    -- IMPORTANT: y POSITIF pour BOTTOMRIGHT = vers le HAUT depuis le bas!
    view:SetPoint("TOPLEFT", parent, "TOPLEFT", 33, -159)  -- Increased for enlarged search box (85 + 48 + 26)
    view:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -33, 65)  -- Reduced from 80 for more content space
    return view
end

-- Create content frames with 70/30 split (avec conteneurs pour progress bars)
local function CreateContentFrames(viewParent)
    local frames = {}

    -- Bank CONTAINER (70% - contient progress bar + scroll frame)
    -- NOTE: Enfant de viewContainer, pas de bankFrame!
    -- NOTE: Ne PAS positionner ici, UpdateContentFrameSizes() s'en chargera
    local bankCont = CreateFrame("Frame", nil, viewParent)

    -- Background (black panel)
    local bankBg = bankCont:CreateTexture(nil, "BACKGROUND")
    bankBg:SetAllPoints(bankCont)
    bankBg:SetColorTexture(0, 0, 0, 0.45)  -- Black background, 45% opacity

    -- Border frame (extended beyond container like progress bars)
    local bankBorder = CreateFrame("Frame", nil, bankCont, "BackdropTemplate")
    bankBorder:SetPoint("TOPLEFT", bankCont, "TOPLEFT", -12, 12)
    bankBorder:SetPoint("BOTTOMRIGHT", bankCont, "BOTTOMRIGHT", 12, -12)
    bankBorder:SetBackdrop({
        edgeFile = "Interface\\AddOns\\Nihui_uf\\textures\\MirroredFrameSingleUF.tga",
        edgeSize = 16,
        insets = {left = 1, right = 1, top = 1, bottom = 1}
    })
    bankBorder:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)  -- Gray border
    bankBorder:SetFrameLevel(bankCont:GetFrameLevel() + 5)  -- Above content

    -- Bank ScrollFrame (DANS le container, sous la progress bar, WITH PADDING)
    -- Ancré RELATIVEMENT au container avec padding intérieur
    local bankScroll = CreateFrame("ScrollFrame", "NihuiIVBankScrollFrame", bankCont, "UIPanelScrollFrameTemplate")
    bankScroll:SetPoint("TOPLEFT", bankCont, "TOPLEFT", 8, -28)  -- 8px left padding, -28 pour progress bar + padding top
    bankScroll:SetPoint("BOTTOMRIGHT", bankCont, "BOTTOMRIGHT", -8, 8)  -- 8px padding right/bottom
    bankScroll:SetClipsChildren(true)
    bankScroll:EnableMouse(true) -- Enable mouse for middle-click detection
    bankScroll:EnableMouseWheel(true)

    -- Middle-click to sort (using OnMouseUp directly on scrollFrame)
    -- Items in scrollChild will still receive their own click events (higher frameLevel)
    -- Disabled when viewing another character's inventory
    bankScroll:SetScript("OnMouseUp", function(self, button)
        if button == "MiddleButton" and MouseIsOver(self) and bankViewMode == "all" and not IsViewingOther() then
            ns.Layouts.Bank.SortItems()
        end
    end)

    local bankScrollChild = CreateFrame("Frame", "NihuiIVBankScrollChild", bankScroll)
    bankScrollChild:SetSize(1, 1)
    bankScrollChild:EnableMouse(false)
    bankScroll:SetScrollChild(bankScrollChild)
    bankScroll.scrollChild = bankScrollChild

    -- Style scrollbar
    if bankScroll.ScrollBar then
        bankScroll.ScrollBar:ClearAllPoints()
        bankScroll.ScrollBar:SetPoint("TOPRIGHT", bankScroll, "TOPRIGHT", 0, -16)
        bankScroll.ScrollBar:SetPoint("BOTTOMRIGHT", bankScroll, "BOTTOMRIGHT", 0, 16)
        if bankScroll.ScrollBar.ScrollUpButton then
            bankScroll.ScrollBar.ScrollUpButton:SetSize(12, 12)
        end
        if bankScroll.ScrollBar.ScrollDownButton then
            bankScroll.ScrollBar.ScrollDownButton:SetSize(12, 12)
        end
        if bankScroll.ScrollBar.ThumbTexture then
            bankScroll.ScrollBar.ThumbTexture:SetWidth(12)
        end
    end

    frames.bankCont = bankCont
    frames.bankScroll = bankScroll

    -- Backpack CONTAINER (30% - contient progress bar + scroll frame)
    -- NOTE: Enfant de viewContainer, pas de bankFrame!
    -- NOTE: Ne PAS positionner ici, UpdateContentFrameSizes() s'en chargera
    local backpackCont = CreateFrame("Frame", nil, viewParent)

    -- Background (black panel)
    local backpackBg = backpackCont:CreateTexture(nil, "BACKGROUND")
    backpackBg:SetAllPoints(backpackCont)
    backpackBg:SetColorTexture(0, 0, 0, 0.45)  -- Black background, 45% opacity

    -- Border frame (extended beyond container like progress bars)
    local backpackBorder = CreateFrame("Frame", nil, backpackCont, "BackdropTemplate")
    backpackBorder:SetPoint("TOPLEFT", backpackCont, "TOPLEFT", -12, 12)
    backpackBorder:SetPoint("BOTTOMRIGHT", backpackCont, "BOTTOMRIGHT", 12, -12)
    backpackBorder:SetBackdrop({
        edgeFile = "Interface\\AddOns\\Nihui_uf\\textures\\MirroredFrameSingleUF.tga",
        edgeSize = 16,
        insets = {left = 1, right = 1, top = 1, bottom = 1}
    })
    backpackBorder:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)  -- Gray border
    backpackBorder:SetFrameLevel(backpackCont:GetFrameLevel() + 5)  -- Above content

    -- Backpack ScrollFrame (DANS le container, sous la progress bar, WITH PADDING)
    -- Ancré RELATIVEMENT au container avec padding intérieur
    local backpackScroll = CreateFrame("ScrollFrame", "NihuiIVBankBackpackScrollFrame", backpackCont, "UIPanelScrollFrameTemplate")
    backpackScroll:SetPoint("TOPLEFT", backpackCont, "TOPLEFT", 8, -28)  -- 8px left padding, -28 pour progress bar + padding top
    backpackScroll:SetPoint("BOTTOMRIGHT", backpackCont, "BOTTOMRIGHT", -8, 8)  -- 8px padding right/bottom
    backpackScroll:SetClipsChildren(true)
    backpackScroll:EnableMouse(true) -- Enable mouse for middle-click detection
    backpackScroll:EnableMouseWheel(true)

    -- Middle-click to sort (using OnMouseUp directly on scrollFrame)
    -- Items in scrollChild will still receive their own click events (higher frameLevel)
    -- Disabled when viewing another character's inventory
    backpackScroll:SetScript("OnMouseUp", function(self, button)
        if button == "MiddleButton" and MouseIsOver(self) and bankViewMode == "all" and not IsViewingOther() then
            ns.Layouts.Bank.SortItems()
        end
    end)

    local backpackScrollChild = CreateFrame("Frame", "NihuiIVBankBackpackScrollChild", backpackScroll)
    backpackScrollChild:SetSize(1, 1)
    backpackScrollChild:EnableMouse(false)
    backpackScroll:SetScrollChild(backpackScrollChild)
    backpackScroll.scrollChild = backpackScrollChild

    -- Style scrollbar
    if backpackScroll.ScrollBar then
        backpackScroll.ScrollBar:ClearAllPoints()
        backpackScroll.ScrollBar:SetPoint("TOPRIGHT", backpackScroll, "TOPRIGHT", 0, -16)
        backpackScroll.ScrollBar:SetPoint("BOTTOMRIGHT", backpackScroll, "BOTTOMRIGHT", 0, 16)
        if backpackScroll.ScrollBar.ScrollUpButton then
            backpackScroll.ScrollBar.ScrollUpButton:SetSize(12, 12)
        end
        if backpackScroll.ScrollBar.ScrollDownButton then
            backpackScroll.ScrollBar.ScrollDownButton:SetSize(12, 12)
        end
        if backpackScroll.ScrollBar.ThumbTexture then
            backpackScroll.ScrollBar.ThumbTexture:SetWidth(12)
        end
    end

    frames.backpackCont = backpackCont
    frames.backpackScroll = backpackScroll

    return frames
end

-- Create dropzone overlays for drag & drop
local function CreateDropzones(parent)
    -- Bank dropzone (LEFT - 70%)
    local bankDrop = CreateFrame("Button", nil, parent)
    bankDrop:SetFrameLevel(parent:GetFrameLevel() + 10)  -- Above everything
    bankDrop:EnableMouse(true)
    bankDrop:RegisterForClicks("AnyUp")  -- Detect any mouse button release

    -- Background overlay (semi-transparent purple)
    bankDrop.bg = bankDrop:CreateTexture(nil, "BACKGROUND")
    bankDrop.bg:SetAllPoints()
    bankDrop.bg:SetColorTexture(0.58, 0.51, 0.79, 0.3)  -- Nihui purple 30% opacity

    -- Border (golden)
    bankDrop.border = bankDrop:CreateTexture(nil, "BORDER")
    bankDrop.border:SetAllPoints()
    bankDrop.border:SetColorTexture(1, 0.82, 0, 0.8)  -- Gold
    bankDrop.border:SetDrawLayer("BORDER", 2)

    -- Inner frame (to create border effect)
    bankDrop.inner = bankDrop:CreateTexture(nil, "BORDER")
    bankDrop.inner:SetPoint("TOPLEFT", bankDrop, "TOPLEFT", 2, -2)
    bankDrop.inner:SetPoint("BOTTOMRIGHT", bankDrop, "BOTTOMRIGHT", -2, 2)
    bankDrop.inner:SetColorTexture(0.58, 0.51, 0.79, 0.3)
    bankDrop.inner:SetDrawLayer("BORDER", 3)

    -- Label text
    bankDrop.label = bankDrop:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    bankDrop.label:SetPoint("CENTER")
    bankDrop.label:SetText(" Click here to DEPOSIT ")
    bankDrop.label:SetTextColor(1, 0.82, 0, 1)

    bankDrop:Hide()  -- Hidden by default

    -- Backpack dropzone (RIGHT - 30%)
    local backpackDrop = CreateFrame("Button", nil, parent)
    backpackDrop:SetFrameLevel(parent:GetFrameLevel() + 10)
    backpackDrop:EnableMouse(true)
    backpackDrop:RegisterForClicks("AnyUp")

    backpackDrop.bg = backpackDrop:CreateTexture(nil, "BACKGROUND")
    backpackDrop.bg:SetAllPoints()
    backpackDrop.bg:SetColorTexture(0.58, 0.51, 0.79, 0.3)

    backpackDrop.border = backpackDrop:CreateTexture(nil, "BORDER")
    backpackDrop.border:SetAllPoints()
    backpackDrop.border:SetColorTexture(1, 0.82, 0, 0.8)
    backpackDrop.border:SetDrawLayer("BORDER", 2)

    backpackDrop.inner = backpackDrop:CreateTexture(nil, "BORDER")
    backpackDrop.inner:SetPoint("TOPLEFT", backpackDrop, "TOPLEFT", 2, -2)
    backpackDrop.inner:SetPoint("BOTTOMRIGHT", backpackDrop, "BOTTOMRIGHT", -2, 2)
    backpackDrop.inner:SetColorTexture(0.58, 0.51, 0.79, 0.3)
    backpackDrop.inner:SetDrawLayer("BORDER", 3)

    backpackDrop.label = backpackDrop:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    backpackDrop.label:SetPoint("CENTER")
    backpackDrop.label:SetText(" Click here to WITHDRAW ")
    backpackDrop.label:SetTextColor(1, 0.82, 0, 1)

    backpackDrop:Hide()

    return {bankDrop = bankDrop, backpackDrop = backpackDrop}
end

-- Create warband money display (left side - for bank)
local function CreateWarbankMoneyDisplay(parent)
    local frame = ns.Components.Money.Create(parent, true)  -- true = warband bank money
    frame:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 33, 38)  -- Reduced from 50 for more content space
    return frame
end

-- Create player money display (right side - for backpack)
local function CreatePlayerMoneyDisplay(parent)
    local frame = ns.Components.Money.Create(parent, false)  -- false = player money
    frame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -33, 38)  -- Reduced from 50 for more content space
    return frame
end

-- Create category header (reuse logic from backpack)
-- @param isBankHeader - true si c'est un header de la banque, false pour inventaire
local function GetOrCreateCategoryHeader(categoryName, parent, maxWidth, headerCache, isBankHeader)
    if headerCache[categoryName] then
        local header = headerCache[categoryName]
        header:SetWidth(maxWidth)
        if header.headerText then
            header.headerText:Show()
        end
        return header
    end

    local header = CreateFrame("Frame", nil, parent)
    header:SetHeight(36)  -- Augmenté de 28 à 36 pour plus d'espace
    header:SetWidth(maxWidth)

    local headerText = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    headerText:SetText(categoryName)
    headerText:SetJustifyH("LEFT")
    headerText:SetJustifyV("TOP")
    headerText:SetTextColor(1, 0.82, 0, 1)
    headerText:SetDrawLayer("OVERLAY", 7)
    headerText:Show()
    header.headerText = headerText

    headerText:SetPoint("TOPLEFT", header, "TOPLEFT", 0, -8)

    -- Bouton d'auto-transfert (pas pour "Empty Slots" ni "Uncategorized")
    -- Les boutons sont TOUJOURS affichés en mode category, pas besoin d'option
    if categoryName ~= "Empty Slots" and categoryName ~= "Uncategorized" then
        -- Use modern WoW button template
        local transferBtn = CreateFrame("Button", nil, header, "UIPanelButtonTemplate")
        transferBtn:SetSize(24, 24)
        transferBtn:SetPoint("LEFT", headerText, "RIGHT", 5, 0)

        -- Icon texture (using modern dropdown icons)
        local icon = transferBtn:CreateTexture(nil, "OVERLAY")
        icon:SetSize(10, 10)
        icon:SetPoint("CENTER")

        if isBankHeader then
            -- Bank header: arrow right (transfer FROM bank TO bags)
            icon:SetAtlas("common-dropdown-icon-next")
            transferBtn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText("Transfer to Bags", 1, 1, 1)
                GameTooltip:AddLine("Transfers all " .. categoryName .. " items from the bank to your bags", 0.8, 0.8, 0.8, true)
                GameTooltip:Show()
            end)

            transferBtn:SetScript("OnClick", function(self)
                TransferCategoryToBags(categoryName)
            end)
        else
            -- Backpack header: arrow left (transfer FROM bags TO bank)
            icon:SetAtlas("common-dropdown-icon-back")
            transferBtn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText("Transfer to Bank", 1, 1, 1)
                GameTooltip:AddLine("Transfers all " .. categoryName .. " items from your bags to the bank", 0.8, 0.8, 0.8, true)
                GameTooltip:Show()
            end)

            transferBtn:SetScript("OnClick", function(self)
                TransferCategoryToBank(categoryName)
            end)
        end

        transferBtn:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
        end)

        transferBtn.icon = icon
        header.transferBtn = transferBtn
    end

    headerCache[categoryName] = header

    return header
end

-- Queue de transfert (pour éviter les conflits de curseur)
local transferQueue = {}
local isTransferring = false
local transferTotalCount = 0
local transferProcessedCount = 0

-- Create transfer modal overlay (masque l'animation)
local function CreateTransferModal(parent)
    if transferModal then return transferModal end

    -- Overlay frame (couvre TOUTE la frame pour un meilleur rendu UI)
    local modal = CreateFrame("Frame", nil, parent)
    modal:SetAllPoints(parent)  -- FULLSCREEN coverage!
    modal:SetFrameLevel(parent:GetFrameLevel() + 50)  -- Au-dessus des items mais sous les borders
    modal:EnableMouse(true)  -- Bloque les clics
    modal:Hide()

    -- Fond sombre COMPLÈTEMENT opaque (95% pour bien cacher l'animation)
    modal.bg = modal:CreateTexture(nil, "BACKGROUND")
    modal.bg:SetAllPoints()
    modal.bg:SetColorTexture(0, 0, 0, 0.95)  -- Noir 95% opaque

    -- Texte de status (titre)
    modal.titleText = modal:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    modal.titleText:SetPoint("CENTER", modal, "CENTER", 0, 60)
    modal.titleText:SetText("Transferring items...")
    modal.titleText:SetTextColor(1, 0.82, 0, 1)

    -- Catégorie (sous le titre)
    modal.categoryText = modal:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    modal.categoryText:SetPoint("TOP", modal.titleText, "BOTTOM", 0, -10)
    modal.categoryText:SetText("")
    modal.categoryText:SetTextColor(0.8, 0.8, 0.8, 1)

    -- Progress bar container (même style que les progress bars de la banque)
    local progressContainer = CreateFrame("Frame", nil, modal)
    progressContainer:SetSize(400, 14)  -- Largeur 400px, hauteur 14px
    progressContainer:SetPoint("TOP", modal.categoryText, "BOTTOM", 0, -20)

    -- Background (texture g1 assombrie)
    local bg = progressContainer:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\AddOns\\Nihui_uf\\textures\\g1.tga")
    bg:SetAllPoints(progressContainer)
    bg:SetVertexColor(0.1, 0.1, 0.1, 0.8)

    -- Status bar (main bar)
    local statusBar = CreateFrame("StatusBar", nil, progressContainer)
    statusBar:SetAllPoints()
    statusBar:SetStatusBarTexture("Interface\\AddOns\\Nihui_uf\\textures\\g1.tga")
    statusBar:SetMinMaxValues(0, 1)
    statusBar:SetValue(0)
    statusBar:SetStatusBarColor(0.2, 1, 0.2, 1)  -- Vert par défaut

    -- Glass overlay (effet brillant)
    local glass = statusBar:CreateTexture(nil, "ARTWORK", nil, 7)
    glass:SetTexture("Interface\\AddOns\\Nihui_uf\\textures\\HPglass.tga")
    glass:SetPoint("TOPLEFT", statusBar, "TOPLEFT", 0, 0)
    glass:SetPoint("BOTTOMRIGHT", statusBar, "BOTTOMRIGHT", 0, 0)
    glass:SetTextureSliceMargins(16, 16, 16, 16)
    glass:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
    glass:SetAlpha(0.2)
    glass:SetBlendMode("ADD")

    -- Border (EXACT comme bar.lua)
    local border = CreateFrame("Frame", nil, progressContainer, "BackdropTemplate")
    border:SetPoint("TOPLEFT", progressContainer, "TOPLEFT", -12, 12)
    border:SetPoint("BOTTOMRIGHT", progressContainer, "BOTTOMRIGHT", 12, -12)
    border:SetBackdrop({
        edgeFile = "Interface\\AddOns\\Nihui_uf\\textures\\MirroredFrameSingleUF.tga",
        edgeSize = 16,
        insets = {left = 1, right = 1, top = 1, bottom = 1}
    })
    border:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    border:SetFrameLevel(progressContainer:GetFrameLevel() + 2)

    -- Spark (animated glow)
    local spark = statusBar:CreateTexture(nil, "OVERLAY", nil, 6)
    spark:SetTexture("Interface\\AddOns\\Nihui_uf\\textures\\orangespark.tga")
    spark:SetSize(20, 14)
    spark:SetBlendMode("ADD")
    spark:Show()

    -- Compteur d'items (au-dessus de la progress bar)
    modal.counterText = modal:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    modal.counterText:SetPoint("BOTTOM", progressContainer, "TOP", 0, 5)
    modal.counterText:SetText("0 / 0")
    modal.counterText:SetTextColor(1, 1, 1, 1)

    modal.progressBar = statusBar
    modal.progressSpark = spark
    modal.progressContainer = progressContainer

    transferModal = modal
    return modal
end

-- Show transfer modal
local function ShowTransferModal(categoryName, totalCount)
    if not transferModal then
        CreateTransferModal(bankFrame)
    end

    transferTotalCount = totalCount
    transferProcessedCount = 0

    transferModal.titleText:SetText("Transferring items...")
    transferModal.counterText:SetText(string.format("%d / %d", 0, totalCount))
    transferModal.categoryText:SetText(categoryName)

    -- Reset progress bar
    transferModal.progressBar:SetMinMaxValues(0, 1)
    transferModal.progressBar:SetValue(0)
    transferModal.progressBar:SetStatusBarColor(0.2, 1, 0.2, 1)  -- Green au début

    -- Reset spark position
    transferModal.progressSpark:ClearAllPoints()
    transferModal.progressSpark:SetPoint("CENTER", transferModal.progressBar, "LEFT", 0, 0)

    transferModal:Show()

    -- CRITICAL: Forcer un curseur simple pendant le transfert (au lieu du curseur avec item)
    -- Note: Le curseur WoW est TOUJOURS visible au-dessus de tout, mais on peut au moins
    -- essayer de le rendre moins distrayant avec un curseur simple
    SetCursor("Interface\\Cursor\\Point")  -- Curseur pointeur simple

    -- Force hide dropzones (empêche les dropzones de s'afficher)
    if bankDropzone then bankDropzone:Hide() end
    if backpackDropzone then backpackDropzone:Hide() end
end

-- Hide transfer modal
local function HideTransferModal()
    if transferModal then
        transferModal:Hide()
    end

    -- Restore cursor (réaffiche le curseur)
    ResetCursor()
end

-- Update transfer modal counter and progress bar
local function UpdateTransferModal()
    if transferModal and transferModal:IsShown() then
        transferProcessedCount = transferProcessedCount + 1

        -- Update counter text
        transferModal.counterText:SetText(string.format("%d / %d", transferProcessedCount, transferTotalCount))

        -- Update progress bar
        local progress = transferProcessedCount / transferTotalCount
        transferModal.progressBar:SetValue(progress)

        -- Update spark position
        local barWidth = transferModal.progressBar:GetWidth()
        local sparkPos = barWidth * progress
        transferModal.progressSpark:ClearAllPoints()
        transferModal.progressSpark:SetPoint("CENTER", transferModal.progressBar, "LEFT", sparkPos, 0)

        -- Change color based on progress (green -> orange -> yellow)
        local r, g, b
        if progress < 0.33 then
            -- 0-33%: Green to Yellow
            r, g, b = 0.2 + progress * 2.4, 1, 0.2
        elseif progress < 0.66 then
            -- 33-66%: Yellow to Orange
            local t = (progress - 0.33) / 0.33
            r, g, b = 1, 1 - t * 0.3, 0.2
        else
            -- 66-100%: Orange to Gold
            local t = (progress - 0.66) / 0.34
            r, g, b = 1, 0.7 + t * 0.12, 0.2
        end
        transferModal.progressBar:SetStatusBarColor(r, g, b, 1)
    end
end

-- Process transfer queue (un item à la fois)
local function ProcessTransferQueue()
    if isTransferring or #transferQueue == 0 then
        -- Queue finished
        if #transferQueue == 0 and transferModal and transferModal:IsShown() then
            HideTransferModal()
        end
        return
    end

    isTransferring = true
    local transfer = table.remove(transferQueue, 1)

    -- Clear cursor first
    ClearCursor()

    -- Pickup item from source
    C_Container.PickupContainerItem(transfer.sourceBag, transfer.sourceSlot)

    -- Wait a tiny bit then place in destination (0.01 = très rapide)
    C_Timer.After(0.01, function()
        C_Container.PickupContainerItem(transfer.destBag, transfer.destSlot)

        -- Update modal counter
        UpdateTransferModal()

        -- Wait a bit more then continue queue
        C_Timer.After(0.01, function()
            isTransferring = false

            -- Process next item in queue
            if #transferQueue > 0 then
                ProcessTransferQueue()
            else
                -- Queue finished, hide modal and refresh
                HideTransferModal()

                if transfer.onComplete then
                    transfer.onComplete()
                end
            end
        end)
    end)
end

-- Transfer all items of a category from backpack to bank
function TransferCategoryToBank(categoryName)
    if not bankFrame or not bankFrame:IsShown() then
        return
    end

    local const = getConst()

    -- Get all backpack items
    local backpackItems = ns.Components.Items.GetBackpackItems()

    -- Group by category
    local groupedItems = ns.Components.Categories.GroupItemsByCategory(backpackItems, const.BAG_KIND.BACKPACK)

    -- Get items from this category
    local categoryItems = groupedItems[categoryName]
    if not categoryItems then
        ns:Print("|cffff0000No items found in category: " .. categoryName .. "|r")
        return
    end

    -- Count items to transfer
    local itemsToTransfer = {}
    for slotKey, itemData in pairs(categoryItems) do
        if not itemData.isEmpty and not itemData.isEmptySlotStack then
            table.insert(itemsToTransfer, itemData)
        end
    end

    if #itemsToTransfer == 0 then
        ns:Print("|cffff0000No items to transfer in category: " .. categoryName .. "|r")
        return
    end

    -- Build transfer queue with slot tracking
    local queuedCount = 0
    local usedSlots = {}  -- Track slots we're planning to use

    for i, itemData in ipairs(itemsToTransfer) do
        local bankBagID, bankSlotID = FindFirstEmptySlot(const.BANK_BAGS, usedSlots)

        if bankBagID and bankSlotID then
            -- Mark this slot as "will be used"
            local slotKey = bankBagID .. ":" .. bankSlotID
            usedSlots[slotKey] = true

            table.insert(transferQueue, {
                sourceBag = itemData.bagID,
                sourceSlot = itemData.slotID,
                destBag = bankBagID,
                destSlot = bankSlotID,
                onComplete = function()
                    -- Refresh on last item
                    if bankFrame:IsShown() then
                        ns.Layouts.Bank.RefreshAll()
                    end
                end
            })
            queuedCount = queuedCount + 1
        else
            ns:Print("|cffff0000Bank is full! Cannot transfer more items.|r")
            break
        end
    end

    if queuedCount > 0 then
        ns:Print(string.format("|cff00ff00Transferring %d items from %s to bank...|r", queuedCount, categoryName))

        -- Show transfer modal (cache l'animation)
        ShowTransferModal(categoryName, queuedCount)

        -- Start processing
        ProcessTransferQueue()
    else
        ns:Print("|cffff0000Bank is full!|r")
    end
end

-- Transfer all items of a category from bank to backpack
function TransferCategoryToBags(categoryName)
    if not bankFrame or not bankFrame:IsShown() then return end

    local const = getConst()

    -- Get all bank items
    local bankItems = ns.Components.Items.GetAllItems(const.BANK_BAGS)

    -- Group by category
    local groupedItems = ns.Components.Categories.GroupItemsByCategory(bankItems, const.BAG_KIND.BANK)

    -- Get items from this category
    local categoryItems = groupedItems[categoryName]
    if not categoryItems then
        ns:Print("No items found in category: " .. categoryName)
        return
    end

    -- Count items to transfer
    local itemsToTransfer = {}
    for slotKey, itemData in pairs(categoryItems) do
        if not itemData.isEmpty and not itemData.isEmptySlotStack then
            table.insert(itemsToTransfer, itemData)
        end
    end

    if #itemsToTransfer == 0 then
        ns:Print("No items to transfer in category: " .. categoryName)
        return
    end

    -- Get backpack bags constant
    local backpackBags = ns.Components.Items.GetBagConstants().BACKPACK

    -- Build transfer queue with slot tracking
    local queuedCount = 0
    local usedSlots = {}  -- Track slots we're planning to use

    for _, itemData in ipairs(itemsToTransfer) do
        local backpackBagID, backpackSlotID = FindFirstEmptySlot(backpackBags, usedSlots)
        if backpackBagID and backpackSlotID then
            -- Mark this slot as "will be used"
            local slotKey = backpackBagID .. ":" .. backpackSlotID
            usedSlots[slotKey] = true

            table.insert(transferQueue, {
                sourceBag = itemData.bagID,
                sourceSlot = itemData.slotID,
                destBag = backpackBagID,
                destSlot = backpackSlotID,
                onComplete = function()
                    -- Refresh on last item
                    if bankFrame:IsShown() then
                        ns.Layouts.Bank.RefreshAll()
                    end
                end
            })
            queuedCount = queuedCount + 1
        else
            break
        end
    end

    if queuedCount > 0 then
        ns:Print(string.format("|cff00ff00Transferring %d items from %s to bags...|r", queuedCount, categoryName))

        -- Show transfer modal (cache l'animation)
        ShowTransferModal(categoryName, queuedCount)

        -- Start processing
        ProcessTransferQueue()
    else
        ns:Print("|cffff0000Bags are full!|r")
    end
end

-- Update bank progress bar
local function UpdateBankProgress()
    if not bankProgressBar then return end

    local const = getConst()
    local bags = (activeBankType == "warband") and const.ACCOUNT_BANK_BAGS or const.BANK_BAGS
    local freeSlots = ns.Components.Items.GetFreeSlots(bags)
    local totalSlots = ns.Components.Items.GetTotalSlots(bags)

    UpdateProgressBar(bankProgressBar, freeSlots, totalSlots)
end

-- Refresh bank items by category (with headers)
local function RefreshBankItemsByCategory(items, scrollChild, contentWidth, columns, spacing)
    local const = getConst()
    local slotSize = ns.db.bankIconSize or 37 -- Use configured size
    local slotTotalSize = slotSize + spacing

    -- Group items by category
    local groupedItems = ns.Components.Categories.GroupItemsByCategory(items, const.BAG_KIND.BANK)

    -- Get sorted category names
    local categoryOrder = {}
    for categoryName in pairs(groupedItems) do
        table.insert(categoryOrder, categoryName)
    end

    -- Sort categories (Empty Slots and Uncategorized at the end)
    table.sort(categoryOrder, function(a, b)
        if a == "Empty Slots" then return false end
        if b == "Empty Slots" then return false end
        if a == "Uncategorized" then return false end
        if b == "Uncategorized" then return false end
        return a < b
    end)

    -- Layout categories vertically with headers
    local currentY = 0
    local totalHeight = 0

    for _, categoryName in ipairs(categoryOrder) do
        local categoryItems = groupedItems[categoryName]
        local numCategoryItems = 0
        for _ in pairs(categoryItems) do numCategoryItems = numCategoryItems + 1 end

        if numCategoryItems > 0 then
            -- Create category header (avec bouton de transfert pour la banque)
            local header = GetOrCreateCategoryHeader(categoryName, scrollChild, contentWidth, bankCategoryHeaders, true)  -- true = bank header
            header:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, currentY)
            header:Show()

            currentY = currentY - 36  -- Hauteur du header (augmentée pour plus d'espace)
            totalHeight = totalHeight + 36

            -- Calculate rows for this category
            local categoryRows = math.ceil(numCategoryItems / columns)
            local categoryHeight = categoryRows * slotTotalSize

            -- Create slots for this category
            local allSlots = ns.Components.Slots.CreateGrid(scrollChild, categoryItems, columns, spacing, slotSize)

            -- Position category grid below header
            for _, slot in ipairs(allSlots) do
                local currentPoint, relativeTo, relativePoint, offsetX, offsetY = slot:GetPoint(1)
                slot:ClearAllPoints()
                slot:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", offsetX, currentY + offsetY)

                -- Apply search opacity
                if slot.itemData and slot.itemData.searchOpacity then
                    slot:SetAlpha(slot.itemData.searchOpacity)
                end
            end

            currentY = currentY - categoryHeight
            totalHeight = totalHeight + categoryHeight
        end
    end

    -- Set scrollChild height
    scrollChild:SetSize(math.max(contentWidth, columns * slotTotalSize), math.max(100, totalHeight + 20))
end

-- Refresh backpack items by category (in bank view)
local function RefreshBackpackItemsByCategory(items, scrollChild, contentWidth, columns, spacing)
    local const = getConst()
    local slotSize = ns.db.bankIconSize or 37 -- Use bank's configured size (same as bank view)
    local slotTotalSize = slotSize + spacing

    -- Group items by category
    local groupedItems = ns.Components.Categories.GroupItemsByCategory(items, const.BAG_KIND.BACKPACK)

    -- Get sorted category names
    local categoryOrder = {}
    for categoryName in pairs(groupedItems) do
        table.insert(categoryOrder, categoryName)
    end

    -- Sort categories
    table.sort(categoryOrder, function(a, b)
        if a == "Empty Slots" then return false end
        if b == "Empty Slots" then return false end
        if a == "Uncategorized" then return false end
        if b == "Uncategorized" then return false end
        return a < b
    end)

    -- Layout categories vertically with headers
    local currentY = 0
    local totalHeight = 0

    for _, categoryName in ipairs(categoryOrder) do
        local categoryItems = groupedItems[categoryName]
        local numCategoryItems = 0
        for _ in pairs(categoryItems) do numCategoryItems = numCategoryItems + 1 end

        if numCategoryItems > 0 then
            -- Create category header (avec bouton de transfert pour l'inventaire)
            local header = GetOrCreateCategoryHeader(categoryName, scrollChild, contentWidth, backpackCategoryHeaders, false)  -- false = backpack header
            header:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, currentY)
            header:Show()

            currentY = currentY - 36  -- Hauteur du header (augmentée pour plus d'espace)
            totalHeight = totalHeight + 36

            -- Calculate rows for this category
            local categoryRows = math.ceil(numCategoryItems / columns)
            local categoryHeight = categoryRows * slotTotalSize

            -- Create slots for this category
            local allSlots = ns.Components.Slots.CreateGrid(scrollChild, categoryItems, columns, spacing, slotSize)

            -- Position category grid below header
            for _, slot in ipairs(allSlots) do
                local currentPoint, relativeTo, relativePoint, offsetX, offsetY = slot:GetPoint(1)
                slot:ClearAllPoints()
                slot:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", offsetX, currentY + offsetY)

                -- Apply search opacity
                if slot.itemData and slot.itemData.searchOpacity then
                    slot:SetAlpha(slot.itemData.searchOpacity)
                end
            end

            currentY = currentY - categoryHeight
            totalHeight = totalHeight + categoryHeight
        end
    end

    -- Set scrollChild height
    scrollChild:SetSize(math.max(contentWidth, columns * slotTotalSize), math.max(100, totalHeight + 20))
end

-- Update backpack progress bar
local function UpdateBackpackProgress()
    if not backpackProgressBar then return end

    local bags = ns.Components.Items.GetBagConstants().BACKPACK
    local freeSlots = ns.Components.Items.GetFreeSlots(bags)
    local totalSlots = ns.Components.Items.GetTotalSlots(bags)

    UpdateProgressBar(backpackProgressBar, freeSlots, totalSlots)
end

-- Refresh bank items (similar to backpack refresh but for bank)
local function RefreshBankItems()
    if not bankContentFrame or not bankFrame:IsShown() then return end

    -- Release old bank slots
    ns.Components.Slots.ReleaseAll()

    -- Get bank items (from cache if viewing another character)
    local items
    if IsViewingOther() and viewingCharKey then
        -- Check if this character has bank data
        if not ns.Components.Items.HasCachedBank(viewingCharKey) then
            -- No bank data cached for this character
            items = {}

            -- Display message once (not on every refresh)
            if not bankContentFrame.noBankDataWarningShown then
                local charInfo = ns.Components.Cache.GetCharacterInfo(viewingCharKey)
                local charName = charInfo and charInfo.name or "this character"
                ns:Print("No bank data cached for " .. charName .. ". Open their bank to cache it.")
                bankContentFrame.noBankDataWarningShown = true

                -- Reset flag when returning to current character
                C_Timer.After(0.1, function()
                    if not IsViewingOther() then
                        bankContentFrame.noBankDataWarningShown = false
                    end
                end)
            end
        else
            items = ns.Components.Items.GetCachedBankItems(viewingCharKey)
        end
    else
        -- Get bank items (use ACCOUNT_BANK_BAGS for warband, BANK_BAGS for regular)
        local const = getConst()
        local bags = (activeBankType == "warband") and const.ACCOUNT_BANK_BAGS or const.BANK_BAGS
        items = ns.Components.Items.GetAllItems(bags)

        -- Reset warning flag when viewing current character
        if bankContentFrame then
            bankContentFrame.noBankDataWarningShown = false
        end
    end

    -- Apply stacking
    items = ns.Components.Stacking.FilterStackedItems(items)

    -- Merge empty slots (ONLY if option enabled)
    local emptySlotCount = 0
    local filteredItems = {}
    local firstEmptySlotKey = nil

    for slotKey, itemData in pairs(items) do
        if itemData.isEmpty then
            emptySlotCount = emptySlotCount + 1
            if not firstEmptySlotKey then
                firstEmptySlotKey = slotKey
            end
        else
            filteredItems[slotKey] = itemData
        end
    end

    -- Add single merged "Empty Slots" item if we have any empty slots (ONLY if option enabled)
    if emptySlotCount > 0 and firstEmptySlotKey and (ns.db.bankShowEmptySlots ~= false) then
        filteredItems[firstEmptySlotKey] = {
            bagID = 0,
            slotID = 0,
            slotKey = firstEmptySlotKey,
            isEmpty = false,
            isEmptySlotStack = true,
            emptySlotCount = emptySlotCount,
            itemTexture = "Interface\\Icons\\INV_Misc_QuestionMark",
            currentItemCount = emptySlotCount,
            itemQuality = 0,
        }
    end

    items = filteredItems

    -- Apply search filter
    if currentSearchText ~= "" then
        ns.Components.Search.RebuildIndex(items)
        local searchResults = ns.Components.Search.Search(currentSearchText)

        -- Apply opacity instead of filtering (0.2 for non-matching items)
        for slotKey, itemData in pairs(items) do
            itemData.searchOpacity = searchResults[slotKey] and 1.0 or 0.1
        end
    else
        for slotKey, itemData in pairs(items) do
            itemData.searchOpacity = 1.0
        end
    end

    -- Get dimensions
    local scrollChild = bankContentFrame.scrollChild
    local contentWidth = bankContentFrame:GetWidth() - 20
    local slotSize = ns.db.bankIconSize or 37 -- Use configured size
    local spacing = 4
    local slotTotalSize = slotSize + spacing
    local columns = math.max(1, math.floor((contentWidth + spacing) / slotTotalSize))

    -- Hide old headers
    for _, header in pairs(bankCategoryHeaders) do
        header:Hide()
    end

    -- Render based on view mode
    if bankViewMode == "category" then
        RefreshBankItemsByCategory(items, scrollChild, contentWidth, columns, spacing)
    else
        -- All-in-one mode
        local numItems = 0
        for _ in pairs(items) do numItems = numItems + 1 end

        local rows = math.ceil(numItems / columns)
        local gridHeight = rows * slotTotalSize

        scrollChild:SetSize(math.max(contentWidth, columns * slotTotalSize), math.max(100, gridHeight + 20))

        local allSlots = ns.Components.Slots.CreateGrid(scrollChild, items, columns, spacing, slotSize)

        -- Apply search opacity
        for _, slot in ipairs(allSlots) do
            if slot.itemData and slot.itemData.searchOpacity then
                slot:SetAlpha(slot.itemData.searchOpacity)
            end
        end
    end

    UpdateBankProgress()
end

-- Refresh backpack items (in bank view)
local function RefreshBackpackItems()
    if not backpackContentFrame or not bankFrame:IsShown() then return end

    -- Get backpack items (from cache if viewing another character)
    local items
    if IsViewingOther() and viewingCharKey then
        items = ns.Components.Items.GetCachedBackpackItems(viewingCharKey)
    else
        items = ns.Components.Items.GetBackpackItems()
    end

    -- Apply stacking
    items = ns.Components.Stacking.FilterStackedItems(items)

    -- Merge empty slots (ONLY if option enabled)
    local emptySlotCount = 0
    local filteredItems = {}
    local firstEmptySlotKey = nil

    for slotKey, itemData in pairs(items) do
        if itemData.isEmpty then
            emptySlotCount = emptySlotCount + 1
            if not firstEmptySlotKey then
                firstEmptySlotKey = slotKey
            end
        else
            filteredItems[slotKey] = itemData
        end
    end

    -- Add single merged "Empty Slots" item if we have any empty slots (ONLY if option enabled)
    if emptySlotCount > 0 and firstEmptySlotKey and (ns.db.bankShowEmptySlots ~= false) then
        filteredItems[firstEmptySlotKey] = {
            bagID = 0,
            slotID = 0,
            slotKey = firstEmptySlotKey,
            isEmpty = false,
            isEmptySlotStack = true,
            emptySlotCount = emptySlotCount,
            itemTexture = "Interface\\Icons\\INV_Misc_QuestionMark",
            currentItemCount = emptySlotCount,
            itemQuality = 0,
        }
    end

    items = filteredItems

    -- Apply search filter
    if currentSearchText ~= "" then
        ns.Components.Search.RebuildIndex(items)
        local searchResults = ns.Components.Search.Search(currentSearchText)

        -- Apply opacity (0.2 for non-matching items)
        for slotKey, itemData in pairs(items) do
            itemData.searchOpacity = searchResults[slotKey] and 1.0 or 0.2
        end
    else
        for slotKey, itemData in pairs(items) do
            itemData.searchOpacity = 1.0
        end
    end

    -- Get dimensions
    local scrollChild = backpackContentFrame.scrollChild
    local contentWidth = backpackContentFrame:GetWidth() - 20
    local slotSize = ns.db.bankIconSize or 37 -- Use bank's configured size (same as bank view)
    local spacing = 4
    local slotTotalSize = slotSize + spacing
    local columns = math.max(1, math.floor((contentWidth + spacing) / slotTotalSize))

    -- Hide old headers
    for _, header in pairs(backpackCategoryHeaders) do
        header:Hide()
    end

    -- Render based on view mode (same as bank view)
    if bankViewMode == "category" then
        RefreshBackpackItemsByCategory(items, scrollChild, contentWidth, columns, spacing)
    else
        -- All-in-one mode
        local numItems = 0
        for _ in pairs(items) do numItems = numItems + 1 end

        local rows = math.ceil(numItems / columns)
        local gridHeight = rows * slotTotalSize

        scrollChild:SetSize(math.max(contentWidth, columns * slotTotalSize), math.max(100, gridHeight + 20))

        local allSlots = ns.Components.Slots.CreateGrid(scrollChild, items, columns, spacing, slotSize)

        -- Apply search opacity
        for _, slot in ipairs(allSlots) do
            if slot.itemData and slot.itemData.searchOpacity then
                slot:SetAlpha(slot.itemData.searchOpacity)
            end
        end
    end

    UpdateBackpackProgress()
end

-- Show bank
function ns.Layouts.Bank.Show()
    if not bankFrame then
        ns.Layouts.Bank.Initialize()
    end

    -- Close backpack if it's open (prevent concurrency issues)
    if ns.Layouts.Backpack and ns.Layouts.Backpack.IsShown() then
        ns.Layouts.Backpack.Hide()
    end

    -- Reset closing flag
    isClosing = false

    -- IMPORTANT: Clear header cache to ensure transfer buttons show with current settings
    ns.Layouts.Bank.ClearHeaderCache()

    bankFrame:Show()
    ns.Layouts.Bank.RefreshAll()
end

-- Hide bank
function ns.Layouts.Bank.Hide()
    if bankFrame and bankFrame:IsShown() then
        -- Close dropdown if open
        if characterSelector and characterSelector.CloseDropdown then
            characterSelector:CloseDropdown()
        end
        isClosing = true
        bankFrame:Hide()
        C_Timer.After(0.1, function() isClosing = false end)
    end
end

-- Check if bank is shown
function ns.Layouts.Bank.IsShown()
    return bankFrame and bankFrame:IsShown()
end

-- Toggle bank
function ns.Layouts.Bank.Toggle()
    if ns.Layouts.Bank.IsShown() then
        ns.Layouts.Bank.Hide()
    else
        ns.Layouts.Bank.Show()
    end
end

-- Check if viewing another character (for ESC handling)
function ns.Layouts.Bank.IsViewingOther()
    return characterSelector and characterSelector:IsViewingOther() or false
end

-- Return to current character (for ESC handling)
function ns.Layouts.Bank.ReturnToCurrent()
    if characterSelector and characterSelector.ReturnToCurrent then
        characterSelector:ReturnToCurrent()
        return true
    end
    return false
end

-- Toggle options panel
function ns.Layouts.Bank.ToggleOptions()
    if not contentContainer or not optionsView then return end

    if optionsView:IsShown() then
        -- Hide options, show normal content
        optionsView:Hide()
        contentContainer:Show()

        -- Show close button again
        if titleBar and titleBar.closeButton then
            titleBar.closeButton:Show()
        end
    else
        -- Hide normal content, show options
        contentContainer:Hide()
        optionsView:Show()

        -- Hide close button (moins confusant)
        if titleBar and titleBar.closeButton then
            titleBar.closeButton:Hide()
        end
    end
end

-- Show options panel
function ns.Layouts.Bank.ShowOptions()
    if not contentContainer or not optionsView then return end
    contentContainer:Hide()
    optionsView:Show()

    -- Hide close button (moins confusant)
    if titleBar and titleBar.closeButton then
        titleBar.closeButton:Hide()
    end
end

-- Hide options panel
function ns.Layouts.Bank.HideOptions()
    if not contentContainer or not optionsView then return end
    optionsView:Hide()
    contentContainer:Show()

    -- Show close button again
    if titleBar and titleBar.closeButton then
        titleBar.closeButton:Show()
    end
end

-- Update big header visibility (direct refresh)
function ns.Layouts.Bank.UpdateBigHeaderVisibility()
    local shouldShow = ns.db.showBigHeader ~= false

    -- Update titleBar bigHeader
    if titleBar and titleBar.bigHeader then
        if shouldShow then
            titleBar.bigHeader:Show()
        else
            titleBar.bigHeader:Hide()
        end
    end

    -- Update borderOverlay bigHeader (stays on top during modal)
    if bankFrame and bankFrame.borderOverlay and bankFrame.borderOverlay.bigHeader then
        if shouldShow then
            bankFrame.borderOverlay.bigHeader:Show()
        else
            bankFrame.borderOverlay.bigHeader:Hide()
        end
    end
end

-- Clear header caches (force recreation of headers with updated options)
function ns.Layouts.Bank.ClearHeaderCache()
    -- Hide and release old bank headers
    for _, header in pairs(bankCategoryHeaders) do
        header:Hide()
        header:SetParent(nil)
        header:ClearAllPoints()
    end
    bankCategoryHeaders = {}

    -- Hide and release old backpack headers
    for _, header in pairs(backpackCategoryHeaders) do
        header:Hide()
        header:SetParent(nil)
        header:ClearAllPoints()
    end
    backpackCategoryHeaders = {}
end

-- Update content frame sizes (for resize)
local function UpdateContentFrameSizes()
    if not viewContainer or not bankContainer or not backpackContainer then return end

    -- Recalculate 70/30 split DANS le viewContainer
    local gap = 16  -- Increased from 8 to 16 for better panel separation
    local totalWidth = viewContainer:GetWidth()  -- Largeur du viewContainer (sans borders)
    local bankWidth = math.floor((totalWidth - gap) * 0.7)

    -- Bank CONTAINER - 70% du viewContainer (REMPLI toute la hauteur!)
    bankContainer:ClearAllPoints()
    bankContainer:SetPoint("TOPLEFT", viewContainer, "TOPLEFT", 0, 0)
    bankContainer:SetPoint("BOTTOMRIGHT", viewContainer, "BOTTOMLEFT", bankWidth, 0)  -- BOTTOMLEFT pour bien gérer la hauteur

    -- Backpack CONTAINER - 30% du viewContainer (REMPLI toute la hauteur!)
    backpackContainer:ClearAllPoints()
    backpackContainer:SetPoint("TOPLEFT", viewContainer, "TOPLEFT", bankWidth + gap, 0)
    backpackContainer:SetPoint("BOTTOMRIGHT", viewContainer, "BOTTOMRIGHT", 0, 0)  -- Remplit jusqu'en bas

    -- Update dropzone positions and sizes (ancré aux scroll frames pour resize automatique)
    if bankDropzone and backpackDropzone then
        bankDropzone:ClearAllPoints()
        bankDropzone:SetPoint("TOPLEFT", bankContentFrame, "TOPLEFT", 0, 0)
        bankDropzone:SetPoint("BOTTOMRIGHT", bankContentFrame, "BOTTOMRIGHT", 0, 0)

        backpackDropzone:ClearAllPoints()
        backpackDropzone:SetPoint("TOPLEFT", backpackContentFrame, "TOPLEFT", 0, 0)
        backpackDropzone:SetPoint("BOTTOMRIGHT", backpackContentFrame, "BOTTOMRIGHT", 0, 0)
    end

    -- Les progress bars et scroll frames sont maintenant des enfants des containers,
    -- ils suivent automatiquement leur resize.
    -- Le spark sera mis à jour dans OnSizeChanged avec un délai pour laisser WoW recalculer GetWidth()
end

-- Refresh all (both bank and backpack)
function ns.Layouts.Bank.RefreshAll()
    if not bankFrame or not bankFrame:IsShown() then return end

    -- Update frame sizes first (important for resize)
    UpdateContentFrameSizes()

    RefreshBankItems()
    RefreshBackpackItems()

    -- Update money displays (both warbank and player)
    if warbankMoneyFrame then
        warbankMoneyFrame:Update()
    end
    if playerMoneyFrame then
        playerMoneyFrame:Update()
    end
end

-- Sort cooldown tracking
local lastBankSortTime = 0
local BANK_SORT_COOLDOWN = 2 -- 2 seconds cooldown

-- Sort items (only in "all" mode)
function ns.Layouts.Bank.SortItems()
    if bankViewMode ~= "all" then
        ns:Print("Sorting is only available in 'All Items' view mode")
        return
    end

    -- Prevent sorting when viewing another character
    if IsViewingOther() then
        ns:Print("Cannot sort while viewing another character's inventory")
        return
    end

    -- Check cooldown
    local currentTime = GetTime()
    if currentTime - lastBankSortTime < BANK_SORT_COOLDOWN then
        local remaining = math.ceil(BANK_SORT_COOLDOWN - (currentTime - lastBankSortTime))
        ns:Print("Please wait " .. remaining .. " second(s) before sorting again")
        return
    end

    -- Update last sort time
    lastBankSortTime = currentTime

    -- Use WoW's built-in sort functions for both bank and backpack
    C_Container.SortBankBags()
    C_Container.SortBags()
    ns:Print("All items sorted!")

    -- Refresh after delays to ensure WoW finishes sorting
    -- First refresh at 0.3s
    C_Timer.After(0.3, function()
        if bankFrame and bankFrame:IsShown() then
            ns.Layouts.Bank.RefreshAll()
        end
    end)

    -- Second refresh at 0.6s to catch any stragglers
    C_Timer.After(0.6, function()
        if bankFrame and bankFrame:IsShown() then
            ns.Layouts.Bank.RefreshAll()
        end
    end)
end

-- Set bank view mode explicitly
function ns.Layouts.Bank.SetViewMode(mode)
    if mode ~= "all" and mode ~= "category" then
        ns:Print("Invalid view mode. Use 'all' or 'category'")
        return
    end
    bankViewMode = mode
    ns.db.bankViewMode = mode  -- Save to DB
    -- IMPORTANT: Clear header cache to force recreation with updated options
    ns.Layouts.Bank.ClearHeaderCache()
    ns.Layouts.Bank.RefreshAll()

    -- Update sort button visibility based on view mode
    if titleBar and titleBar.sortButton then
        if bankViewMode == "all" then
            titleBar.sortButton:Show()
        else
            titleBar.sortButton:Hide()
        end
    end
end

-- Toggle bank view mode (affects both bank and backpack sides)
function ns.Layouts.Bank.ToggleBankView()
    bankViewMode = (bankViewMode == "all") and "category" or "all"
    ns.db.bankViewMode = bankViewMode  -- Save to DB
    -- IMPORTANT: Clear header cache to force recreation with updated options
    ns.Layouts.Bank.ClearHeaderCache()
    ns.Layouts.Bank.RefreshAll()
    print("|cff9482c9Nihui|r: Bank view mode set to " .. bankViewMode)

    -- Update sort button visibility based on view mode
    if titleBar and titleBar.sortButton then
        if bankViewMode == "all" then
            titleBar.sortButton:Show()
        else
            titleBar.sortButton:Hide()
        end
    end
end

-- Find first empty slot in a set of bags
-- @param bags - Table of bag IDs to search
-- @param usedSlots - Table of slots already reserved (optional)
function FindFirstEmptySlot(bags, usedSlots)
    usedSlots = usedSlots or {}

    for bagID, _ in pairs(bags) do
        local numSlots = C_Container.GetContainerNumSlots(bagID)
        if numSlots and numSlots > 0 then
            for slotID = 1, numSlots do
                -- Check if this slot is already reserved
                local slotKey = bagID .. ":" .. slotID
                if not usedSlots[slotKey] then
                    local itemInfo = C_Container.GetContainerItemInfo(bagID, slotID)
                    if not itemInfo then
                        -- Empty slot found!
                        return bagID, slotID
                    end
                end
            end
        end
    end
    return nil, nil
end

-- Transfer item from cursor to bank
local function TransferToBank()
    local cursorType = GetCursorInfo()
    if cursorType ~= "item" then return false end

    -- Find first empty slot in bank
    local const = getConst()
    local bagID, slotID = FindFirstEmptySlot(const.BANK_BAGS)

    if bagID and slotID then
        -- Place item in empty bank slot
        C_Container.PickupContainerItem(bagID, slotID)
        ns:Print("Item deposited to bank!")
        return true
    else
        ns:Print("|cffff0000Bank is full!|r")
        return false
    end
end

-- Transfer item from cursor to backpack
local function TransferToBackpack()
    local cursorType = GetCursorInfo()
    if cursorType ~= "item" then return false end

    -- Find first empty slot in backpack
    local const = getConst()
    local bagID, slotID = FindFirstEmptySlot(const.BACKPACK_BAGS)

    if bagID and slotID then
        -- Place item in empty backpack slot
        C_Container.PickupContainerItem(bagID, slotID)
        ns:Print("Item withdrawn to bags!")
        return true
    else
        ns:Print("|cffff0000Bags are full!|r")
        return false
    end
end

-- Setup dropzone functionality (cursor detection + click handlers)
local function SetupDropzones()
    if not dropzoneUpdateFrame then
        dropzoneUpdateFrame = CreateFrame("Frame")
    end

    -- OnUpdate: Check cursor for items and show/hide dropzones SMARTLY
    dropzoneUpdateFrame:SetScript("OnUpdate", function(self, elapsed)
        if not bankFrame or not bankFrame:IsShown() then
            -- Bank closed, hide dropzones
            if bankDropzone then bankDropzone:Hide() end
            if backpackDropzone then backpackDropzone:Hide() end
            return
        end

        -- CRITICAL: Si un transfert automatique est en cours (modal visible), FORCER les dropzones à rester cachées
        if transferModal and transferModal:IsShown() then
            -- Transfert automatique en cours, NE PAS afficher les dropzones
            if bankDropzone then bankDropzone:Hide() end
            if backpackDropzone then backpackDropzone:Hide() end
            return
        end

        -- Check if cursor has an item
        local cursorType = GetCursorInfo()

        if cursorType == "item" then
            -- Item on cursor! Detect which zone mouse is over
            local mouseOverBank = MouseIsOver(bankContentFrame)
            local mouseOverBackpack = MouseIsOver(backpackContentFrame)

            if mouseOverBank then
                -- Mouse over BANK → show BANK dropzone (drop here to deposit)
                if bankDropzone then bankDropzone:Show() end
                if backpackDropzone then backpackDropzone:Hide() end
            elseif mouseOverBackpack then
                -- Mouse over BACKPACK → show BACKPACK dropzone (drop here to withdraw)
                if backpackDropzone then backpackDropzone:Show() end
                if bankDropzone then bankDropzone:Hide() end
            else
                -- Mouse not over either zone → hide both
                if bankDropzone then bankDropzone:Hide() end
                if backpackDropzone then backpackDropzone:Hide() end
            end
        else
            -- No item on cursor → hide all dropzones
            if bankDropzone then bankDropzone:Hide() end
            if backpackDropzone then backpackDropzone:Hide() end
        end
    end)

    -- Bank dropzone click handler (deposit to bank)
    if bankDropzone then
        bankDropzone:SetScript("OnClick", function(self, button)
            if TransferToBank() then
                -- Item transferred, refresh views
                C_Timer.After(0.1, function()
                    ns.Layouts.Bank.RefreshAll()
                end)
            end
        end)

        -- Hover effect
        bankDropzone:SetScript("OnEnter", function(self)
            self.bg:SetAlpha(0.5)  -- Brighter on hover
        end)

        bankDropzone:SetScript("OnLeave", function(self)
            self.bg:SetAlpha(0.3)  -- Back to normal
        end)
    end

    -- Backpack dropzone click handler (withdraw from bank)
    if backpackDropzone then
        backpackDropzone:SetScript("OnClick", function(self, button)
            if TransferToBackpack() then
                -- Item transferred, refresh views
                C_Timer.After(0.1, function()
                    ns.Layouts.Bank.RefreshAll()
                end)
            end
        end)

        -- Hover effect
        backpackDropzone:SetScript("OnEnter", function(self)
            self.bg:SetAlpha(0.5)
        end)

        backpackDropzone:SetScript("OnLeave", function(self)
            self.bg:SetAlpha(0.3)
        end)
    end
end

-- Set ESC key handler (called from init.lua)
function ns.Layouts.Bank.SetEscapeHandler(handler)
    ns.Layouts.Bank._escapeHandler = handler
end

-- Initialize bank
function ns.Layouts.Bank.Initialize()
    if bankFrame then return end

    -- Initialize bankViewMode from DB (or default to "category")
    bankViewMode = ns.db.bankViewMode or "category"

    -- Create main frame
    bankFrame = CreateBankFrame()

    -- Create bank type tabs (Regular / Warband) - positioned ABOVE the frame
    bankTabs = CreateBankTabs(bankFrame)

    -- Create purchase button for buying bank slots - positioned LEFT of the frame
    purchaseButton = CreatePurchaseButton(bankFrame)

    -- Create title bar (ALWAYS visible) - store globally for close button hide/show
    titleBar = CreateTitleBar(bankFrame)

    -- Create contentContainer (wraps all normal content - can be hidden when showing options)
    contentContainer = CreateFrame("Frame", nil, bankFrame)
    contentContainer:SetAllPoints(bankFrame)

    -- Create all normal content INSIDE contentContainer
    -- Create VIEW CONTAINER (entre search et footer)
    viewContainer = CreateViewContainer(contentContainer)

    -- Create 70/30 split content frames (DANS le viewContainer)
    local contentFrames = CreateContentFrames(viewContainer)  -- viewContainer comme parent!
    bankContainer = contentFrames.bankCont
    backpackContainer = contentFrames.backpackCont
    bankContentFrame = contentFrames.bankScroll
    backpackContentFrame = contentFrames.backpackScroll

    -- IMPORTANT: Position containers IMMÉDIATEMENT après création (avant dropzones et progress bars)
    UpdateContentFrameSizes()

    -- Create dropzones for drag & drop (inside contentContainer)
    local dropzones = CreateDropzones(contentContainer)
    bankDropzone = dropzones.bankDrop
    backpackDropzone = dropzones.backpackDrop

    -- Setup dropzone functionality (cursor detection + click handlers)
    SetupDropzones()

    -- Create single search box (filters both bank and backpack) (inside contentContainer)
    searchBox = CreateSearchBox(contentContainer, function(text)
        currentSearchText = text
        ns.Layouts.Bank.RefreshAll()
    end)

    -- Create money displays (warband bank on left, player money on right) (inside contentContainer)
    warbankMoneyFrame = CreateWarbankMoneyDisplay(contentContainer)
    playerMoneyFrame = CreatePlayerMoneyDisplay(contentContainer)

    -- Create progress bars (ENFANTS des CONTAINERS pour hiérarchie correcte, WITH PADDING)
    -- Bank progress bar (70% left) - ENFANT de bankContainer, en haut avec padding
    bankProgressBar = CreateProgressBar(bankContainer)
    bankProgressBar:SetPoint("TOPLEFT", bankContainer, "TOPLEFT", 8, -8)  -- 8px padding left/top
    bankProgressBar:SetPoint("TOPRIGHT", bankContainer, "TOPRIGHT", -68, -8)  -- -68 = -60 text - 8 padding

    -- Backpack progress bar (30% right) - ENFANT de backpackContainer, en haut avec padding
    backpackProgressBar = CreateProgressBar(backpackContainer)
    backpackProgressBar:SetPoint("TOPLEFT", backpackContainer, "TOPLEFT", 8, -8)  -- 8px padding left/top
    backpackProgressBar:SetPoint("TOPRIGHT", backpackContainer, "TOPRIGHT", -68, -8)  -- -68 = -60 text - 8 padding

    -- Create options view (hidden by default)
    if ns.Config and ns.Config.Options then
        -- Options view should cover the same area as the content (search to money displays)
        local optionsContainer = CreateFrame("Frame", nil, bankFrame)
        optionsContainer:SetPoint("TOPLEFT", bankFrame, "TOPLEFT", 33, -159) -- Same as viewContainer (search bar position)
        optionsContainer:SetPoint("BOTTOMRIGHT", bankFrame, "BOTTOMRIGHT", -33, 65) -- Same as viewContainer (above money displays)

        optionsView = ns.Config.Options.CreateView(optionsContainer, "bank")  -- Default to bank tab
        optionsView:Hide()
    end

    -- Register for item updates
    ns.Components.Items.SetItemsChangedCallback(function()
        if bankFrame:IsShown() then
            ns.Layouts.Bank.RefreshAll()
        end
    end)

    -- Register for money updates (both warbank and player)
    ns.Components.Events.RegisterEvent("PLAYER_MONEY", function()
        if playerMoneyFrame and bankFrame:IsShown() then
            playerMoneyFrame:Update()
        end
    end)

    -- Register for warbank money updates
    ns.Components.Events.RegisterEvent("CURRENCY_DISPLAY_UPDATE", function()
        if warbankMoneyFrame and bankFrame:IsShown() then
            warbankMoneyFrame:Update()
        end
    end)

    -- ESC key handling via OnKeyDown (configured in init.lua via SetEscapeHandler)
    -- First ESC in preview mode: returns to current character (keeps window open)
    -- Second ESC (or first in normal mode): closes the window
    -- Does NOT use UISpecialFrames to avoid conflicts with menu opening

    -- Initialize sort button visibility based on current view mode
    if titleBar and titleBar.sortButton then
        if bankViewMode == "all" then
            titleBar.sortButton:Show()
        else
            titleBar.sortButton:Hide()
        end
    end

    ns:Print("Bank layout initialized!")
end

-- Destroy bank
function ns.Layouts.Bank.Destroy()
    if bankFrame then
        bankFrame:Hide()
        bankFrame = nil
    end
    viewContainer = nil
    bankContainer = nil
    backpackContainer = nil
    bankContentFrame = nil
    backpackContentFrame = nil
    searchBox = nil
    warbankMoneyFrame = nil
    playerMoneyFrame = nil
    bankCategoryHeaders = {}
    backpackCategoryHeaders = {}

    -- Cleanup dropzones
    if bankDropzone then
        bankDropzone:Hide()
        bankDropzone = nil
    end
    if backpackDropzone then
        backpackDropzone:Hide()
        backpackDropzone = nil
    end
    if dropzoneUpdateFrame then
        dropzoneUpdateFrame:SetScript("OnUpdate", nil)
        dropzoneUpdateFrame = nil
    end
end
