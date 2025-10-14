-- components/characterselect.lua - Character selection dropdown UI with portrait
local addonName, ns = ...

ns.Components = ns.Components or {}
ns.Components.CharacterSelect = {}

-- Class colors
local CLASS_COLORS = {
    WARRIOR = {0.78, 0.61, 0.43},
    PALADIN = {0.96, 0.55, 0.73},
    HUNTER = {0.67, 0.83, 0.45},
    ROGUE = {1.00, 0.96, 0.41},
    PRIEST = {1.00, 1.00, 1.00},
    DEATHKNIGHT = {0.77, 0.12, 0.23},
    SHAMAN = {0.00, 0.44, 0.87},
    MAGE = {0.41, 0.80, 0.94},
    WARLOCK = {0.58, 0.51, 0.79},
    MONK = {0.00, 1.00, 0.59},
    DRUID = {1.00, 0.49, 0.04},
    DEMONHUNTER = {0.64, 0.19, 0.79},
    EVOKER = {0.20, 0.58, 0.50},
}

-- Get class icon atlas
local function GetClassIcon(className)
    if not className then return nil end
    return "classicon-" .. className:lower()
end

-- Format time ago
local function FormatTimeAgo(timestamp)
    if not timestamp then return "Never" end

    local diff = time() - timestamp

    if diff < 60 then
        return "Just now"
    elseif diff < 3600 then
        local minutes = math.floor(diff / 60)
        return minutes .. "m ago"
    elseif diff < 86400 then
        local hours = math.floor(diff / 3600)
        return hours .. "h ago"
    else
        local days = math.floor(diff / 86400)
        return days .. "d ago"
    end
end

-- Create character selector (portrait + name dropdown)
function ns.Components.CharacterSelect.Create(parent, bagType)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(300, 40)

    local currentCharKey = ns.Components.Cache.GetCurrentCharacterKey()
    local viewingCharKey = currentCharKey  -- Default to current character
    local onCharacterChanged = nil

    -- Portrait frame (class icon)
    local portrait = container:CreateTexture(nil, "ARTWORK")
    portrait:SetSize(32, 32)
    portrait:SetPoint("LEFT", container, "LEFT", 0, 0)

    -- Portrait border
    local portraitBorder = container:CreateTexture(nil, "OVERLAY")
    portraitBorder:SetSize(56, 56)  -- 32 + 24 for visible border
    portraitBorder:SetPoint("CENTER", portrait, "CENTER", 0, 0)
    portraitBorder:SetAtlas("charactercreate-ring", false)
    portraitBorder:SetVertexColor(1, 0.82, 0, 1)

    -- Character name button (dropdown trigger)
    local nameButton = CreateFrame("Button", nil, container)
    nameButton:SetSize(200, 32)  -- Match portrait height
    nameButton:SetPoint("TOPLEFT", portrait, "TOPRIGHT", 8, 0)  -- Align with top of portrait

    -- Name text
    local nameText = nameButton:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    nameText:SetPoint("TOPLEFT", nameButton, "TOPLEFT", 0, 0)  -- Align to top-left
    nameText:SetJustifyH("LEFT")
    nameText:SetJustifyV("TOP")  -- Align text to top
    nameText:SetTextColor(1, 0.82, 0, 1)

    -- Dropdown arrow icon
    local arrowIcon = nameButton:CreateTexture(nil, "OVERLAY")
    arrowIcon:SetSize(12, 12)
    arrowIcon:SetPoint("LEFT", nameText, "RIGHT", 4, 0)
    arrowIcon:SetAtlas("common-dropdown-icon", false)
    arrowIcon:SetVertexColor(1, 0.82, 0, 1)

    -- "Viewing" indicator (shown when viewing another character)
    local viewingText = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    viewingText:SetPoint("BOTTOMLEFT", nameButton, "TOPLEFT", 0, 2)
    viewingText:SetText("Viewing:")
    viewingText:SetTextColor(0.7, 0.7, 0.7, 1)
    viewingText:Hide()

    -- Last update time
    local lastUpdateText = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lastUpdateText:SetPoint("TOPLEFT", nameText, "BOTTOMLEFT", 0, -2)  -- Relative to nameText instead of nameButton
    lastUpdateText:SetTextColor(0.6, 0.6, 0.6, 1)
    lastUpdateText:SetJustifyH("LEFT")

    -- Update display for a character
    local function UpdateDisplay(charKey)
        viewingCharKey = charKey
        local charInfo = ns.Components.Cache.GetCharacterInfo(charKey)

        if not charInfo then
            nameText:SetText("Unknown")
            portrait:SetTexture(nil)
            lastUpdateText:SetText("")
            return
        end

        -- Update name with class color
        local classColor = CLASS_COLORS[charInfo.class] or {1, 1, 1}
        nameText:SetText(charInfo.name)
        nameText:SetTextColor(classColor[1], classColor[2], classColor[3], 1)

        -- Update portrait (class icon)
        local classIcon = GetClassIcon(charInfo.class)
        if classIcon then
            portrait:SetAtlas(classIcon, false)
        end

        -- Update viewing indicator
        if charKey ~= currentCharKey then
            viewingText:Show()
        else
            viewingText:Hide()
        end

        -- Update last update time
        local cachedChars = ns.Components.Cache.GetCachedCharacters()
        for _, char in ipairs(cachedChars) do
            if char.key == charKey then
                lastUpdateText:SetText(FormatTimeAgo(char.lastUpdate))
                break
            end
        end
    end

    -- Store reference to active menu (for closing on hide)
    local activeMenu = nil

    -- Create dropdown menu
    local function ShowDropdown()
        local characters = ns.Components.Cache.GetCachedCharacters()

        if #characters == 0 then
            return
        end

        -- Close existing menu if any
        if activeMenu then
            activeMenu:Hide()
            activeMenu = nil
        end

        -- Create menu
        local menu = CreateFrame("Frame", nil, container, "BackdropTemplate")
        menu:SetPoint("TOPLEFT", nameButton, "BOTTOMLEFT", 0, -2)
        menu:SetFrameStrata("DIALOG")
        menu:SetFrameLevel(1000)
        menu:SetSize(250, math.min(300, #characters * 40 + 20))
        activeMenu = menu

        -- Background
        menu:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\AddOns\\Nihui_uf\\textures\\MirroredFrameSingleUF.tga",
            edgeSize = 16,
            insets = {left = 12, right = 12, top = 12, bottom = 12}
        })
        menu:SetBackdropColor(0, 0, 0, 0.95)
        menu:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)

        -- Close menu when clicking outside
        menu:SetScript("OnHide", function(self)
            self:SetParent(nil)
            if activeMenu == self then
                activeMenu = nil
            end
        end)

        -- Scroll frame for menu items
        local scrollFrame = CreateFrame("ScrollFrame", nil, menu, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", menu, "TOPLEFT", 12, -12)
        scrollFrame:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", -32, 12)

        local scrollChild = CreateFrame("Frame", nil, scrollFrame)
        scrollChild:SetSize(206, #characters * 40)
        scrollFrame:SetScrollChild(scrollChild)

        -- Create menu items
        local yOffset = 0
        for _, char in ipairs(characters) do
            local item = CreateFrame("Button", nil, scrollChild)
            item:SetSize(206, 36)
            item:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, yOffset)

            -- Highlight on hover
            local highlight = item:CreateTexture(nil, "BACKGROUND")
            highlight:SetAllPoints()
            highlight:SetColorTexture(1, 1, 1, 0.1)
            highlight:Hide()

            item:SetScript("OnEnter", function(self)
                highlight:Show()
            end)
            item:SetScript("OnLeave", function(self)
                highlight:Hide()
            end)

            -- Portrait
            local charPortrait = item:CreateTexture(nil, "ARTWORK")
            charPortrait:SetSize(28, 28)
            charPortrait:SetPoint("LEFT", item, "LEFT", 4, 0)
            local classIcon = GetClassIcon(char.class)
            if classIcon then
                charPortrait:SetAtlas(classIcon, false)
            end

            -- Name
            local charName = item:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            charName:SetPoint("LEFT", charPortrait, "RIGHT", 6, 4)
            charName:SetJustifyH("LEFT")
            local classColor = CLASS_COLORS[char.class] or {1, 1, 1}
            charName:SetText(char.name)
            charName:SetTextColor(classColor[1], classColor[2], classColor[3], 1)

            -- Level and realm
            local charInfo = item:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            charInfo:SetPoint("TOPLEFT", charName, "BOTTOMLEFT", 0, -2)
            charInfo:SetText("Lv" .. char.level .. " - " .. char.realm)
            charInfo:SetTextColor(0.7, 0.7, 0.7, 1)

            -- Last update
            local lastUpdate = item:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            lastUpdate:SetPoint("RIGHT", item, "RIGHT", -4, 0)
            lastUpdate:SetText(FormatTimeAgo(char.lastUpdate))
            lastUpdate:SetTextColor(0.5, 0.5, 0.5, 1)

            -- Current indicator
            if char.isCurrent then
                local currentIcon = item:CreateTexture(nil, "OVERLAY")
                currentIcon:SetSize(12, 12)
                currentIcon:SetPoint("RIGHT", lastUpdate, "LEFT", -4, 0)
                currentIcon:SetAtlas("auctionhouse-icon-favorite", false)
                currentIcon:SetVertexColor(1, 0.82, 0, 1)
            end

            -- Click to select
            item:SetScript("OnClick", function(self)
                menu:Hide()
                UpdateDisplay(char.key)

                -- Notify callback
                if onCharacterChanged then
                    onCharacterChanged(char.key, bagType)
                end
            end)

            yOffset = yOffset - 40
        end

        menu:Show()

        -- Close menu when clicking outside
        C_Timer.After(0.1, function()
            menu:SetScript("OnUpdate", function(self)
                if not MouseIsOver(self) and not MouseIsOver(nameButton) then
                    if GetMouseButtonClicked() then
                        self:Hide()
                        self:SetScript("OnUpdate", nil)
                    end
                end
            end)
        end)
    end

    -- Name button click handler (toggle dropdown)
    nameButton:SetScript("OnClick", function()
        if activeMenu and activeMenu:IsShown() then
            activeMenu:Hide()
        else
            ShowDropdown()
        end
    end)

    -- Hover effect with tooltip
    nameButton:SetScript("OnEnter", function()
        nameText:SetTextColor(1, 1, 1, 1)
        arrowIcon:SetVertexColor(1, 1, 1, 1)

        -- Show tooltip
        GameTooltip:SetOwner(nameButton, "ANCHOR_BOTTOM")

        if viewingCharKey ~= currentCharKey then
            -- Viewing another character - read-only mode
            GameTooltip:SetText("Viewing Another Character", 1, 0.82, 0, 1)
            GameTooltip:AddLine("You are viewing cached inventory data", 1, 1, 1, true)
            GameTooltip:AddLine(" ", 1, 1, 1)
            GameTooltip:AddLine("Read-only mode:", 0.8, 0.8, 0.8)
            GameTooltip:AddLine("• Cannot sort items", 0.6, 0.6, 0.6, true)
            GameTooltip:AddLine("• Cannot move items", 0.6, 0.6, 0.6, true)
            GameTooltip:AddLine("• Cannot transfer items", 0.6, 0.6, 0.6, true)
            GameTooltip:AddLine(" ", 1, 1, 1)
            GameTooltip:AddLine("Click to view another character", 0.5, 0.8, 1, true)
        else
            -- Viewing current character
            GameTooltip:SetText("Character Inventory Viewer", 1, 0.82, 0, 1)
            GameTooltip:AddLine("Click to view other characters' inventories", 1, 1, 1, true)
            GameTooltip:AddLine(" ", 1, 1, 1)
            GameTooltip:AddLine("Your addon automatically caches inventory data", 0.7, 0.7, 0.7, true)
            GameTooltip:AddLine("from all characters on this account", 0.7, 0.7, 0.7, true)
        end

        GameTooltip:Show()
    end)
    nameButton:SetScript("OnLeave", function()
        local charInfo = ns.Components.Cache.GetCharacterInfo(viewingCharKey)
        if charInfo then
            local classColor = CLASS_COLORS[charInfo.class] or {1, 1, 1}
            nameText:SetTextColor(classColor[1], classColor[2], classColor[3], 1)
        end
        arrowIcon:SetVertexColor(1, 0.82, 0, 1)
        GameTooltip:Hide()
    end)

    -- Public API
    function container:SetCharacter(charKey)
        UpdateDisplay(charKey)
    end

    function container:GetCurrentCharacter()
        return viewingCharKey
    end

    function container:SetCallback(callback)
        onCharacterChanged = callback
    end

    function container:IsViewingOther()
        return viewingCharKey ~= currentCharKey
    end

    function container:ReturnToCurrent()
        UpdateDisplay(currentCharKey)
        if onCharacterChanged then
            onCharacterChanged(currentCharKey, bagType)
        end
    end

    function container:CloseDropdown()
        if activeMenu then
            activeMenu:Hide()
        end
    end

    -- Initialize with current character
    UpdateDisplay(currentCharKey)

    return container
end
