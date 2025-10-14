-- ui/sidebar.lua - Bag sidebar with filter buttons
local addonName, ns = ...

ns.UI.Sidebar = {}

local sidebarFrame = nil
local bagButtons = {}
local activeBag = nil -- nil = all bags, bagID = filter this bag

-- Button groups for dynamic repositioning
local BUTTON_GROUPS = {
    primary = {}, -- Bags button or bank tabs
    utility = {}  -- Settings, Repair, Sell, Sort
}
local currentView = "bags" -- "bags", "settings", "bank_tabs"
local merchantEventFrame = nil
local bankTabButtons = {} -- Guild bank tab buttons (1-8)

-- Reposition all visible buttons dynamically (remove gaps)
function ns.UI.Sidebar.RepositionButtons()
    if not sidebarFrame then return end

    local buttonSize = 40
    local gap = 5
    local groupGap = 20 -- Gap between button groups
    local yOffset = -10

    -- Collect all visible buttons in order
    local visibleButtons = {}

    -- Primary buttons (bags)
    for _, btn in ipairs(BUTTON_GROUPS.primary) do
        if btn:IsShown() then
            table.insert(visibleButtons, {button = btn, group = "primary"})
        end
    end

    -- Add group gap if we have utility buttons coming
    local hasVisibleUtility = false
    for _, btn in ipairs(BUTTON_GROUPS.utility) do
        if btn:IsShown() then
            hasVisibleUtility = true
            break
        end
    end

    -- Utility buttons (settings, repair, sell, sort)
    for _, btn in ipairs(BUTTON_GROUPS.utility) do
        if btn:IsShown() then
            table.insert(visibleButtons, {button = btn, group = "utility"})
        end
    end

    -- Reposition all visible buttons
    local previousGroup = nil
    for i, data in ipairs(visibleButtons) do
        local btn = data.button
        btn:ClearAllPoints()

        if i == 1 then
            -- First button
            btn:SetPoint("TOPRIGHT", sidebarFrame, "TOPRIGHT", 0, yOffset)
        else
            local prevBtn = visibleButtons[i - 1].button
            local extraGap = 0

            -- Add extra gap between groups
            if previousGroup and previousGroup ~= data.group then
                extraGap = groupGap
            end

            btn:SetPoint("TOPRIGHT", prevBtn, "BOTTOMRIGHT", 0, -(gap + extraGap))
        end

        previousGroup = data.group
    end

    -- Update sidebar height to fit all buttons
    local totalHeight = (#visibleButtons * buttonSize) + ((#visibleButtons - 1) * gap)
    if hasVisibleUtility and #BUTTON_GROUPS.primary > 0 and #BUTTON_GROUPS.utility > 0 then
        totalHeight = totalHeight + groupGap
    end
    totalHeight = totalHeight + math.abs(yOffset) + 10
    sidebarFrame:SetHeight(totalHeight)
end

-- Show/hide buttons dynamically
function ns.UI.Sidebar.SetButtonVisible(buttonKey, visible)
    local btn = bagButtons[buttonKey]
    if not btn then return end

    if visible then
        btn:Show()
    else
        btn:Hide()
    end

    -- Reposition all buttons
    ns.UI.Sidebar.RepositionButtons()
end

-- Create the bag sidebar (outside frame on the left)
function ns.UI.Sidebar.Create(parent)
    if sidebarFrame then
        return sidebarFrame
    end

    -- Sidebar container (positioned outside content frame to the left - collé)
    local sidebar = CreateFrame("Frame", "NihuiIVSidebar", parent)
    sidebar:SetSize(50, 400)
    sidebar:SetPoint("RIGHT", parent, "LEFT", 0, 0) -- Collé au content frame (offset 0)
    sidebar:SetFrameLevel(parent:GetFrameLevel() + 1)

    sidebarFrame = sidebar

    -- Create bag buttons
    ns.UI.Sidebar.CreateBagButtons(sidebar)

    -- Initial repositioning
    ns.UI.Sidebar.RepositionButtons()

    return sidebar
end

-- Create individual bag buttons (vertical stack)
function ns.UI.Sidebar.CreateBagButtons(parent)
    local buttonSize = 40

    -- Single "Bags" button (replaces all individual bag buttons)
    local bagsButton = CreateFrame("Button", "NihuiIVBagsButton", parent, "BackdropTemplate")
    bagsButton:SetSize(buttonSize, buttonSize)

    -- Background with gradient (right opaque → left transparent)
    local bg = bagsButton:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    bg:SetGradient("HORIZONTAL",
        CreateColor(0, 0, 0, 0),      -- Left: transparent
        CreateColor(0.1, 0.1, 0.1, 0.8) -- Right: opaque
    )
    bagsButton.bg = bg

    -- Border
    bagsButton:SetBackdrop({
        edgeFile = "Interface\\Buttons\\UI-SlotBackground",
        edgeSize = 1,
        insets = {left = 0, right = 0, top = 0, bottom = 0}
    })
    bagsButton:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

    -- Bags icon (atlas)
    local icon = bagsButton:CreateTexture(nil, "ARTWORK")
    icon:SetSize(buttonSize - 8, buttonSize - 8)
    icon:SetPoint("CENTER")
    icon:SetAtlas("bag-main")
    bagsButton.icon = icon

    bagsButton:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")

    -- Active border (always visible since it's the bags view)
    bagsButton.activeBorder = bagsButton:CreateTexture(nil, "OVERLAY")
    bagsButton.activeBorder:SetAllPoints()
    bagsButton.activeBorder:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    bagsButton.activeBorder:SetBlendMode("ADD")
    bagsButton.activeBorder:SetVertexColor(0.5, 0.3, 1, 0.8)
    bagsButton.activeBorder:Show() -- Active by default

    bagsButton:SetScript("OnClick", function(self)
        ns.UI.Sidebar.SwitchView("bags")
    end)

    bagsButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Bags")
        GameTooltip:AddLine("Click to show all bags", 1, 1, 1)
        GameTooltip:Show()
    end)

    bagsButton:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    bagButtons["bags"] = bagsButton
    table.insert(BUTTON_GROUPS.primary, bagsButton)

    -- ========================================
    -- UTILITY BUTTONS (Settings, Repair, Sell)
    -- ========================================

    -- Settings button
    local settingsButton = CreateFrame("Button", "NihuiIVSettingsButton", parent, "BackdropTemplate")
    settingsButton:SetSize(buttonSize, buttonSize)

    -- Background with gradient
    local settingsBg = settingsButton:CreateTexture(nil, "BACKGROUND")
    settingsBg:SetAllPoints()
    settingsBg:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    settingsBg:SetGradient("HORIZONTAL",
        CreateColor(0, 0, 0, 0),      -- Left: transparent
        CreateColor(0.1, 0.1, 0.1, 0.8) -- Right: opaque
    )

    -- Border
    settingsButton:SetBackdrop({
        edgeFile = "Interface\\Buttons\\UI-SlotBackground",
        edgeSize = 1,
        insets = {left = 0, right = 0, top = 0, bottom = 0}
    })
    settingsButton:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

    -- Settings icon (atlas)
    local settingsIcon = settingsButton:CreateTexture(nil, "ARTWORK")
    settingsIcon:SetSize(buttonSize - 8, buttonSize - 8)
    settingsIcon:SetPoint("CENTER")
    settingsIcon:SetAtlas("Crosshair_interact_48")
    settingsButton.icon = settingsIcon

    settingsButton:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")

    -- Add active border (hidden by default)
    settingsButton.activeBorder = settingsButton:CreateTexture(nil, "OVERLAY")
    settingsButton.activeBorder:SetAllPoints()
    settingsButton.activeBorder:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    settingsButton.activeBorder:SetBlendMode("ADD")
    settingsButton.activeBorder:SetVertexColor(0.5, 0.3, 1, 0.8)
    settingsButton.activeBorder:Hide()

    settingsButton:SetScript("OnClick", function(self)
        ns.UI.Sidebar.SwitchView("settings")
    end)

    settingsButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Settings")
        GameTooltip:AddLine("Click to open settings", 1, 1, 1)
        GameTooltip:Show()
    end)

    settingsButton:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    bagButtons["settings"] = settingsButton
    table.insert(BUTTON_GROUPS.utility, settingsButton)

    -- Repair button
    local repairButton = CreateFrame("Button", "NihuiIVRepairButton", parent, "BackdropTemplate")
    repairButton:SetSize(buttonSize, buttonSize)

    -- Background with gradient
    local repairBg = repairButton:CreateTexture(nil, "BACKGROUND")
    repairBg:SetAllPoints()
    repairBg:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    repairBg:SetGradient("HORIZONTAL",
        CreateColor(0, 0, 0, 0),      -- Left: transparent
        CreateColor(0.1, 0.1, 0.1, 0.8) -- Right: opaque
    )

    -- Border
    repairButton:SetBackdrop({
        edgeFile = "Interface\\Buttons\\UI-SlotBackground",
        edgeSize = 1,
        insets = {left = 0, right = 0, top = 0, bottom = 0}
    })
    repairButton:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

    -- Repair icon (atlas)
    local repairIcon = repairButton:CreateTexture(nil, "ARTWORK")
    repairIcon:SetSize(buttonSize - 8, buttonSize - 8)
    repairIcon:SetPoint("CENTER")
    repairIcon:SetAtlas("Crosshair_Repair_48")
    repairButton.icon = repairIcon

    repairButton:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")

    repairButton:SetScript("OnClick", function(self)
        -- Repair all items
        if CanMerchantRepair() then
            local repairCost, canRepair = GetRepairAllCost()

            if canRepair and repairCost > 0 then
                -- Try guild repair first
                local usedGuildRepair = false
                if CanGuildBankRepair() then
                    RepairAllItems(1) -- 1 = use guild funds
                    usedGuildRepair = true
                else
                    RepairAllItems(0) -- 0 = use player funds
                end

                local gold = math.floor(repairCost / 10000)
                local silver = math.floor((repairCost % 10000) / 100)
                local copper = repairCost % 100

                local costString = string.format("%dg %ds %dc", gold, silver, copper)

                if usedGuildRepair then
                    ns:Print("Repaired all items using guild funds (" .. costString .. ")")
                else
                    ns:Print("Repaired all items for " .. costString)
                end
            else
                ns:Print("Nothing to repair")
            end
        else
            ns:Print("Merchant cannot repair")
        end
    end)

    repairButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Repair All")
        GameTooltip:AddLine("Click to repair all items", 1, 1, 1)
        GameTooltip:Show()
    end)

    repairButton:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    bagButtons["repair"] = repairButton
    table.insert(BUTTON_GROUPS.utility, repairButton)

    -- Sell button
    local sellButton = CreateFrame("Button", "NihuiIVSellButton", parent, "BackdropTemplate")
    sellButton:SetSize(buttonSize, buttonSize)

    -- Background with gradient
    local sellBg = sellButton:CreateTexture(nil, "BACKGROUND")
    sellBg:SetAllPoints()
    sellBg:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    sellBg:SetGradient("HORIZONTAL",
        CreateColor(0, 0, 0, 0),      -- Left: transparent
        CreateColor(0.1, 0.1, 0.1, 0.8) -- Right: opaque
    )

    -- Border
    sellButton:SetBackdrop({
        edgeFile = "Interface\\Buttons\\UI-SlotBackground",
        edgeSize = 1,
        insets = {left = 0, right = 0, top = 0, bottom = 0}
    })
    sellButton:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

    -- Sell icon (atlas - money bag)
    local sellIcon = sellButton:CreateTexture(nil, "ARTWORK")
    sellIcon:SetSize(buttonSize - 8, buttonSize - 8)
    sellIcon:SetPoint("CENTER")
    sellIcon:SetAtlas("Crosshair_pickup_48")
    sellButton.icon = sellIcon

    sellButton:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")

    sellButton:SetScript("OnClick", function(self)
        -- Sell all junk items
        local totalValue = 0
        local itemsSold = 0

        -- Iterate through all bags
        for bagID = 0, 4 do
            local numSlots = C_Container.GetContainerNumSlots(bagID)

            if numSlots then
                for slotID = 1, numSlots do
                    local info = C_Container.GetContainerItemInfo(bagID, slotID)

                    if info and info.quality == Enum.ItemQuality.Poor then
                        -- Get item value
                        local itemLink = C_Container.GetContainerItemLink(bagID, slotID)
                        if itemLink then
                            local vendorPrice = select(11, C_Item.GetItemInfo(itemLink))
                            if vendorPrice and vendorPrice > 0 then
                                totalValue = totalValue + (vendorPrice * info.stackCount)
                                itemsSold = itemsSold + 1
                            end
                        end

                        -- Sell item
                        C_Container.UseContainerItem(bagID, slotID)
                    end
                end
            end
        end

        if itemsSold > 0 then
            local gold = math.floor(totalValue / 10000)
            local silver = math.floor((totalValue % 10000) / 100)
            local copper = totalValue % 100

            ns:Print(string.format("Sold %d junk items for %dg %ds %dc", itemsSold, gold, silver, copper))
        else
            ns:Print("No junk items to sell")
        end
    end)

    sellButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Sell Junk")
        GameTooltip:AddLine("Click to sell all junk items", 1, 1, 1)
        GameTooltip:Show()
    end)

    sellButton:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    bagButtons["sell"] = sellButton
    table.insert(BUTTON_GROUPS.utility, sellButton)

    -- Sort button
    local sortButton = CreateFrame("Button", "NihuiIVSortButton", parent, "BackdropTemplate")
    sortButton:SetSize(buttonSize, buttonSize)

    -- Background with gradient
    local sortBg = sortButton:CreateTexture(nil, "BACKGROUND")
    sortBg:SetAllPoints()
    sortBg:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    sortBg:SetGradient("HORIZONTAL",
        CreateColor(0, 0, 0, 0),      -- Left: transparent
        CreateColor(0.1, 0.1, 0.1, 0.8) -- Right: opaque
    )

    -- Border
    sortButton:SetBackdrop({
        edgeFile = "Interface\\Buttons\\UI-SlotBackground",
        edgeSize = 1,
        insets = {left = 0, right = 0, top = 0, bottom = 0}
    })
    sortButton:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

    -- Sort icon (atlas - refresh button)
    local sortIcon = sortButton:CreateTexture(nil, "ARTWORK")
    sortIcon:SetSize(buttonSize - 8, buttonSize - 8)
    sortIcon:SetPoint("CENTER")
    sortIcon:SetAtlas("UI-RefreshButton")
    sortButton.icon = sortIcon

    sortButton:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")

    sortButton:SetScript("OnClick", function(self)
        if ns.Modules.Sort and ns.Modules.Sort.SortInventory then
            ns.Modules.Sort.SortInventory()
        else
            C_Container.SortBags()
            ns:Print("Sorting bags...")
        end
    end)

    sortButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Sort Bags")
        GameTooltip:AddLine("Click to sort all bags", 1, 1, 1)
        GameTooltip:Show()
    end)

    sortButton:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    bagButtons["sort"] = sortButton
    table.insert(BUTTON_GROUPS.utility, sortButton)

    -- Hide repair and sell buttons by default (shown only when merchant is open)
    repairButton:Hide()
    sellButton:Hide()

    -- Create merchant event handler
    if not merchantEventFrame then
        merchantEventFrame = CreateFrame("Frame")
        merchantEventFrame:RegisterEvent("MERCHANT_SHOW")
        merchantEventFrame:RegisterEvent("MERCHANT_CLOSED")

        merchantEventFrame:SetScript("OnEvent", function(self, event)
            if event == "MERCHANT_SHOW" then
                -- Show repair button if merchant can repair
                if CanMerchantRepair() then
                    bagButtons["repair"]:Show()
                end

                -- Always show sell button when merchant is open
                bagButtons["sell"]:Show()

                -- Reposition buttons to remove gaps
                ns.UI.Sidebar.RepositionButtons()

            elseif event == "MERCHANT_CLOSED" then
                -- Hide repair and sell buttons
                bagButtons["repair"]:Hide()
                bagButtons["sell"]:Hide()

                -- Reposition buttons to remove gaps
                ns.UI.Sidebar.RepositionButtons()
            end
        end)
    end
end

-- Filter by bag (simplified - always shows all bags now)
function ns.UI.Sidebar.FilterBag(bagID)
    activeBag = nil -- Always show all bags

    -- Trigger inventory update (no filter)
    if ns.Modules.Inventory and ns.Modules.Inventory.UpdateInventory then
        ns.Modules.Inventory.UpdateInventory(nil)
    end
end

-- Get current active bag filter (always nil = all bags)
function ns.UI.Sidebar.GetActiveBag()
    return nil
end

-- Switch sidebar view (bags, settings, bank_tabs)
function ns.UI.Sidebar.SwitchView(view)
    if view == currentView then return end

    currentView = view

    -- Update button highlights
    for key, btn in pairs(bagButtons) do
        if btn.activeBorder then
            btn.activeBorder:Hide()
        end
    end

    -- Show correct view
    local mainFrame = _G["NihuiIVFrame"]
    if not mainFrame then return end

    if view == "bags" then
        -- Show bags view
        if bagButtons["bags"] and bagButtons["bags"].activeBorder then
            bagButtons["bags"].activeBorder:Show()
        end

        -- Show search box
        if mainFrame.searchBox then
            mainFrame.searchBox:GetParent():Show() -- Show searchContainer
        end

        -- Hide options panel
        if mainFrame.optionsPanel then
            mainFrame.optionsPanel:Hide()
        end

        -- Show item grid
        if mainFrame.itemGrid then
            mainFrame.itemGrid:Show()
        end

        -- Update inventory
        if ns.Modules.Inventory and ns.Modules.Inventory.UpdateInventory then
            ns.Modules.Inventory.UpdateInventory()
        end

    elseif view == "settings" then
        -- Show settings view
        if bagButtons["settings"] and bagButtons["settings"].activeBorder then
            bagButtons["settings"].activeBorder:Show()
        end

        -- Hide search box (not needed in options)
        if mainFrame.searchBox then
            mainFrame.searchBox:GetParent():Hide() -- Hide searchContainer
        end

        -- Hide item grid
        if mainFrame.itemGrid then
            mainFrame.itemGrid:Hide()
        end

        -- Show options panel
        if not mainFrame.optionsPanel then
            mainFrame.optionsPanel = ns.UI.Options.Create(mainFrame.content.body)
            mainFrame.optionsPanel:SetPoint("TOPLEFT", mainFrame.content.body, "TOPLEFT", 10, -10)
            mainFrame.optionsPanel:SetPoint("BOTTOMRIGHT", mainFrame.content.body, "BOTTOMRIGHT", -10, 10)
        end
        mainFrame.optionsPanel:Show()

    elseif view == "bank_tabs" then
        -- TODO: Show bank tabs view
    end
end

-- Get current view
function ns.UI.Sidebar.GetCurrentView()
    return currentView
end

-- Create bank tab buttons (1-8) for guild bank
function ns.UI.Sidebar.CreateBankTabs()
    if not sidebarFrame then return end

    -- Clear existing bank tab buttons
    for _, btn in ipairs(bankTabButtons) do
        btn:Hide()
        btn:SetParent(nil)
    end
    wipe(bankTabButtons)

    -- Clear primary group (remove bags button)
    wipe(BUTTON_GROUPS.primary)

    local buttonSize = 40

    -- Create 8 bank tab buttons
    for i = 1, 8 do
        local tabButton = CreateFrame("Button", "NihuiIVBankTab" .. i, sidebarFrame, "BackdropTemplate")
        tabButton:SetSize(buttonSize, buttonSize)

        -- Background with gradient
        local bg = tabButton:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
        bg:SetGradient("HORIZONTAL",
            CreateColor(0, 0, 0, 0),
            CreateColor(0.1, 0.1, 0.1, 0.8)
        )

        -- Border
        tabButton:SetBackdrop({
            edgeFile = "Interface\\Buttons\\UI-SlotBackground",
            edgeSize = 1,
            insets = {left = 0, right = 0, top = 0, bottom = 0}
        })
        tabButton:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

        -- Tab number text
        local tabText = tabButton:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        tabText:SetPoint("CENTER")
        tabText:SetText(tostring(i))

        tabButton:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")

        -- Active border
        tabButton.activeBorder = tabButton:CreateTexture(nil, "OVERLAY")
        tabButton.activeBorder:SetAllPoints()
        tabButton.activeBorder:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
        tabButton.activeBorder:SetBlendMode("ADD")
        tabButton.activeBorder:SetVertexColor(0.5, 0.3, 1, 0.8)
        tabButton.activeBorder:Hide()

        -- Click handler
        tabButton:SetScript("OnClick", function(self)
            ns.UI.Sidebar.SelectBankTab(i)
        end)

        -- Tooltip
        tabButton:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Bank Tab " .. i)
            GameTooltip:Show()
        end)

        tabButton:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
        end)

        table.insert(bankTabButtons, tabButton)
        table.insert(BUTTON_GROUPS.primary, tabButton)
    end

    -- Reposition all buttons
    ns.UI.Sidebar.RepositionButtons()
end

-- Select a bank tab
function ns.UI.Sidebar.SelectBankTab(tabIndex)
    -- Update highlights
    for i, btn in ipairs(bankTabButtons) do
        if btn.activeBorder then
            if i == tabIndex then
                btn.activeBorder:Show()
            else
                btn.activeBorder:Hide()
            end
        end
    end

    -- Update bank display
    if ns.Modules.Bank and ns.Modules.Bank.SelectBankTab then
        ns.Modules.Bank.SelectBankTab(tabIndex)
    end
end

-- Hide bank tabs and restore bags button
function ns.UI.Sidebar.HideBankTabs()
    -- Hide bank tab buttons
    for _, btn in ipairs(bankTabButtons) do
        btn:Hide()
    end

    -- Clear primary group
    wipe(BUTTON_GROUPS.primary)

    -- Restore bags button to primary group
    if bagButtons["bags"] then
        table.insert(BUTTON_GROUPS.primary, bagButtons["bags"])
        bagButtons["bags"]:Show()
    end

    -- Reposition
    ns.UI.Sidebar.RepositionButtons()
end

-- Show bank tabs (and hide bags button)
function ns.UI.Sidebar.ShowBankTabs()
    -- Hide bags button
    if bagButtons["bags"] then
        bagButtons["bags"]:Hide()
    end

    -- Create bank tabs if not exists
    if #bankTabButtons == 0 then
        ns.UI.Sidebar.CreateBankTabs()
    else
        -- Clear primary group and add bank tabs
        wipe(BUTTON_GROUPS.primary)
        for _, btn in ipairs(bankTabButtons) do
            btn:Show()
            table.insert(BUTTON_GROUPS.primary, btn)
        end
    end

    -- Select tab 1 by default
    ns.UI.Sidebar.SelectBankTab(1)

    -- Reposition
    ns.UI.Sidebar.RepositionButtons()
end


