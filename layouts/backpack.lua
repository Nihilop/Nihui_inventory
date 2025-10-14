-- layouts/backpack.lua - Beautiful Nihui-themed backpack layout
local addonName, ns = ...

ns.Layouts = ns.Layouts or {}
ns.Layouts.Backpack = {}

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
        left = "!" .. faction .. "FrameTile-Left",  -- Bordures latérales (pas de rotation nécessaire)
        titleLeft = faction .. "Frame_Title-End",
        titleCenter = "_" .. faction .. "Frame_Title-Tile",
        titleRight = faction .. "Frame_Title-End-2",
    }
end

-- Scale for borders and corners (adjust this to test different sizes!)
local BORDER_SCALE = 0.45 -- 1.0 = normal size, 1.5 = 50% larger, 0.8 = 20% smaller

-- Backpack state
local backpackFrame = nil
local contentContainer = nil  -- NEW: Wrapper for all normal content
local optionsView = nil        -- NEW: Options panel
local contentFrame = nil
local searchBox = nil
local moneyFrame = nil
local currencyFrame = nil
local itemGrid = nil
local titleText = nil
local titleBar = nil
local freeSlotsText = nil
local currentSearchText = ""
local categoryHeaders = {} -- Store category headers to prevent duplication
local categoryGrids = {} -- Store separate grids per category
local characterSelector = nil  -- Character selection dropdown
local viewingCharKey = nil     -- Current character being viewed (nil = current player)
local returnButton = nil       -- Button to return to current character

-- View mode: "all" or "category"
local viewMode = "all"  -- Default to all-in-one view

-- Check if viewing another character
local function IsViewingOther()
    if not viewingCharKey then return false end
    return viewingCharKey ~= ns.Components.Cache.GetCurrentCharacterKey()
end

-- Create main backpack frame
local function CreateBackpackFrame()
    -- Main frame
    local frame = CreateFrame("Frame", "NihuiIVBackpack", UIParent)
    frame:SetSize(400, 600)
    frame:SetPoint("RIGHT", UIParent, "RIGHT", -50, 0)
    frame:SetFrameStrata("MEDIUM")  -- BetterBags uses MEDIUM for backpack
    frame:SetFrameLevel(500)  -- BetterBags uses 500
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:SetResizable(true)
    frame:SetResizeBounds(300, 400, 800, 1000) -- Modern API for resize limits
    frame:RegisterForDrag("LeftButton")
    frame:SetClampedToScreen(true)

    -- Background using Dragonflight atlas
    frame.bg = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    frame.bg:SetAllPoints()
    frame.bg:SetAtlas("characterupdate_background", true)
    frame.bg:SetAlpha(0.8)

    -- Darker overlay for better contrast
    frame.overlay = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
    frame.overlay:SetAllPoints()
    frame.overlay:SetColorTexture(0, 0, 0, 0.5)

    -- Don't clip children on main frame (for decorative header that extends outside)
    -- Clipping is done on contentFrame instead

    -- Get faction-specific atlas names
    local atlas = GetFactionAtlas()

    -- Borders using same tile with rotation (tiled and aligned with corners)
    local borderSize = 40 * BORDER_SCALE -- Base size: 40, scaled by BORDER_SCALE

    -- Corners (decorative) - Always 80px larger than borders for perfect fit
    local cornerSize = borderSize + 80

    -- Top Left Corner (no rotation)
    frame.cornerTL = frame:CreateTexture(nil, "OVERLAY", nil, 7)
    frame.cornerTL:SetSize(cornerSize, cornerSize)
    frame.cornerTL:SetPoint("TOPLEFT", frame, "TOPLEFT", -4, 4) -- Offset to extend outward
    frame.cornerTL:SetAtlas(atlas.cornerTopLeft, false)

    -- Top Right Corner (270° rotation - clockwise from top-left)
    frame.cornerTR = frame:CreateTexture(nil, "OVERLAY", nil, 7)
    frame.cornerTR:SetSize(cornerSize, cornerSize)
    frame.cornerTR:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 4, 4) -- Offset to extend outward
    frame.cornerTR:SetAtlas(atlas.cornerTopLeft, false)
    frame.cornerTR:SetRotation(math.rad(270))

    -- Bottom Right Corner (180° rotation)
    frame.cornerBR = frame:CreateTexture(nil, "OVERLAY", nil, 7)
    frame.cornerBR:SetSize(cornerSize, cornerSize)
    frame.cornerBR:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 4, -4) -- Offset to extend outward
    frame.cornerBR:SetAtlas(atlas.cornerTopLeft, false)
    frame.cornerBR:SetRotation(math.rad(180))

    -- Bottom Left Corner (90° rotation - counter-clockwise from top-left)
    frame.cornerBL = frame:CreateTexture(nil, "OVERLAY", nil, 7)
    frame.cornerBL:SetSize(cornerSize, cornerSize)
    frame.cornerBL:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", -4, -4) -- Offset to extend outward
    frame.cornerBL:SetAtlas(atlas.cornerTopLeft, false)
    frame.cornerBL:SetRotation(math.rad(90))

    -- Bottom border (no rotation, tiled on X axis)
    frame.borderBottom = frame:CreateTexture(nil, "BORDER", nil, 1)
    frame.borderBottom:SetHeight(borderSize)
    frame.borderBottom:SetPoint("BOTTOMLEFT", frame.cornerBL, "BOTTOMRIGHT", 0, 0)
    frame.borderBottom:SetPoint("BOTTOMRIGHT", frame.cornerBR, "BOTTOMLEFT", 0, 0)
    frame.borderBottom:SetAtlas(atlas.bottom, false)
    frame.borderBottom:SetHorizTile(true)

    -- Top border (180° rotation, tiled on X axis)
    frame.borderTop = frame:CreateTexture(nil, "BORDER", nil, 1)
    frame.borderTop:SetHeight(borderSize)
    frame.borderTop:SetPoint("TOPLEFT", frame.cornerTL, "TOPRIGHT", 0, 0)
    frame.borderTop:SetPoint("TOPRIGHT", frame.cornerTR, "TOPLEFT", 0, 0)
    frame.borderTop:SetAtlas(atlas.bottom, false)
    frame.borderTop:SetHorizTile(true)
    frame.borderTop:SetRotation(math.rad(180))

    -- Left border (using !HordeFrameTile-Left, no rotation needed)
    frame.borderLeft = frame:CreateTexture(nil, "BORDER", nil, 1)
    frame.borderLeft:SetWidth(borderSize)
    frame.borderLeft:SetPoint("TOPLEFT", frame.cornerTL, "BOTTOMLEFT", 0, 0)
    frame.borderLeft:SetPoint("BOTTOMLEFT", frame.cornerBL, "TOPLEFT", 0, 0)
    frame.borderLeft:SetAtlas(atlas.left, false)
    frame.borderLeft:SetVertTile(true)

    -- Right border (using !HordeFrameTile-Left with 180° rotation for mirroring)
    frame.borderRight = frame:CreateTexture(nil, "BORDER", nil, 1)
    frame.borderRight:SetWidth(borderSize)
    frame.borderRight:SetPoint("TOPRIGHT", frame.cornerTR, "BOTTOMRIGHT", 0, 0)
    frame.borderRight:SetPoint("BOTTOMRIGHT", frame.cornerBR, "TOPRIGHT", 0, 0)
    frame.borderRight:SetAtlas(atlas.left, false)
    frame.borderRight:SetVertTile(true)
    frame.borderRight:SetRotation(math.rad(180))

    -- Drag handlers (on main frame)
    frame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)

    -- Store reference to frame for bigHeader drag handlers
    frame.parentFrame = frame

    -- Resize grip (bottom right corner)
    local resizeGrip = CreateFrame("Button", nil, frame)
    resizeGrip:SetSize(16, 16)
    resizeGrip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    resizeGrip:EnableMouse(true)
    resizeGrip:RegisterForDrag("LeftButton")
    resizeGrip:SetFrameLevel(frame:GetFrameLevel() + 1)

    -- Resize grip texture
    resizeGrip.texture = resizeGrip:CreateTexture(nil, "OVERLAY")
    resizeGrip.texture:SetAllPoints()
    resizeGrip.texture:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")

    resizeGrip:SetScript("OnDragStart", function(self)
        frame:StartSizing("BOTTOMRIGHT")
    end)

    resizeGrip:SetScript("OnDragStop", function(self)
        frame:StopMovingOrSizing()
        -- Instant refresh when drag stops
        if contentFrame and backpackFrame and backpackFrame:IsShown() then
            ns.Layouts.Backpack.RefreshItems()
        end
    end)

    -- Instant resize with reduced debounce for smoother UX
    frame:SetScript("OnSizeChanged", function(self, width, height)
        if contentFrame and self:IsShown() then
            -- Debounce the grid refresh (0.02s = 20ms for nearly instant feedback)
            if self.resizeTimer then
                self.resizeTimer:Cancel()
            end
            self.resizeTimer = C_Timer.NewTimer(0.02, function()
                if self:IsShown() then
                    ns.Layouts.Backpack.RefreshItems()
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
            local handler = ns.Layouts.Backpack._escapeHandler
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

    frame:Hide()
    return frame
end

-- Create title bar
local function CreateTitleBar(parent)
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetPoint("TOPLEFT", parent, "TOPLEFT", 33, -45) -- 50/1.5 = 33px
    bar:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -33, -45) -- 50/1.5 = 33px
    bar:SetHeight(32)

    -- Get faction-specific atlas
    local atlas = GetFactionAtlas()

    -- Big decorative header (extends outside frame, ABOVE top border)
    -- Different Y offset for each faction (Horde needs less, Alliance needs more)
    local faction = GetPlayerFaction()
    local headerYOffset = faction == "Horde" and 80 or 107 -- Horde: 80, Alliance: 107

    local bigHeader = parent:CreateTexture(nil, "OVERLAY", nil, 7)
    bigHeader:SetSize(512, 128) -- Large size
    bigHeader:SetPoint("TOP", parent, "TOP", 0, headerYOffset)
    bigHeader:SetAtlas(atlas.header, true)
    bigHeader:SetAlpha(1.0) -- Full opacity
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

    -- NO background - transparent

    -- Character selector (portrait + name dropdown) - LEFT side
    if ns.Components.CharacterSelect then
        characterSelector = ns.Components.CharacterSelect.Create(bar, "backpack")
        characterSelector:SetPoint("LEFT", bar, "LEFT", 0, 0)

        -- Set callback for character change
        characterSelector:SetCallback(function(charKey, bagType)
            viewingCharKey = charKey
            ns.Layouts.Backpack.RefreshItems()

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
                    if viewMode == "all" then
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

    -- Sort button (bag icon with arrows, LEFT of options button)
    bar.sortButton = CreateFrame("Button", nil, bar)
    bar.sortButton:SetSize(24, 24)
    bar.sortButton:SetPoint("RIGHT", bar, "RIGHT", -60, 0) -- 60px before right edge (30 for close, 30 for options)

    -- Sort icon (bag with arrows)
    bar.sortButton.icon = bar.sortButton:CreateTexture(nil, "ARTWORK")
    bar.sortButton.icon:SetAllPoints()
    bar.sortButton.icon:SetAtlas("bags-icon")  -- Bag icon
    bar.sortButton.icon:SetVertexColor(1, 0.82, 0, 1) -- Gold color

    -- Hover effect
    bar.sortButton:SetScript("OnEnter", function(self)
        self.icon:SetVertexColor(1, 1, 1, 1) -- White on hover
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Sort Items", 1, 1, 1)
        GameTooltip:AddLine("Sorts all items by quality (Epic > Rare > Uncommon > Common)", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine("Tip: You can also middle-click inside the bag to sort", 0.5, 0.8, 1, true)
        GameTooltip:Show()
    end)
    bar.sortButton:SetScript("OnLeave", function(self)
        self.icon:SetVertexColor(1, 0.82, 0, 1) -- Gold normally
        GameTooltip:Hide()
    end)

    bar.sortButton:SetScript("OnClick", function()
        ns.Layouts.Backpack.SortItems()
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
        ns.Layouts.Backpack.ToggleOptions()
    end)

    -- Close button (aligned RIGHT)
    bar.closeButton = CreateFrame("Button", nil, bar)
    bar.closeButton:SetSize(24, 24)
    bar.closeButton:SetPoint("RIGHT", bar, "RIGHT", 0, 0)

    -- Try to load custom texture, fallback to text
    local hasTexture = false
    pcall(function()
        bar.closeButton:SetNormalTexture("Interface\\AddOns\\Nihui_iv\\media\\close")
        bar.closeButton:SetHighlightTexture("Interface\\AddOns\\Nihui_iv\\media\\close")
        if bar.closeButton:GetNormalTexture():GetTexture() then
            bar.closeButton:GetHighlightTexture():SetAlpha(0.5)
            hasTexture = true
        end
    end)

    -- Fallback to text if texture doesn't exist
    if not hasTexture then
        bar.closeButton:SetNormalFontObject("GameFontNormalLarge")
        bar.closeButton:SetText("×")
        -- Set text color through font string
        local fontString = bar.closeButton:GetFontString()
        if fontString then
            fontString:SetTextColor(1, 0.82, 0, 1)
        end
    end

    bar.closeButton:SetScript("OnClick", function()
        ns.Layouts.Backpack.Hide()
    end)

    return bar
end

-- Create search box with 9-slice background (no stretching!)
local function CreateSearchBox(parent)
    -- Container frame for search box
    local container = CreateFrame("Frame", nil, parent)
    container:SetPoint("TOPLEFT", parent, "TOPLEFT", 33, -85)
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

    -- EditBox on top with padding
    local box = CreateFrame("EditBox", nil, container)
    box:SetPoint("LEFT", bg, "LEFT", 12, 0) -- 12px left padding
    box:SetPoint("RIGHT", bg, "RIGHT", -12, 0) -- 12px right padding
    box:SetHeight(40)
    box:SetAutoFocus(false)
    box:SetFontObject("GameFontNormal")
    box:SetTextInsets(0, 0, 0, 0)
    box:SetTextColor(1, 0.82, 0, 1) -- Gold color to match headers
    box:SetMaxLetters(50)

    -- Remove default textures
    if box.Left then box.Left:Hide() end
    if box.Right then box.Right:Hide() end
    if box.Middle then box.Middle:Hide() end

    -- Placeholder text (gold color)
    box.placeholder = box:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    box.placeholder:SetPoint("LEFT", box, "LEFT", 0, 0)
    box.placeholder:SetText("Search items...")
    box.placeholder:SetTextColor(1, 0.82, 0, 0.5) -- Semi-transparent gold
    box.placeholder:SetJustifyH("LEFT")

    box:SetScript("OnTextChanged", function(self, userInput)
        if userInput then
            local text = self:GetText()
            if text == "" then
                box.placeholder:Show()
            else
                box.placeholder:Hide()
            end

            currentSearchText = text
            ns.Layouts.Backpack.RefreshItems()
        end
    end)

    box:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        self:SetText("")
        -- IMPORTANT: Reset search text and refresh to clear opacity filter
        currentSearchText = ""
        ns.Layouts.Backpack.RefreshItems()
    end)

    box:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)

    box:SetScript("OnEditFocusGained", function(self)
        self:HighlightText(0, 0) -- Don't select all on focus
    end)

    container.editBox = box
    return container
end

-- Create money display (NOW on RIGHT)
local function CreateMoneyDisplay(parent)
    local frame = ns.Components.Money.Create(parent, false)
    frame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -33, 38) -- 33px right to match left padding, reduced height
    return frame
end

-- Create currency display (NOW on LEFT)
local function CreateCurrencyDisplay(parent)
    local frame = ns.Components.Currency.Create(parent)
    frame:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 33, 38) -- 33px left, aligned with scroll content, reduced height
    return frame
end

-- Create free slots text
local function CreateFreeSlotsDisplay(parent)
    local text = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("BOTTOM", parent, "BOTTOM", 0, 26) -- Adjusted for borders, reduced from 38
    text:SetText("Free: 0/0")
    text:SetTextColor(1, 0.82, 0, 1) -- Gold color
    return text
end

-- Create content frame (scrollable area)
local function CreateContentFrame(parent)
    -- Create container frame with background and border
    local container = CreateFrame("Frame", nil, parent)
    container:SetPoint("TOPLEFT", parent, "TOPLEFT", 33, -141) -- 33px left, 141px top (85 + 48 + 8 margin)
    container:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -33, 65) -- 33px right (same as left!), 65px bottom (reduced from 80)

    -- Background (black panel)
    local bg = container:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(container)
    bg:SetColorTexture(0, 0, 0, 0.45) -- Black background, 45% opacity

    -- Border frame (extended beyond container like progress bars)
    local border = CreateFrame("Frame", nil, container, "BackdropTemplate")
    border:SetPoint("TOPLEFT", container, "TOPLEFT", -12, 12)
    border:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", 12, -12)
    border:SetBackdrop({
        edgeFile = "Interface\\AddOns\\Nihui_uf\\textures\\MirroredFrameSingleUF.tga",
        edgeSize = 16,
        insets = {left = 1, right = 1, top = 1, bottom = 1}
    })
    border:SetBackdropBorderColor(0.5, 0.5, 0.5, 1) -- Gray border
    border:SetFrameLevel(container:GetFrameLevel() + 5) -- Above content

    -- Create scroll frame INSIDE container with padding
    local scrollFrame = CreateFrame("ScrollFrame", "NihuiIVBackpackScrollFrame", container, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", container, "TOPLEFT", 8, -8) -- 8px padding
    scrollFrame:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -8, 8) -- 8px padding
    scrollFrame:SetClipsChildren(true) -- Prevent overflow
    scrollFrame:EnableMouse(true) -- Enable mouse for middle-click detection
    scrollFrame:EnableMouseWheel(true) -- Allow scrolling

    -- Middle-click to sort (using OnMouseUp directly on scrollFrame)
    -- Items in scrollChild will still receive their own click events (higher frameLevel)
    -- Disabled when viewing another character's inventory
    scrollFrame:SetScript("OnMouseUp", function(self, button)
        if button == "MiddleButton" and MouseIsOver(self) and viewMode == "all" and not IsViewingOther() then
            ns.Layouts.Backpack.SortItems()
        end
    end)

    -- No background - transparent for better visibility

    -- Create scroll child (content container with padding)
    local scrollChild = CreateFrame("Frame", "NihuiIVBackpackScrollChild", scrollFrame)
    scrollChild:SetSize(1, 1) -- Will be resized dynamically
    scrollChild:EnableMouse(false) -- Don't block mouse interactions
    scrollFrame:SetScrollChild(scrollChild)
    scrollFrame.scrollChild = scrollChild

    -- Style scrollbar - make it smaller and positioned at the edge
    local scrollBar = scrollFrame.ScrollBar
    if scrollBar then
        scrollBar:ClearAllPoints()
        scrollBar:SetPoint("TOPRIGHT", scrollFrame, "TOPRIGHT", 0, -16) -- At the edge (0 = right edge of scrollframe)
        scrollBar:SetPoint("BOTTOMRIGHT", scrollFrame, "BOTTOMRIGHT", 0, 16)

        -- Make scrollbar visually smaller
        if scrollBar.ScrollUpButton then
            scrollBar.ScrollUpButton:SetSize(12, 12)
        end
        if scrollBar.ScrollDownButton then
            scrollBar.ScrollDownButton:SetSize(12, 12)
        end
        if scrollBar.ThumbTexture then
            scrollBar.ThumbTexture:SetWidth(12)
        end
    end

    return scrollFrame
end

-- Update free slots display
local function UpdateFreeSlots()
    if not freeSlotsText then return end

    local bags = ns.Components.Items.GetBagConstants().BACKPACK
    local freeSlots = ns.Components.Items.GetFreeSlots(bags)
    local totalSlots = ns.Components.Items.GetTotalSlots(bags)

    freeSlotsText:SetText(string.format("Free: %d/%d", freeSlots, totalSlots))
end

-- Create or get existing category header
local function GetOrCreateCategoryHeader(categoryName, parent, maxWidth)
    -- Check if header already exists
    if categoryHeaders[categoryName] then
        local header = categoryHeaders[categoryName]

        -- Update to full width to ensure vertical stacking
        header:SetWidth(maxWidth)
        if header.headerText then
            header.headerText:Show()
        end

        return header
    end

    -- Create new header with compact spacing (NO background, just text)
    local header = CreateFrame("Frame", nil, parent)
    header:SetHeight(28) -- Compact: 8px top + 12px text + 8px bottom
    header:SetWidth(maxWidth) -- IMPORTANT: Take full width to force vertical stacking

    -- Header text (smaller font, no background)
    local headerText = header:CreateFontString(nil, "OVERLAY", "GameFontNormal") -- Normal instead of Large
    headerText:SetText(categoryName)
    headerText:SetJustifyH("LEFT")
    headerText:SetJustifyV("TOP")
    headerText:SetTextColor(1, 0.82, 0, 1) -- Gold color
    headerText:SetDrawLayer("OVERLAY", 7)
    headerText:Show()
    header.headerText = headerText

    -- Position text at top left of header with small margin
    headerText:SetPoint("TOPLEFT", header, "TOPLEFT", 0, -8) -- 8px top margin

    -- Store for reuse
    categoryHeaders[categoryName] = header

    return header
end

-- Sort cooldown tracking
local lastSortTime = 0
local SORT_COOLDOWN = 2 -- 2 seconds cooldown

-- Sort items (only in "all" mode)
function ns.Layouts.Backpack.SortItems()
    if viewMode ~= "all" then
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
    if currentTime - lastSortTime < SORT_COOLDOWN then
        local remaining = math.ceil(SORT_COOLDOWN - (currentTime - lastSortTime))
        ns:Print("Please wait " .. remaining .. " second(s) before sorting again")
        return
    end

    -- Update last sort time
    lastSortTime = currentTime

    -- Use WoW's built-in sort function
    C_Container.SortBags()
    ns:Print("Items sorted!")

    -- Refresh after delays to ensure WoW finishes sorting
    -- First refresh at 0.3s
    C_Timer.After(0.3, function()
        if backpackFrame and backpackFrame:IsShown() then
            ns.Layouts.Backpack.RefreshItems()
        end
    end)

    -- Second refresh at 0.6s to catch any stragglers
    C_Timer.After(0.6, function()
        if backpackFrame and backpackFrame:IsShown() then
            ns.Layouts.Backpack.RefreshItems()
        end
    end)
end

-- Toggle view mode between "all" and "category"
function ns.Layouts.Backpack.ToggleViewMode()
    viewMode = (viewMode == "all") and "category" or "all"
    ns.Layouts.Backpack.RefreshItems()

    -- Update sort button visibility based on view mode
    if titleBar and titleBar.sortButton then
        if viewMode == "all" then
            titleBar.sortButton:Show()
        else
            titleBar.sortButton:Hide()
        end
    end

    print("|cff9482c9Nihui|r: View mode set to " .. viewMode)
end

-- Set view mode explicitly
function ns.Layouts.Backpack.SetViewMode(mode)
    if mode ~= "all" and mode ~= "category" then
        print("|cff9482c9Nihui|r: Invalid view mode. Use 'all' or 'category'")
        return
    end
    viewMode = mode
    ns.Layouts.Backpack.RefreshItems()

    -- Update sort button visibility based on view mode
    if titleBar and titleBar.sortButton then
        if viewMode == "all" then
            titleBar.sortButton:Show()
        else
            titleBar.sortButton:Hide()
        end
    end
end

-- Refresh items by category (with headers)
local function RefreshItemsByCategory(items, scrollChild, contentWidth, columns, spacing)
    local const = getConst()
    local slotSize = ns.db.backpackIconSize or 37 -- Use configured size
    local slotTotalSize = slotSize + spacing

    -- Group items by category
    local groupedItems = ns.Components.Categories.GroupItemsByCategory(items, const.BAG_KIND.BACKPACK)

    -- Get sorted category names (prioritized)
    local categoryOrder = {}
    for categoryName in pairs(groupedItems) do
        table.insert(categoryOrder, categoryName)
    end

    -- Sort categories alphabetically, but put "Empty Slots" and "Uncategorized" at the end
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
            -- Create category header
            local header = GetOrCreateCategoryHeader(categoryName, scrollChild, contentWidth)
            header:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, currentY)
            header:Show()

            currentY = currentY - 28 -- Header height
            totalHeight = totalHeight + 28

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
            end

            currentY = currentY - categoryHeight
            totalHeight = totalHeight + categoryHeight
        end
    end

    -- Set scrollChild height
    scrollChild:SetSize(math.max(contentWidth, columns * slotTotalSize), math.max(100, totalHeight + 20))
end

-- Refresh items in all-in-one mode (no categories)
local function RefreshItemsAllInOne(items, scrollChild, contentWidth, columns, spacing)
    local slotSize = ns.db.backpackIconSize or 37 -- Use configured size
    local slotTotalSize = slotSize + spacing

    -- Count items
    local numItems = 0
    for _ in pairs(items) do numItems = numItems + 1 end

    -- Calculate grid height
    local rows = math.ceil(numItems / columns)
    local gridHeight = rows * slotTotalSize

    -- Set scrollChild size
    scrollChild:SetSize(math.max(contentWidth, columns * slotTotalSize), math.max(100, gridHeight + 20))

    -- Create slots directly on scrollChild with dynamic columns
    local allSlots = ns.Components.Slots.CreateGrid(scrollChild, items, columns, spacing, slotSize)
end

-- Refresh items in grid
function ns.Layouts.Backpack.RefreshItems()
    if not contentFrame or not backpackFrame:IsShown() then return end

    -- Release old slots
    ns.Components.Slots.ReleaseAll()

    -- Get backpack items (from cache if viewing another character)
    local items
    if IsViewingOther() and viewingCharKey then
        items = ns.Components.Items.GetCachedBackpackItems(viewingCharKey)
    else
        items = ns.Components.Items.GetBackpackItems()
    end

    -- Rebuild search index with current items
    ns.Components.Search.RebuildIndex(items)

    -- Apply stacking: merge identical items (like multiple chests)
    items = ns.Components.Stacking.FilterStackedItems(items)

    -- Count and merge empty slots into single "Empty Slots" item
    local emptySlotCount = 0
    local filteredItems = {}
    local firstEmptySlotKey = nil

    for slotKey, itemData in pairs(items) do
        if itemData.isEmpty then
            emptySlotCount = emptySlotCount + 1
            -- Keep reference to first empty slot for position
            if not firstEmptySlotKey then
                firstEmptySlotKey = slotKey
            end
        else
            -- Keep all non-empty items
            filteredItems[slotKey] = itemData
        end
    end

    -- Add single merged "Empty Slots" item if we have any empty slots (ONLY if option enabled)
    if emptySlotCount > 0 and firstEmptySlotKey and (ns.db.backpackShowEmptySlots ~= false) then
        filteredItems[firstEmptySlotKey] = {
            bagID = 0,
            slotID = 0,
            slotKey = firstEmptySlotKey,
            isEmpty = false,
            isEmptySlotStack = true,  -- Special flag
            emptySlotCount = emptySlotCount,
            itemTexture = "Interface\\Icons\\INV_Misc_QuestionMark",  -- Gray question mark icon
            currentItemCount = emptySlotCount,
            itemQuality = 0,  -- Poor quality = gray
        }
    end

    items = filteredItems

    -- Apply search filter if active
    if currentSearchText ~= "" then
        local searchResults = ns.Components.Search.Search(currentSearchText)
        items = ns.Components.Search.ApplySearchResults(items, searchResults)
    end

    -- Get dynamic content width (scrollChild width)
    local scrollChild = contentFrame.scrollChild
    local contentWidth = contentFrame:GetWidth() - 20 -- Account for scrollbar and padding

    -- Calculate dynamic columns based on available width
    -- Use configured icon size (default 37px)
    local slotSize = ns.db.backpackIconSize or 37
    local spacing = 4
    local slotTotalSize = slotSize + spacing
    local columns = math.max(1, math.floor((contentWidth + spacing) / slotTotalSize))

    -- Hide all existing category headers
    for _, header in pairs(categoryHeaders) do
        header:Hide()
    end

    -- Render based on view mode
    if viewMode == "category" then
        RefreshItemsByCategory(items, scrollChild, contentWidth, columns, spacing)
    else
        RefreshItemsAllInOne(items, scrollChild, contentWidth, columns, spacing)
    end

    -- Update free slots
    UpdateFreeSlots()
end

-- Show backpack
function ns.Layouts.Backpack.Show()
    -- Don't open backpack if bank is open (prevent concurrency issues)
    if ns.Layouts.Bank and ns.Layouts.Bank.IsShown() then
        return
    end

    if not backpackFrame then
        ns.Layouts.Backpack.Initialize()
    end

    backpackFrame:Show()
    ns.Layouts.Backpack.RefreshItems()

    -- Update money and currency
    if moneyFrame then
        moneyFrame:Update()
    end
    if currencyFrame then
        currencyFrame:Update()
    end
end

-- Hide backpack
function ns.Layouts.Backpack.Hide()
    if backpackFrame then
        -- Close dropdown if open
        if characterSelector and characterSelector.CloseDropdown then
            characterSelector:CloseDropdown()
        end
        backpackFrame:Hide()
    end
end

-- Check if backpack is shown
function ns.Layouts.Backpack.IsShown()
    return backpackFrame and backpackFrame:IsShown()
end

-- Toggle backpack
function ns.Layouts.Backpack.Toggle()
    if ns.Layouts.Backpack.IsShown() then
        ns.Layouts.Backpack.Hide()
    else
        ns.Layouts.Backpack.Show()
    end
end

-- Check if viewing another character (for ESC handling)
function ns.Layouts.Backpack.IsViewingOther()
    return characterSelector and characterSelector:IsViewingOther() or false
end

-- Return to current character (for ESC handling)
function ns.Layouts.Backpack.ReturnToCurrent()
    if characterSelector and characterSelector.ReturnToCurrent then
        characterSelector:ReturnToCurrent()
        return true
    end
    return false
end

-- Toggle options panel
function ns.Layouts.Backpack.ToggleOptions()
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
function ns.Layouts.Backpack.ShowOptions()
    if not contentContainer or not optionsView then return end
    contentContainer:Hide()
    optionsView:Show()

    -- Hide close button (moins confusant)
    if titleBar and titleBar.closeButton then
        titleBar.closeButton:Hide()
    end
end

-- Hide options panel
function ns.Layouts.Backpack.HideOptions()
    if not contentContainer or not optionsView then return end
    optionsView:Hide()
    contentContainer:Show()

    -- Show close button again
    if titleBar and titleBar.closeButton then
        titleBar.closeButton:Show()
    end
end

-- Update big header visibility (direct refresh)
function ns.Layouts.Backpack.UpdateBigHeaderVisibility()
    if not titleBar or not titleBar.bigHeader then return end

    local shouldShow = ns.db.showBigHeader ~= false
    if shouldShow then
        titleBar.bigHeader:Show()
    else
        titleBar.bigHeader:Hide()
    end
end

-- Set ESC key handler (called from init.lua)
function ns.Layouts.Backpack.SetEscapeHandler(handler)
    ns.Layouts.Backpack._escapeHandler = handler
end

-- Initialize backpack
function ns.Layouts.Backpack.Initialize()
    if backpackFrame then return end

    -- Initialize viewMode from DB (or default to "category")
    viewMode = ns.db.backpackViewMode or "category"

    -- Create main frame
    backpackFrame = CreateBackpackFrame()

    -- Create title bar (ALWAYS visible)
    titleBar = CreateTitleBar(backpackFrame)

    -- Create contentContainer (wraps all normal content - can be hidden when showing options)
    contentContainer = CreateFrame("Frame", nil, backpackFrame)
    contentContainer:SetAllPoints(backpackFrame)

    -- Create all normal content INSIDE contentContainer
    searchBox = CreateSearchBox(contentContainer)
    contentFrame = CreateContentFrame(contentContainer)
    moneyFrame = CreateMoneyDisplay(contentContainer)
    currencyFrame = CreateCurrencyDisplay(contentContainer)
    freeSlotsText = CreateFreeSlotsDisplay(contentContainer)

    -- Create options view (hidden by default)
    if ns.Config and ns.Config.Options then
        -- Options view should cover the same area as contentContainer
        local optionsContainer = CreateFrame("Frame", nil, backpackFrame)
        optionsContainer:SetPoint("TOPLEFT", backpackFrame, "TOPLEFT", 33, -117) -- Start below search bar (same as contentFrame)
        optionsContainer:SetPoint("BOTTOMRIGHT", backpackFrame, "BOTTOMRIGHT", -33, 80) -- Same as contentFrame (above money/currency)

        optionsView = ns.Config.Options.CreateView(optionsContainer, "backpack")  -- Default to backpack tab
        optionsView:Hide()
    end

    -- Grid system disabled for now - we create slots directly on scrollChild
    -- TODO: Re-enable when implementing categories
    -- local scrollChild = contentFrame.scrollChild
    -- itemGrid = ns.Components.Grid.Create(scrollChild)
    -- itemGrid:SetSpacing(4)
    -- itemGrid:SetColumns(1)
    -- itemGrid.frame:SetAllPoints(scrollChild)

    -- Register for item updates
    ns.Components.Items.SetItemsChangedCallback(function()
        if backpackFrame:IsShown() then
            ns.Layouts.Backpack.RefreshItems()
        end
    end)

    -- Register for money updates
    ns.Components.Events.RegisterEvent("PLAYER_MONEY", function()
        if moneyFrame and backpackFrame:IsShown() then
            moneyFrame:Update()
        end
    end)

    -- Register for currency updates
    ns.Components.Events.RegisterEvent("CURRENCY_DISPLAY_UPDATE", function()
        if currencyFrame and backpackFrame:IsShown() then
            currencyFrame:Update()
        end
    end)

    -- ESC key handling via OnKeyDown (configured in init.lua via SetEscapeHandler)
    -- First ESC in preview mode: returns to current character (keeps window open)
    -- Second ESC (or first in normal mode): closes the window
    -- Does NOT use UISpecialFrames to avoid conflicts with menu opening

    -- Initialize sort button visibility based on current view mode
    if titleBar and titleBar.sortButton then
        if viewMode == "all" then
            titleBar.sortButton:Show()
        else
            titleBar.sortButton:Hide()
        end
    end

    ns:Print("Backpack layout initialized!")
end

-- Destroy backpack (for reset)
function ns.Layouts.Backpack.Destroy()
    if backpackFrame then
        backpackFrame:Hide()
        backpackFrame = nil
    end
    contentContainer = nil
    optionsView = nil
    contentFrame = nil
    searchBox = nil
    moneyFrame = nil
    currencyFrame = nil
    itemGrid = nil
    titleText = nil
    titleBar = nil
    freeSlotsText = nil
    currentSearchText = ""
    categoryHeaders = {}
    categoryGrids = {}

    -- Release all slots
    ns.Components.Slots.ReleaseAll()
end
