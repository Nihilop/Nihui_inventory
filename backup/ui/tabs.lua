-- ui/tabs.lua - Reusable tab system component
local addonName, ns = ...

ns.UI.Tabs = {}

-- Create a tab group (horizontal tabs)
-- Usage: ns.UI.Tabs.Create(parent, tabs, options)
-- tabs = { {id="tab1", label="Tab 1", onSelect=func}, ... }
function ns.UI.Tabs.Create(parent, tabs, options)
    options = options or {}
    local position = options.position or "BOTTOM" -- BOTTOM, TOP, LEFT, RIGHT
    local orientation = (position == "TOP" or position == "BOTTOM") and "HORIZONTAL" or "VERTICAL"
    local buttonSize = options.buttonSize or {width = 100, height = 32}
    local gap = options.gap or 2

    local tabGroup = CreateFrame("Frame", nil, parent)
    tabGroup.buttons = {}
    tabGroup.activeTab = nil
    tabGroup.tabs = tabs

    -- Calculate total size based on orientation
    if orientation == "HORIZONTAL" then
        local totalWidth = (#tabs * buttonSize.width) + ((#tabs - 1) * gap)
        tabGroup:SetSize(totalWidth, buttonSize.height)
    else
        local totalHeight = (#tabs * buttonSize.height) + ((#tabs - 1) * gap)
        tabGroup:SetSize(buttonSize.width, totalHeight)
    end

    -- Create tab buttons
    for i, tab in ipairs(tabs) do
        local button = CreateFrame("Button", nil, tabGroup, "BackdropTemplate")
        button:SetSize(buttonSize.width, buttonSize.height)

        -- Position button
        if i == 1 then
            if position == "BOTTOM" then
                button:SetPoint("BOTTOMLEFT", tabGroup, "BOTTOMLEFT", 0, 0)
            elseif position == "TOP" then
                button:SetPoint("TOPLEFT", tabGroup, "TOPLEFT", 0, 0)
            elseif position == "LEFT" then
                button:SetPoint("TOPLEFT", tabGroup, "TOPLEFT", 0, 0)
            elseif position == "RIGHT" then
                button:SetPoint("TOPRIGHT", tabGroup, "TOPRIGHT", 0, 0)
            end
        else
            local prevButton = tabGroup.buttons[i - 1]
            if orientation == "HORIZONTAL" then
                button:SetPoint("LEFT", prevButton, "RIGHT", gap, 0)
            else
                button:SetPoint("TOP", prevButton, "BOTTOM", 0, -gap)
            end
        end

        -- Backdrop
        local borderConfig = ns.db.border or ns.defaults.border
        button:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = borderConfig.enabled and borderConfig.texture or nil,
            edgeSize = borderConfig.edgeSize or 16,
            tile = false,
            insets = {left = 8, right = 8, top = 8, bottom = 8}
        })

        -- Inactive state (default)
        button:SetBackdropColor(0.1, 0.1, 0.1, 0.6)
        if borderConfig.enabled then
            button:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
        end

        -- Label
        local label = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("CENTER")
        label:SetText(tab.label)
        button.label = label

        -- Icon (optional)
        if tab.icon then
            local icon = button:CreateTexture(nil, "ARTWORK")
            icon:SetSize(16, 16)
            icon:SetPoint("LEFT", button, "LEFT", 10, 0)

            if tab.iconType == "atlas" then
                icon:SetAtlas(tab.icon)
            else
                icon:SetTexture(tab.icon)
            end

            button.icon = icon
            -- Adjust label position if icon exists
            label:ClearAllPoints()
            label:SetPoint("LEFT", icon, "RIGHT", 5, 0)
        end

        -- Highlight
        button:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")

        -- Store tab data
        button.tabData = tab
        button.tabIndex = i

        -- Click handler
        button:SetScript("OnClick", function(self)
            tabGroup:SelectTab(self.tabIndex)
        end)

        table.insert(tabGroup.buttons, button)
    end

    -- Select tab function
    function tabGroup:SelectTab(index)
        if not self.buttons[index] then return end

        -- Deactivate all tabs
        for i, btn in ipairs(self.buttons) do
            btn:SetBackdropColor(0.1, 0.1, 0.1, 0.6)
            if borderConfig.enabled then
                btn:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
            end
            btn.label:SetTextColor(0.7, 0.7, 0.7)
        end

        -- Activate selected tab
        local selectedBtn = self.buttons[index]
        selectedBtn:SetBackdropColor(0.2, 0.2, 0.2, 0.9)
        if borderConfig.enabled then
            selectedBtn:SetBackdropBorderColor(0.58, 0.51, 0.79, 1) -- Nihui purple
        end
        selectedBtn.label:SetTextColor(1, 1, 1)

        self.activeTab = index

        -- Callback
        if selectedBtn.tabData.onSelect then
            selectedBtn.tabData.onSelect(selectedBtn.tabData.id, selectedBtn.tabData)
        end
    end

    -- Auto-select first tab
    tabGroup:SelectTab(1)

    return tabGroup
end
