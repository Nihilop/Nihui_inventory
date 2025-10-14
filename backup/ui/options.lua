-- ui/options.lua - Options panel UI
local addonName, ns = ...

ns.UI.Options = {}

local optionsFrame = nil

-- Sort types available
local SORT_TYPES = {
    {id = "default", label = "Default (Blizzard)", icon = "Interface\\Icons\\INV_Misc_QuestionMark"},
    {id = "name", label = "Alphabetical (A-Z)", icon = "Interface\\Icons\\INV_Misc_Book_11"},
    {id = "quality", label = "Quality (Rare first)", icon = "Interface\\Icons\\INV_Misc_Gem_Diamond_01"},
    {id = "ilvl", label = "Item Level", icon = "Interface\\Icons\\INV_Jewelry_Ring_56"},
    {id = "type", label = "Type (Armor, Weapon, etc.)", icon = "Interface\\Icons\\INV_Chest_Plate01"},
    {id = "value", label = "Vendor Price", icon = "Interface\\Icons\\INV_Misc_Coin_01"},
}

-- Create modern dropdown select
function ns.UI.Options.CreateSelect(parent, label, options, currentValue, onChange)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(300, 70)

    -- Label
    local labelText = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    labelText:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
    labelText:SetText(label)

    -- Select button
    local selectButton = CreateFrame("Button", nil, container, "BackdropTemplate")
    selectButton:SetSize(300, 36)
    selectButton:SetPoint("TOPLEFT", labelText, "BOTTOMLEFT", 0, -8)

    local borderConfig = ns.db.border or ns.defaults.border
    selectButton:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = borderConfig.enabled and borderConfig.texture or nil,
        edgeSize = borderConfig.edgeSize or 16,
        tile = false,
        insets = {left = 8, right = 8, top = 8, bottom = 8}
    })
    selectButton:SetBackdropColor(0, 0, 0, 0.5)
    if borderConfig.enabled then
        selectButton:SetBackdropBorderColor(unpack(borderConfig.color))
    end

    -- Current value text
    local valueText = selectButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    valueText:SetPoint("LEFT", selectButton, "LEFT", 12, 0)
    valueText:SetText(currentValue or "Select...")

    -- Dropdown arrow icon
    local arrow = selectButton:CreateTexture(nil, "OVERLAY")
    arrow:SetSize(16, 16)
    arrow:SetPoint("RIGHT", selectButton, "RIGHT", -10, 0)
    arrow:SetAtlas("charactercreate-customize-dropdownbox-arrows")

    -- Highlight
    selectButton:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")

    -- Dropdown menu frame (hidden by default)
    local dropdown = CreateFrame("Frame", nil, selectButton, "BackdropTemplate")
    dropdown:SetFrameStrata("TOOLTIP") -- Changed from DIALOG to avoid blocking game menu
    dropdown:SetFrameLevel(selectButton:GetFrameLevel() + 10)
    dropdown:SetPoint("TOPLEFT", selectButton, "BOTTOMLEFT", 0, -2)
    dropdown:SetSize(300, #options * 40 + 10)

    dropdown:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = borderConfig.enabled and borderConfig.texture or nil,
        edgeSize = borderConfig.edgeSize or 16,
        tile = false,
        insets = {left = 8, right = 8, top = 8, bottom = 8}
    })
    dropdown:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
    if borderConfig.enabled then
        dropdown:SetBackdropBorderColor(0.58, 0.51, 0.79, 1) -- Nihui purple
    end

    dropdown:Hide()

    -- Create option buttons
    dropdown.options = {}
    for i, option in ipairs(options) do
        local optionBtn = CreateFrame("Button", nil, dropdown, "BackdropTemplate")
        optionBtn:SetSize(280, 36)

        if i == 1 then
            optionBtn:SetPoint("TOPLEFT", dropdown, "TOPLEFT", 10, -10)
        else
            optionBtn:SetPoint("TOPLEFT", dropdown.options[i - 1], "BOTTOMLEFT", 0, -4)
        end

        optionBtn:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground"
        })
        optionBtn:SetBackdropColor(0, 0, 0, 0)

        -- Icon (optional)
        if option.icon then
            local icon = optionBtn:CreateTexture(nil, "ARTWORK")
            icon:SetSize(24, 24)
            icon:SetPoint("LEFT", optionBtn, "LEFT", 8, 0)
            icon:SetTexture(option.icon)
            optionBtn.icon = icon
        end

        -- Label
        local optionLabel = optionBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        if option.icon then
            optionLabel:SetPoint("LEFT", optionBtn.icon, "RIGHT", 8, 0)
        else
            optionLabel:SetPoint("LEFT", optionBtn, "LEFT", 12, 0)
        end
        optionLabel:SetText(option.label)
        optionBtn.label = optionLabel

        -- Checkmark (if selected)
        local checkmark = optionBtn:CreateTexture(nil, "OVERLAY")
        checkmark:SetSize(16, 16)
        checkmark:SetPoint("RIGHT", optionBtn, "RIGHT", -8, 0)
        checkmark:SetAtlas("communities-icon-checkmark")
        checkmark:Hide()
        optionBtn.checkmark = checkmark

        -- Hover effect
        optionBtn:SetScript("OnEnter", function(self)
            self:SetBackdropColor(0.58, 0.51, 0.79, 0.3) -- Nihui purple
        end)

        optionBtn:SetScript("OnLeave", function(self)
            self:SetBackdropColor(0, 0, 0, 0)
        end)

        -- Click handler
        optionBtn:SetScript("OnClick", function(self)
            valueText:SetText(option.label)
            dropdown:Hide()

            -- Update checkmarks
            for _, btn in ipairs(dropdown.options) do
                btn.checkmark:Hide()
            end
            self.checkmark:Show()

            -- Callback
            if onChange then
                onChange(option.id, option)
            end
        end)

        table.insert(dropdown.options, optionBtn)

        -- Show checkmark if current value
        if option.id == currentValue or option.label == currentValue then
            checkmark:Show()
        end
    end

    -- Toggle dropdown
    selectButton:SetScript("OnClick", function(self)
        if dropdown:IsShown() then
            dropdown:Hide()
        else
            dropdown:Show()
        end
    end)

    -- Close dropdown when clicking outside
    dropdown:SetScript("OnHide", function(self)
        arrow:SetRotation(0) -- Reset arrow
    end)

    dropdown:SetScript("OnShow", function(self)
        arrow:SetRotation(math.rad(180)) -- Flip arrow
    end)

    container.selectButton = selectButton
    container.dropdown = dropdown
    container.valueText = valueText

    return container
end

-- Create options panel
function ns.UI.Options.Create(parent)
    if optionsFrame then
        return optionsFrame
    end

    local frame = CreateFrame("Frame", "NihuiIVOptionsPanel", parent)
    frame:SetAllPoints(parent)

    -- Title
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -20)
    title:SetText("|cff9482c9Nihui IV|r Options")

    -- Content container (scrollable in the future)
    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -20)
    content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 20)

    -- Section: Sorting
    local sortSection = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    sortSection:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
    sortSection:SetText("Sorting")

    local sortDesc = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    sortDesc:SetPoint("TOPLEFT", sortSection, "BOTTOMLEFT", 0, -8)
    sortDesc:SetText("Choose how items are sorted when using the Sort button.")
    sortDesc:SetJustifyH("LEFT")
    sortDesc:SetWordWrap(true)
    sortDesc:SetWidth(400)

    -- Sort type select
    local currentSort = (ns.db and ns.db.sortType) or "default"
    local sortSelect = ns.UI.Options.CreateSelect(
        content,
        "Sort Type",
        SORT_TYPES,
        currentSort,
        function(selectedId, selectedOption)
            ns.db.sortType = selectedId
            ns:Print("Sort type changed to: " .. selectedOption.label)
        end
    )
    sortSelect:SetPoint("TOPLEFT", sortDesc, "BOTTOMLEFT", 0, -20)

    -- TODO: Add more options here (slot size, columns, etc.)

    optionsFrame = frame
    return frame
end

-- Show options panel
function ns.UI.Options.Show()
    if not optionsFrame then
        -- Create in main frame if it exists
        local mainFrame = _G["NihuiIVFrame"]
        if mainFrame and mainFrame.itemGrid then
            ns.UI.Options.Create(mainFrame.itemGrid:GetParent())
        end
    end

    if optionsFrame then
        optionsFrame:Show()
    end
end

-- Hide options panel
function ns.UI.Options.Hide()
    if optionsFrame then
        optionsFrame:Hide()
    end
end
