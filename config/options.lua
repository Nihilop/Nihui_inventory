-- config/options.lua - Options component (intégré dans les frames)
local addonName, ns = ...

ns.Config = ns.Config or {}
ns.Config.Options = {}

-- ========================================
-- HELPER: Create Section Header
-- ========================================
local function CreateSectionHeader(parent, text)
    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetText(text)
    header:SetTextColor(0.58, 0.51, 0.79, 1)  -- Nihui purple
    return header
end

-- ========================================
-- HELPER: Create Description Text
-- ========================================
local function CreateDescription(parent, text, width)
    local desc = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    desc:SetText(text)
    desc:SetJustifyH("LEFT")
    desc:SetWordWrap(true)
    desc:SetWidth(width or 400)
    desc:SetTextColor(0.7, 0.7, 0.7, 1)
    return desc
end

-- ========================================
-- HELPER: Create Toggle Button (Checkbox)
-- ========================================
local function CreateToggle(parent, label, description, currentValue, onChange)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(400, 50)

    -- Checkbox button
    local checkbox = CreateFrame("CheckButton", nil, container, "UICheckButtonTemplate")
    checkbox:SetSize(24, 24)
    checkbox:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -5)
    checkbox:SetChecked(currentValue)

    -- Label
    local labelText = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    labelText:SetPoint("LEFT", checkbox, "RIGHT", 8, 0)
    labelText:SetText(label)

    -- Description (smaller, below)
    local descText = container:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    descText:SetPoint("TOPLEFT", checkbox, "BOTTOMLEFT", 32, -4)
    descText:SetText(description)
    descText:SetTextColor(0.7, 0.7, 0.7, 1)
    descText:SetJustifyH("LEFT")
    descText:SetWordWrap(true)
    descText:SetWidth(360)

    -- Checkbox handler
    checkbox:SetScript("OnClick", function(self)
        local isChecked = self:GetChecked()
        if onChange then
            onChange(isChecked)
        end
    end)

    container.checkbox = checkbox
    container.label = labelText
    container.description = descText

    return container
end

-- ========================================
-- HELPER: Create Dropdown Menu
-- ========================================
local function CreateDropdown(parent, label, description, options, currentValue, onChange)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(400, 80)

    -- Label
    local labelText = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    labelText:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
    labelText:SetText(label)

    -- Description
    if description then
        local descText = container:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        descText:SetPoint("TOPLEFT", labelText, "BOTTOMLEFT", 0, -4)
        descText:SetText(description)
        descText:SetTextColor(0.7, 0.7, 0.7, 1)
        descText:SetJustifyH("LEFT")
        descText:SetWordWrap(true)
        descText:SetWidth(360)
    end

    -- Dropdown button
    local dropdown = CreateFrame("Frame", nil, container, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", labelText, "BOTTOMLEFT", -15, description and -30 or -10)

    -- Initialize dropdown
    UIDropDownMenu_SetWidth(dropdown, 200)
    UIDropDownMenu_Initialize(dropdown, function(self, level)
        for _, option in ipairs(options) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = option.label
            info.value = option.value
            info.func = function()
                UIDropDownMenu_SetSelectedValue(dropdown, option.value)
                if onChange then
                    onChange(option.value)
                end
            end
            info.checked = (option.value == currentValue)
            UIDropDownMenu_AddButton(info)
        end
    end)

    -- Set initial value
    UIDropDownMenu_SetSelectedValue(dropdown, currentValue)

    container.dropdown = dropdown
    return container
end

-- ========================================
-- HELPER: Create Slider
-- ========================================
local function CreateSlider(parent, label, description, min, max, step, currentValue, onChange)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(400, 80)

    -- Label
    local labelText = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    labelText:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
    labelText:SetText(label)

    -- Description
    if description then
        local descText = container:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        descText:SetPoint("TOPLEFT", labelText, "BOTTOMLEFT", 0, -4)
        descText:SetText(description)
        descText:SetTextColor(0.7, 0.7, 0.7, 1)
        descText:SetJustifyH("LEFT")
        descText:SetWordWrap(true)
        descText:SetWidth(360)
    end

    -- Slider
    local slider = CreateFrame("Slider", nil, container, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", labelText, "BOTTOMLEFT", 10, description and -35 or -15)
    slider:SetMinMaxValues(min, max)
    slider:SetValueStep(step)
    slider:SetValue(currentValue)
    slider:SetWidth(300)
    slider:SetObeyStepOnDrag(true)

    -- Value label (shows current value)
    local valueLabel = container:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    valueLabel:SetPoint("LEFT", slider, "RIGHT", 10, 0)
    valueLabel:SetText(tostring(currentValue))

    -- Update value label on change
    slider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value + 0.5) -- Round to nearest integer
        valueLabel:SetText(tostring(value))
        if onChange then
            onChange(value)
        end
    end)

    container.slider = slider
    container.valueLabel = valueLabel
    return container
end

-- ========================================
-- HELPER: Create Radio Button Group
-- ========================================
local function CreateRadioGroup(parent, label, options, currentValue, onChange)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(400, 30 + (#options * 30))

    -- Label
    local labelText = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    labelText:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
    labelText:SetText(label)

    -- Radio buttons
    local radioButtons = {}
    for i, option in ipairs(options) do
        local radio = CreateFrame("CheckButton", nil, container, "UIRadioButtonTemplate")
        radio:SetSize(20, 20)

        if i == 1 then
            radio:SetPoint("TOPLEFT", labelText, "BOTTOMLEFT", 0, -8)
        else
            radio:SetPoint("TOPLEFT", radioButtons[i - 1], "BOTTOMLEFT", 0, -10)
        end

        radio:SetChecked(option.value == currentValue)

        -- Label for radio
        local radioLabel = container:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        radioLabel:SetPoint("LEFT", radio, "RIGHT", 8, 0)
        radioLabel:SetText(option.label)

        -- Click handler
        radio:SetScript("OnClick", function(self)
            -- Uncheck all others
            for _, btn in ipairs(radioButtons) do
                btn:SetChecked(false)
            end

            -- Check this one
            self:SetChecked(true)

            -- Callback
            if onChange then
                onChange(option.value)
            end
        end)

        radio.option = option
        table.insert(radioButtons, radio)
    end

    container.radioButtons = radioButtons
    return container
end

-- ========================================
-- CREATE SIDEBAR (Vertical Tabs)
-- ========================================
local function CreateSidebar(parent, tabs, onTabChange)
    local sidebar = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    -- IMPORTANT: Use SetAllPoints to match parent size exactly (fixes overflow)
    sidebar:SetWidth(150)
    sidebar:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    sidebar:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
    sidebar:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    })
    sidebar:SetBackdropColor(0.02, 0.02, 0.02, 0.7)  -- Plus transparent (0.7 au lieu de 0.95)

    -- Title
    local title = sidebar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", sidebar, "TOP", 0, -20)
    title:SetText("Settings")
    title:SetTextColor(0.58, 0.51, 0.79, 1)  -- Nihui purple

    -- Tab buttons
    local tabButtons = {}
    for i, tab in ipairs(tabs) do
        local btn = CreateFrame("Button", nil, sidebar, "BackdropTemplate")
        btn:SetSize(130, 40)

        if i == 1 then
            btn:SetPoint("TOP", title, "BOTTOM", 0, -20)
        else
            btn:SetPoint("TOP", tabButtons[i - 1], "BOTTOM", 0, -5)
        end

        btn:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = false,
            edgeSize = 12,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        btn:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
        btn:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

        -- Tab label
        local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("CENTER", btn, "CENTER", 0, 0)
        label:SetText(tab.label)

        -- Click handler
        btn:SetScript("OnClick", function(self)
            -- Deselect all tabs
            for _, tabBtn in ipairs(tabButtons) do
                tabBtn:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
                tabBtn:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
                tabBtn.label:SetTextColor(1, 1, 1, 1)
            end

            -- Select this tab
            self:SetBackdropColor(0.58, 0.51, 0.79, 0.3)  -- Nihui purple
            self:SetBackdropBorderColor(0.58, 0.51, 0.79, 1)
            self.label:SetTextColor(0.58, 0.51, 0.79, 1)

            -- Callback
            if onTabChange then
                onTabChange(tab.id)
            end
        end)

        -- Hover effect
        btn:SetScript("OnEnter", function(self)
            if self:GetBackdropColor() ~= 0.58 then
                self:SetBackdropColor(0.15, 0.15, 0.15, 0.9)
            end
        end)

        btn:SetScript("OnLeave", function(self)
            if self:GetBackdropColor() ~= 0.58 then
                self:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
            end
        end)

        btn.label = label
        btn.tab = tab
        table.insert(tabButtons, btn)

        -- Select first tab by default
        if i == 1 then
            btn:SetBackdropColor(0.58, 0.51, 0.79, 0.3)
            btn:SetBackdropBorderColor(0.58, 0.51, 0.79, 1)
            btn.label:SetTextColor(0.58, 0.51, 0.79, 1)
        end
    end

    sidebar.tabs = tabButtons
    return sidebar
end

-- ========================================
-- CREATE BACKPACK OPTIONS PANEL
-- ========================================
local function CreateBackpackOptionsPanel(parent)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetAllPoints(parent)

    -- Scrollable content
    local scrollFrame = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -10)
    scrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -30, 10)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(scrollFrame:GetWidth() - 10, 850) -- Increased from 750 to 850 for icon size slider
    scrollFrame:SetScrollChild(content)

    local yOffset = 0

    -- Section: View Mode
    local viewSection = CreateSectionHeader(content, "View Mode")
    viewSection:SetPoint("TOPLEFT", content, "TOPLEFT", 0, yOffset)
    yOffset = yOffset - 30

    local viewDesc = CreateDescription(content, "Choose how items are displayed in your backpack.")
    viewDesc:SetPoint("TOPLEFT", content, "TOPLEFT", 0, yOffset)
    yOffset = yOffset - 40

    local viewRadio = CreateRadioGroup(
        content,
        "Display Mode:",
        {
            { label = "Category View (organized by type)", value = "category" },
            { label = "All Items View (grid of all items)", value = "all" }
        },
        ns.db and ns.db.backpackViewMode or "category",
        function(value)
            ns.db.backpackViewMode = value
            ns:Print("Backpack view set to: " .. (value == "category" and "Category" or "All Items"))

            -- Apply immediately
            if ns.Layouts.Backpack and ns.Layouts.Backpack.SetViewMode then
                ns.Layouts.Backpack.SetViewMode(value)
            end
        end
    )
    viewRadio:SetPoint("TOPLEFT", content, "TOPLEFT", 0, yOffset)
    yOffset = yOffset - 100

    -- Section: UI Settings
    local uiSection = CreateSectionHeader(content, "UI Settings")
    uiSection:SetPoint("TOPLEFT", content, "TOPLEFT", 0, yOffset)
    yOffset = yOffset - 30

    local uiDesc = CreateDescription(content, "Customize the appearance of your backpack.")
    uiDesc:SetPoint("TOPLEFT", content, "TOPLEFT", 0, yOffset)
    yOffset = yOffset - 40

    local emptySlotToggle = CreateToggle(
        content,
        "Show Empty Slot Stack",
        "Display a single icon representing all empty slots.",
        ns.db and ns.db.backpackShowEmptySlots ~= false or true,
        function(isChecked)
            ns.db.backpackShowEmptySlots = isChecked
            ns:Print("Backpack empty slot stack " .. (isChecked and "shown" or "hidden"))

            -- Refresh backpack (use RefreshItems, not Refresh)
            if ns.Layouts.Backpack and ns.Layouts.Backpack.RefreshItems then
                ns.Layouts.Backpack.RefreshItems()
            end
        end
    )
    emptySlotToggle:SetPoint("TOPLEFT", content, "TOPLEFT", 0, yOffset)
    yOffset = yOffset - 70

    local bigHeaderToggle = CreateToggle(
        content,
        "Show Big Header",
        "Display the decorative faction header at the top of the frame.",
        ns.db and ns.db.showBigHeader ~= false or true,
        function(isChecked)
            ns.db.showBigHeader = isChecked
            ns:Print("Big header " .. (isChecked and "shown" or "hidden"))

            -- Update header visibility immediately (direct refresh)
            if ns.Layouts.Backpack and ns.Layouts.Backpack.UpdateBigHeaderVisibility then
                ns.Layouts.Backpack.UpdateBigHeaderVisibility()
            end
        end
    )
    bigHeaderToggle:SetPoint("TOPLEFT", content, "TOPLEFT", 0, yOffset)
    yOffset = yOffset - 70

    local iconSizeSlider = CreateSlider(
        content,
        "Icon Size:",
        "Adjust the size of item icons in your backpack (requires /reload).",
        32,  -- min
        64,  -- max
        1,   -- step
        ns.db and ns.db.backpackIconSize or 37,
        function(value)
            ns.db.backpackIconSize = value
            ns:Print("Backpack icon size set to " .. value .. " (type /reload to apply)")
        end
    )
    iconSizeSlider:SetPoint("TOPLEFT", content, "TOPLEFT", 0, yOffset)
    yOffset = yOffset - 90

    -- Section: Sort Settings
    local sortSection = CreateSectionHeader(content, "Auto-Sort Settings")
    sortSection:SetPoint("TOPLEFT", content, "TOPLEFT", 0, yOffset)
    yOffset = yOffset - 30

    local sortDesc = CreateDescription(content, "Configure automatic sorting for your backpack (middle-click in 'All Items' view).")
    sortDesc:SetPoint("TOPLEFT", content, "TOPLEFT", 0, yOffset)
    yOffset = yOffset - 50

    local sortTypeDropdown = CreateDropdown(
        content,
        "Sort Type:",
        "Note: Currently uses WoW's built-in sorting (always same order). Custom sorting types will be implemented in a future update.",
        {
            { label = "WoW Default (current)", value = "quality" },
            { label = "By Name (coming soon)", value = "name" },
            { label = "By Item Level (coming soon)", value = "ilvl" },
            { label = "By Type (coming soon)", value = "type" }
        },
        ns.db and ns.db.sortType or "quality",
        function(value)
            ns.db.sortType = value
            ns:Print("Sort type set to: " .. value .. " (custom sorting coming soon)")
        end
    )
    sortTypeDropdown:SetPoint("TOPLEFT", content, "TOPLEFT", 0, yOffset)
    yOffset = yOffset - 90

    return panel
end

-- ========================================
-- CREATE BANK OPTIONS PANEL
-- ========================================
local function CreateBankOptionsPanel(parent)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetAllPoints(parent)

    -- Scrollable content
    local scrollFrame = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -10)
    scrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -30, 10)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(scrollFrame:GetWidth() - 10, 700) -- Increased from 600 to 700 for icon size slider
    scrollFrame:SetScrollChild(content)

    local yOffset = 0

    -- Section: View Mode
    local viewSection = CreateSectionHeader(content, "View Mode")
    viewSection:SetPoint("TOPLEFT", content, "TOPLEFT", 0, yOffset)
    yOffset = yOffset - 30

    local viewDesc = CreateDescription(content, "Choose how items are displayed in your bank.")
    viewDesc:SetPoint("TOPLEFT", content, "TOPLEFT", 0, yOffset)
    yOffset = yOffset - 40

    local viewRadio = CreateRadioGroup(
        content,
        "Display Mode:",
        {
            { label = "Category View (organized by type)", value = "category" },
            { label = "All Items View (grid of all items)", value = "all" }
        },
        ns.db and ns.db.bankViewMode or "category",
        function(value)
            ns.db.bankViewMode = value
            ns:Print("Bank view set to: " .. (value == "category" and "Category" or "All Items"))

            -- Apply immediately
            if ns.Layouts.Bank and ns.Layouts.Bank.SetViewMode then
                ns.Layouts.Bank.SetViewMode(value)
            end
        end
    )
    viewRadio:SetPoint("TOPLEFT", content, "TOPLEFT", 0, yOffset)
    yOffset = yOffset - 100

    -- Section: UI Settings
    local uiSection = CreateSectionHeader(content, "UI Settings")
    uiSection:SetPoint("TOPLEFT", content, "TOPLEFT", 0, yOffset)
    yOffset = yOffset - 30

    local uiDesc = CreateDescription(content, "Customize the appearance of your bank.")
    uiDesc:SetPoint("TOPLEFT", content, "TOPLEFT", 0, yOffset)
    yOffset = yOffset - 40

    local emptySlotToggle = CreateToggle(
        content,
        "Show Empty Slot Stack",
        "Display a single icon representing all empty slots.",
        ns.db and ns.db.bankShowEmptySlots ~= false or true,
        function(isChecked)
            ns.db.bankShowEmptySlots = isChecked
            ns:Print("Bank empty slot stack " .. (isChecked and "shown" or "hidden"))

            -- Refresh bank to update empty slot display
            if ns.Layouts.Bank and ns.Layouts.Bank.RefreshAll then
                ns.Layouts.Bank.RefreshAll()
            end
        end
    )
    emptySlotToggle:SetPoint("TOPLEFT", content, "TOPLEFT", 0, yOffset)
    yOffset = yOffset - 70

    local bigHeaderToggle = CreateToggle(
        content,
        "Show Big Header",
        "Display the decorative faction header at the top of the frame.",
        ns.db and ns.db.showBigHeader ~= false or true,
        function(isChecked)
            ns.db.showBigHeader = isChecked
            ns:Print("Big header " .. (isChecked and "shown" or "hidden"))

            -- Update header visibility immediately (direct refresh)
            if ns.Layouts.Bank and ns.Layouts.Bank.UpdateBigHeaderVisibility then
                ns.Layouts.Bank.UpdateBigHeaderVisibility()
            end
        end
    )
    bigHeaderToggle:SetPoint("TOPLEFT", content, "TOPLEFT", 0, yOffset)
    yOffset = yOffset - 70

    local iconSizeSlider = CreateSlider(
        content,
        "Icon Size:",
        "Adjust the size of item icons in your bank (requires /reload).",
        32,  -- min
        64,  -- max
        1,   -- step
        ns.db and ns.db.bankIconSize or 37,
        function(value)
            ns.db.bankIconSize = value
            ns:Print("Bank icon size set to " .. value .. " (type /reload to apply)")
        end
    )
    iconSizeSlider:SetPoint("TOPLEFT", content, "TOPLEFT", 0, yOffset)
    yOffset = yOffset - 90

    return panel
end

-- ========================================
-- CREATE OPTIONS VIEW (Component intégrable)
-- ========================================
-- @param parentFrame - Parent frame for the options view
-- @param defaultTab - Default tab to show ("backpack" or "bank")
function ns.Config.Options.CreateView(parentFrame, defaultTab)
    local optionsView = CreateFrame("Frame", nil, parentFrame)
    optionsView:SetAllPoints(parentFrame)
    optionsView:Hide()

    -- Sidebar avec tabs (Backpack / Bank)
    local sidebar = CreateSidebar(
        optionsView,
        {
            { id = "backpack", label = "Backpack" },
            { id = "bank", label = "Bank" }
        },
        function(tabId)
            -- Hide all panels
            if optionsView.backpackPanel then
                optionsView.backpackPanel:Hide()
            end
            if optionsView.bankPanel then
                optionsView.bankPanel:Hide()
            end

            -- Show selected panel
            if tabId == "backpack" then
                optionsView.backpackPanel:Show()
            elseif tabId == "bank" then
                optionsView.bankPanel:Show()
            end
        end
    )

    -- Content area (à droite de la sidebar)
    local contentArea = CreateFrame("Frame", nil, optionsView)
    contentArea:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 10, 0)
    contentArea:SetPoint("BOTTOMRIGHT", optionsView, "BOTTOMRIGHT", 0, 0)

    -- Create panels for each tab
    optionsView.backpackPanel = CreateBackpackOptionsPanel(contentArea)
    optionsView.bankPanel = CreateBankOptionsPanel(contentArea)

    -- Default to "backpack" if not specified
    defaultTab = defaultTab or "backpack"

    -- Show the correct panel based on defaultTab
    if defaultTab == "bank" then
        optionsView.backpackPanel:Hide()
        optionsView.bankPanel:Show()

        -- Select bank tab in sidebar
        if sidebar.tabs and sidebar.tabs[2] then
            local bankTab = sidebar.tabs[2]
            local backpackTab = sidebar.tabs[1]

            -- Deselect backpack tab
            backpackTab:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
            backpackTab:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
            backpackTab.label:SetTextColor(1, 1, 1, 1)

            -- Select bank tab
            bankTab:SetBackdropColor(0.58, 0.51, 0.79, 0.3)
            bankTab:SetBackdropBorderColor(0.58, 0.51, 0.79, 1)
            bankTab.label:SetTextColor(0.58, 0.51, 0.79, 1)
        end
    else
        -- Default: show backpack panel
        optionsView.backpackPanel:Show()
        optionsView.bankPanel:Hide()
    end

    optionsView.sidebar = sidebar
    optionsView.contentArea = contentArea

    return optionsView
end
