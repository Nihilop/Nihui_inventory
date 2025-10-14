-- core/frame.lua - Main inventory frame
local addonName, ns = ...

ns.Core.Frame = {}

local mainFrame = nil

-- Create the main inventory frame
function ns.Core.Frame.Create()
    if mainFrame then
        return mainFrame
    end

    -- Create main frame (wrapper container with background + border)
    local frame = CreateFrame("Frame", "NihuiIVFrame", UIParent, "BackdropTemplate")

    -- Restore saved size or use default
    if ns.db.frameSize and ns.db.frameSize.width then
        frame:SetSize(ns.db.frameSize.width, ns.db.frameSize.height)
    else
        frame:SetSize(560, 600)
    end

    -- Restore saved position or use default
    if ns.db.framePosition and ns.db.framePosition.point then
        frame:SetPoint(
            ns.db.framePosition.point,
            UIParent,
            ns.db.framePosition.relativePoint,
            ns.db.framePosition.xOfs,
            ns.db.framePosition.yOfs
        )
    else
        -- Default position: bottom right (for bags)
        frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -50, 150)
    end
    frame:SetFrameStrata("HIGH")
    frame:SetMovable(true)
    frame:SetResizable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetResizeBounds(400, 400, 1200, 900)

    -- Background and border (like unitframes) on wrapper frame
    local bgConfig = ns.db.background or ns.defaults.background
    local borderConfig = ns.db.border or ns.defaults.border

    -- Background + border on wrapper
    frame:SetBackdrop({
        bgFile = bgConfig.texture,
        edgeFile = borderConfig.enabled and borderConfig.texture or nil,
        edgeSize = borderConfig.edgeSize or 16,
        insets = {left = 12, right = 12, top = 12, bottom = 12} -- Insets to push background inside border
    })

    frame:SetBackdropColor(unpack(bgConfig.color))
    if borderConfig.enabled then
        frame:SetBackdropBorderColor(unpack(borderConfig.color))
    end

    -- Content container (transparent, no backdrop - just for positioning)
    local contentFrame = CreateFrame("Frame", "NihuiIVContent", frame)
    contentFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -12) -- Offset by border size
    contentFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 12)
    frame.content = contentFrame

    -- Glass overlay removed (doesn't look good on large window)
    -- contentFrame.glass = nil

    -- Create bag sidebar (collé au content frame sur la gauche)
    local bagSidebar = ns.UI.Sidebar.Create(contentFrame)
    frame.bagSidebar = bagSidebar

    -- ========================================
    -- HEADER (sticky - not scrollable)
    -- ========================================
    local headerFrame = CreateFrame("Frame", "NihuiIVHeader", contentFrame, "BackdropTemplate")
    headerFrame:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 2, -2)
    headerFrame:SetPoint("TOPRIGHT", contentFrame, "TOPRIGHT", -2, -2)
    headerFrame:SetHeight(80)

    -- Header background (can be different from main)
    headerFrame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground"
    })
    headerFrame:SetBackdropColor(0.05, 0.05, 0.05, 0.7)
    contentFrame.header = headerFrame

    -- Enable dragging from header
    headerFrame:EnableMouse(true)
    headerFrame:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            frame:StartMoving()
        end
    end)
    headerFrame:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            frame:StopMovingOrSizing()

            -- Save position to database
            local point, relativeTo, relativePoint, xOfs, yOfs = frame:GetPoint()
            if not ns.db.framePosition then
                ns.db.framePosition = {}
            end
            ns.db.framePosition.point = point
            ns.db.framePosition.relativePoint = relativePoint
            ns.db.framePosition.xOfs = xOfs
            ns.db.framePosition.yOfs = yOfs
        end
    end)

    -- Title bar (in header)
    local title = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", headerFrame, "TOPLEFT", 20, -12)
    title:SetText("|cff9482c9Inventory|r")
    headerFrame.title = title
    frame.title = title

    -- Count display (in header)
    local count = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    count:SetPoint("TOPRIGHT", headerFrame, "TOPRIGHT", -20, -15)
    count:SetText("0/96")
    headerFrame.count = count
    frame.count = count

    -- Close button (in header - just icon, no default style)
    local closeButton = CreateFrame("Button", nil, headerFrame)
    closeButton:SetSize(20, 20)
    closeButton:SetPoint("TOPRIGHT", headerFrame, "TOPRIGHT", -10, -10)

    -- Icon texture
    local closeIcon = closeButton:CreateTexture(nil, "ARTWORK")
    closeIcon:SetAllPoints()
    closeIcon:SetAtlas("uitools-icon-close")

    -- Highlight texture
    closeButton:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")

    closeButton:SetScript("OnClick", function()
        -- If bank is open, call CloseBankFrame() to trigger proper events (same as ESC)
        if ns.Modules.Bank and ns.Modules.Bank.IsBankOpen() then
            if C_Bank and C_Bank.CloseBankFrame then
                C_Bank.CloseBankFrame()
            else
                CloseBankFrame()
            end
        else
            -- Normal inventory close
            frame:Hide()
        end
    end)

    -- Modern search box (in header)
    local searchContainer = CreateFrame("Frame", nil, headerFrame, "BackdropTemplate")
    searchContainer:SetPoint("TOPLEFT", headerFrame, "TOPLEFT", 15, -45)
    searchContainer:SetPoint("TOPRIGHT", headerFrame, "TOPRIGHT", -15, -45)
    searchContainer:SetHeight(40) -- Increased to compensate for insets

    -- Modern search box style (with same border as content frame)
    local borderConfig = ns.db.border or ns.defaults.border
    searchContainer:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = borderConfig.enabled and borderConfig.texture or nil,
        edgeSize = borderConfig.edgeSize or 16,
        tile = false,
        insets = {left = 12, right = 12, top = 12, bottom = 12}
    })
    searchContainer:SetBackdropColor(0, 0, 0, 0.5)
    if borderConfig.enabled then
        searchContainer:SetBackdropBorderColor(unpack(borderConfig.color))
    end

    local searchBox = CreateFrame("EditBox", "NihuiIVSearchBox", searchContainer)
    searchBox:SetPoint("LEFT", searchContainer, "LEFT", 10, 0)
    searchBox:SetPoint("RIGHT", searchContainer, "RIGHT", -10, 0)
    searchBox:SetHeight(25)
    searchBox:SetFontObject("ChatFontNormal")
    searchBox:SetAutoFocus(false)
    searchBox:SetTextInsets(5, 5, 0, 0)

    -- Placeholder text
    local placeholderText = searchBox:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    placeholderText:SetPoint("LEFT", searchBox, "LEFT", 5, 0)
    placeholderText:SetText("Search...")
    searchBox.placeholder = placeholderText

    searchBox:SetScript("OnTextChanged", function(self)
        local text = self:GetText()

        -- Show/hide placeholder
        if text == "" then
            self.placeholder:Show()
        else
            self.placeholder:Hide()
        end

        if ns.Modules.Inventory and ns.Modules.Inventory.FilterItems then
            ns.Modules.Inventory.FilterItems(text)
        end
    end)

    searchBox:SetScript("OnEditFocusGained", function(self)
        -- No border, so no color change needed
    end)

    searchBox:SetScript("OnEditFocusLost", function(self)
        -- No border, so no color change needed
    end)

    -- Escape key handler to clear focus
    searchBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    headerFrame.searchBox = searchBox
    frame.searchBox = searchBox

    -- ========================================
    -- BODY (scrollable content with ScrollFrame - classic approach)
    -- ========================================
    local bodyFrame = CreateFrame("Frame", "NihuiIVBody", contentFrame)
    bodyFrame:SetPoint("TOPLEFT", headerFrame, "BOTTOMLEFT", 0, 0)
    bodyFrame:SetPoint("BOTTOMRIGHT", contentFrame, "BOTTOMRIGHT", -2, 45 + 2) -- Leave space for footer + padding
    contentFrame.body = bodyFrame

    -- Create ScrollFrame
    local scrollFrame = CreateFrame("ScrollFrame", "NihuiIVScrollFrame", bodyFrame)
    scrollFrame:SetPoint("TOPLEFT", bodyFrame, "TOPLEFT", 10, -10)
    scrollFrame:SetPoint("BOTTOMRIGHT", bodyFrame, "BOTTOMRIGHT", -25, 10) -- Leave space for scrollbar

    -- Scroll child (container for items)
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    local scrollWidth = bodyFrame:GetWidth() - 35 -- Account for scrollbar and padding
    -- Ensure minimum width to prevent layout issues on initial creation
    if not scrollWidth or scrollWidth <= 0 then
        scrollWidth = 500 -- Fallback width
    end
    scrollChild:SetSize(scrollWidth, 1) -- Height will be dynamic
    scrollFrame:SetScrollChild(scrollChild)

    -- Item grid container (inside scroll child)
    local itemGrid = CreateFrame("Frame", "NihuiIVItemGrid", scrollChild)
    itemGrid:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, 0)
    itemGrid:SetSize(scrollWidth, 1) -- Height will be calculated dynamically (width matches scrollChild)
    scrollChild.itemGrid = itemGrid
    bodyFrame.itemGrid = itemGrid
    frame.itemGrid = itemGrid

    -- Store references for resize updates
    frame.scrollChild = scrollChild
    frame.scrollFrame = scrollFrame

    -- Scrollbar (simple custom slider)
    local scrollbar = CreateFrame("Slider", "NihuiIVScrollBar", bodyFrame)
    scrollbar:SetPoint("TOPRIGHT", bodyFrame, "TOPRIGHT", -6, -16)
    scrollbar:SetPoint("BOTTOMRIGHT", bodyFrame, "BOTTOMRIGHT", -6, 16)
    scrollbar:SetMinMaxValues(0, 1)
    scrollbar:SetValueStep(1)
    scrollbar:SetValue(0)
    scrollbar:SetWidth(12)
    scrollbar:SetOrientation("VERTICAL")

    -- Thumb texture
    local thumb = scrollbar:CreateTexture(nil, "OVERLAY")
    thumb:SetColorTexture(0.5, 0.5, 0.5, 0.8)
    thumb:SetSize(12, 40)
    scrollbar:SetThumbTexture(thumb)

    -- Track background
    local bg = scrollbar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.3)

    scrollbar:SetScript("OnValueChanged", function(self, value)
        scrollFrame:SetVerticalScroll(value)
    end)

    bodyFrame.scrollFrame = scrollFrame
    bodyFrame.scrollbar = scrollbar

    -- Update scrollbar range when content changes
    scrollFrame:SetScript("OnScrollRangeChanged", function(self, xrange, yrange)
        scrollbar:SetMinMaxValues(0, yrange)
        if yrange == 0 then
            scrollbar:Hide()
        else
            scrollbar:Show()
        end
    end)

    -- Mouse wheel scrolling
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local current = scrollbar:GetValue()
        local minVal, maxVal = scrollbar:GetMinMaxValues()
        if delta > 0 then
            scrollbar:SetValue(math.max(minVal, current - 40))
        else
            scrollbar:SetValue(math.min(maxVal, current + 40))
        end
    end)

    -- ========================================
    -- FOOTER (sticky - not scrollable)
    -- ========================================
    local footerFrame = CreateFrame("Frame", "NihuiIVFooter", contentFrame, "BackdropTemplate")
    footerFrame:SetPoint("BOTTOMLEFT", contentFrame, "BOTTOMLEFT", 2, 2)
    footerFrame:SetPoint("BOTTOMRIGHT", contentFrame, "BOTTOMRIGHT", -2, 2)
    footerFrame:SetHeight(45)

    -- Footer background (can be different from main)
    footerFrame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground"
    })
    footerFrame:SetBackdropColor(0.05, 0.05, 0.05, 0.7)
    contentFrame.footer = footerFrame

    -- Money display (in footer)
    local money = footerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    money:SetPoint("RIGHT", footerFrame, "RIGHT", -15, 0)
    money:SetText("0g 0s 0c")
    frame.money = money

    -- Dragging
    frame:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            self:StartMoving()
        end
    end)
    frame:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            self:StopMovingOrSizing()

            -- Save position to database
            local point, relativeTo, relativePoint, xOfs, yOfs = self:GetPoint()
            if not ns.db.framePosition then
                ns.db.framePosition = {}
            end
            ns.db.framePosition.point = point
            ns.db.framePosition.relativePoint = relativePoint
            ns.db.framePosition.xOfs = xOfs
            ns.db.framePosition.yOfs = yOfs
        end
    end)

    -- Auto-resize layout when window is resized (throttled to avoid lag)
    local resizeTimer = nil
    frame:SetScript("OnSizeChanged", function(self, width, height)
        -- Update scroll child width immediately
        if self.scrollChild and self.scrollFrame then
            local newWidth = bodyFrame:GetWidth() - 35
            self.scrollChild:SetWidth(newWidth)
            if self.itemGrid then
                self.itemGrid:SetWidth(newWidth)
            end
        end

        -- Cancel previous timer if exists
        if resizeTimer then
            resizeTimer:Cancel()
        end

        -- Debounce: only update 0.2 seconds after user stops resizing
        resizeTimer = C_Timer.NewTimer(0.2, function()
            if ns.Modules.Inventory and ns.Modules.Inventory.UpdateInventory then
                ns.Modules.Inventory.UpdateInventory()
            end
            resizeTimer = nil
        end)
    end)

    -- Resize grip (bottom-right corner - inside frame)
    local resizeButton = CreateFrame("Button", nil, frame)
    resizeButton:SetSize(16, 16)
    resizeButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, 6)
    resizeButton:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeButton:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizeButton:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resizeButton:SetFrameLevel(frame:GetFrameLevel() + 10) -- Ensure it's on top

    resizeButton:SetScript("OnMouseDown", function(self)
        frame:StartSizing("BOTTOMRIGHT")
    end)

    resizeButton:SetScript("OnMouseUp", function(self)
        frame:StopMovingOrSizing()

        -- Save size to database
        if not ns.db.frameSize then
            ns.db.frameSize = {}
        end
        ns.db.frameSize.width = frame:GetWidth()
        ns.db.frameSize.height = frame:GetHeight()
    end)

    -- Store show timers for cleanup
    local showTimers = {}

    -- OnShow handler to ensure grid is displayed with multiple retries
    local firstShow = true
    frame:SetScript("OnShow", function(self)
        -- Cancel previous show timers
        for _, timer in ipairs(showTimers) do
            if timer then timer:Cancel() end
        end
        wipe(showTimers)
        -- Force layout update
        self:SetWidth(self:GetWidth())
        self:SetHeight(self:GetHeight())

        -- Helper function to update scroll dimensions
        local function updateScrollDimensions()
            if self.scrollChild and self.scrollFrame and bodyFrame then
                local newWidth = bodyFrame:GetWidth() - 35
                if newWidth and newWidth > 0 then
                    self.scrollChild:SetWidth(newWidth)
                    if self.itemGrid then
                        self.itemGrid:SetWidth(newWidth)
                    end
                end
            end
        end

        -- Update immediately
        updateScrollDimensions()

        -- Immediate update with next frame to ensure layout is done
        table.insert(showTimers, C_Timer.NewTimer(0, function()
            if not self:IsShown() then return end
            updateScrollDimensions()
            if ns.Modules.Inventory and ns.Modules.Inventory.UpdateInventory then
                ns.Modules.Inventory.UpdateInventory()
            end
        end))

        -- Retry after 0.1s
        table.insert(showTimers, C_Timer.NewTimer(0.1, function()
            if not self:IsShown() then return end
            updateScrollDimensions()
            if ns.Modules.Inventory and ns.Modules.Inventory.UpdateInventory then
                ns.Modules.Inventory.UpdateInventory()
            end
        end))

        -- Only on first show, do extra retries
        if firstShow then
            firstShow = false
            table.insert(showTimers, C_Timer.NewTimer(0.3, function()
                if not self:IsShown() then return end
                updateScrollDimensions()
                if ns.Modules.Inventory and ns.Modules.Inventory.UpdateInventory then
                    ns.Modules.Inventory.UpdateInventory()
                end
            end))
        end
    end)

    -- OnHide handler to clean up timers
    frame:SetScript("OnHide", function(self)
        -- Cancel all show timers
        for _, timer in ipairs(showTimers) do
            if timer then timer:Cancel() end
        end
        wipe(showTimers)

        -- Cancel resize timer
        if resizeTimer then
            resizeTimer:Cancel()
            resizeTimer = nil
        end
    end)

    -- Initially hide
    frame:Hide()

    -- Register for ESC key to close
    table.insert(UISpecialFrames, "NihuiIVFrame")

    -- Store reference
    mainFrame = frame
    return frame
end

-- Show the inventory frame
function ns.Core.Frame.Show()
    if not mainFrame then
        ns.Core.Frame.Create()
    end
    mainFrame:Show()
    -- OnShow handler will trigger the updates
end

-- Hide the inventory frame
function ns.Core.Frame.Hide()
    if mainFrame then
        mainFrame:Hide()
    end
end

-- Toggle the inventory frame
function ns.Core.Frame.Toggle()
    if not mainFrame then
        ns.Core.Frame.Create()
    end
    if mainFrame:IsShown() then
        mainFrame:Hide()
    else
        mainFrame:Show()
    end
end

-- Update money display
function ns.Core.Frame.UpdateMoney()
    if not mainFrame then return end

    local money = GetMoney()
    local gold = math.floor(money / 10000)
    local silver = math.floor((money % 10000) / 100)
    local copper = money % 100

    -- Build money string with colors and icons
    local moneyString = ""

    if gold > 0 then
        moneyString = moneyString .. string.format("|cFFFFD700%d|r|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t ", gold)
    end

    if silver > 0 or gold > 0 then
        moneyString = moneyString .. string.format("|cFFC7C7CF%d|r|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:2:0|t ", silver)
    end

    moneyString = moneyString .. string.format("|cFFEDA55F%d|r|TInterface\\MoneyFrame\\UI-CopperIcon:0:0:2:0|t", copper)

    mainFrame.money:SetText(moneyString)
end

-- Update bag count
function ns.Core.Frame.UpdateCount(used, total)
    if not mainFrame then return end
    mainFrame.count:SetText(string.format("%d/%d", used, total))
end

-- Switch to bank mode (center position, split view)
function ns.Core.Frame.SetBankMode(enabled)
    if not mainFrame then
        return
    end

    if enabled then
        -- Center position for bank
        mainFrame:ClearAllPoints()
        mainFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        mainFrame:SetSize(1200, 700) -- Much wider for split view
        mainFrame.title:SetText("|cff9482c9Bank & Inventory|r")

        -- Force layout update by querying dimensions
        -- This ensures WoW's layout engine calculates the new sizes before we create child frames
        local _ = mainFrame:GetWidth()
        local _ = mainFrame:GetHeight()
        if mainFrame.content and mainFrame.content.body then
            local _ = mainFrame.content.body:GetWidth()
            local _ = mainFrame.content.body:GetHeight()
        end

        -- Hide normal inventory view
        if mainFrame.scrollFrame then
            mainFrame.scrollFrame:Hide()
        end
        if mainFrame.itemGrid then
            mainFrame.itemGrid:Hide()
        end

        -- Create split view if not exists
        if not mainFrame.splitView then
            ns:Print("DEBUG: Creating split view...")
            mainFrame.splitView = ns.UI.SplitView.Create(mainFrame.content.body, {
                orientation = "HORIZONTAL",
                defaultRatio = 0.5,
                minSize = {left = 400, right = 400}
            })

            if not mainFrame.splitView then
                ns:Print("ERROR: SplitView.Create() returned nil!")
                return
            end

            ns:Print("DEBUG: Split view created successfully")

            -- Force immediate layout update before creating children
            -- This ensures pane widths are calculated before bank grid creation
            ns:Print("DEBUG: Checking UpdateSplit...")
            if mainFrame.splitView.UpdateSplit then
                ns:Print("DEBUG: Calling UpdateSplit(0.5)...")
                mainFrame.splitView:UpdateSplit(0.5)
                ns:Print("DEBUG: UpdateSplit completed")
            else
                ns:Print("DEBUG: UpdateSplit not available")
            end

            -- Callback when resizing
            ns:Print("DEBUG: Setting onResize callback...")
            mainFrame.splitView.onResize = function(ratio, leftPane, rightPane)
                -- Update scroll widths
                if mainFrame.bankScrollChild and mainFrame.bankScrollFrame then
                    local newBankWidth = leftPane:GetWidth() - 35
                    mainFrame.bankScrollChild:SetWidth(newBankWidth)
                    if mainFrame.bankGrid then
                        mainFrame.bankGrid:SetWidth(newBankWidth)
                    end
                end

                -- Use invScrollChild instead of scrollChild in bank mode
                if mainFrame.invScrollChild and mainFrame.invScrollFrame then
                    local newInvWidth = rightPane:GetWidth() - 35
                    mainFrame.invScrollChild:SetWidth(newInvWidth)
                    if mainFrame.itemGrid then
                        mainFrame.itemGrid:SetWidth(newInvWidth)
                    end
                end

                -- Refresh grids with debounce
                C_Timer.After(0.1, function()
                    -- Refresh bank grid
                    if ns.Modules.Bank and ns.Modules.Bank.IsBankOpen() then
                        ns.Modules.Bank.UpdateBank()
                    end

                    -- Refresh inventory grid
                    if ns.Modules.Inventory and ns.Modules.Inventory.UpdateInventory then
                        ns.Modules.Inventory.UpdateInventory()
                    end
                end)
            end
            ns:Print("DEBUG: onResize callback set")

            -- Create bank tabs (bottom left of frame)
            -- TEMPORARILY DISABLED - ns.UI.Tabs.Create() is causing errors
            ns:Print("DEBUG: Skipping bank tabs creation (temporarily disabled)")
            --[[
            ns:Print("DEBUG: Creating bank tabs...")
            local bankTabs = ns.UI.Tabs.Create(
                mainFrame.content,
                {
                    {id = "personal", label = "Personal Bank", icon = "bag-main", iconType = "atlas", onSelect = function()
                        ns.Modules.Bank.SwitchBankMode("personal")
                    end},
                    {id = "guild", label = "Guild Bank", icon = "UI-GuildBankIcon-TabLogo", onSelect = function()
                        ns.Modules.Bank.SwitchBankMode("guild")
                    end}
                },
                {
                    position = "BOTTOM",
                    buttonSize = {width = 150, height = 32},
                    gap = 4
                }
            )
            ns:Print("DEBUG: Bank tabs created")
            bankTabs:SetPoint("BOTTOMLEFT", mainFrame.content, "BOTTOMLEFT", 15, 15)
            mainFrame.bankTabs = bankTabs
            ns:Print("DEBUG: Bank tabs positioned")
            --]]

            -- Create bank scroll container (left pane)
            ns:Print("DEBUG: Creating bank scroll container...")
            local bankScrollFrame = CreateFrame("ScrollFrame", "NihuiIVBankScrollFrame", mainFrame.splitView.leftPane)
            bankScrollFrame:SetPoint("TOPLEFT", mainFrame.splitView.leftPane, "TOPLEFT", 10, -10)
            bankScrollFrame:SetPoint("BOTTOMRIGHT", mainFrame.splitView.leftPane, "BOTTOMRIGHT", -25, 10)

            -- Bank scroll child
            local bankScrollChild = CreateFrame("Frame", nil, bankScrollFrame)
            local bankScrollWidth = mainFrame.splitView.leftPane:GetWidth() - 35
            if not bankScrollWidth or bankScrollWidth <= 0 then
                bankScrollWidth = 400
            end
            bankScrollChild:SetSize(bankScrollWidth, 1)
            bankScrollFrame:SetScrollChild(bankScrollChild)

            -- Bank item grid (inside scroll child)
            ns:Print("DEBUG: Creating bank grid...")
            local bankGrid = CreateFrame("Frame", "NihuiIVBankGrid", bankScrollChild)
            bankGrid:SetPoint("TOPLEFT", bankScrollChild, "TOPLEFT", 0, 0)
            bankGrid:SetSize(bankScrollWidth, 1)
            bankScrollChild.bankGrid = bankGrid
            mainFrame.bankGrid = bankGrid
            mainFrame.bankScrollFrame = bankScrollFrame
            mainFrame.bankScrollChild = bankScrollChild
            ns:Print(string.format("DEBUG: Bank grid created! mainFrame.bankGrid = %s", tostring(mainFrame.bankGrid ~= nil)))

            -- Bank scrollbar
            local bankScrollbar = CreateFrame("Slider", "NihuiIVBankScrollBar", mainFrame.splitView.leftPane)
            bankScrollbar:SetPoint("TOPRIGHT", mainFrame.splitView.leftPane, "TOPRIGHT", -6, -16)
            bankScrollbar:SetPoint("BOTTOMRIGHT", mainFrame.splitView.leftPane, "BOTTOMRIGHT", -6, 16)
            bankScrollbar:SetMinMaxValues(0, 1)
            bankScrollbar:SetValueStep(1)
            bankScrollbar:SetValue(0)
            bankScrollbar:SetWidth(12)
            bankScrollbar:SetOrientation("VERTICAL")

            local bankThumb = bankScrollbar:CreateTexture(nil, "OVERLAY")
            bankThumb:SetColorTexture(0.5, 0.5, 0.5, 0.8)
            bankThumb:SetSize(12, 40)
            bankScrollbar:SetThumbTexture(bankThumb)

            local bankScrollBg = bankScrollbar:CreateTexture(nil, "BACKGROUND")
            bankScrollBg:SetAllPoints()
            bankScrollBg:SetColorTexture(0, 0, 0, 0.3)

            bankScrollbar:SetScript("OnValueChanged", function(self, value)
                bankScrollFrame:SetVerticalScroll(value)
            end)

            bankScrollFrame:SetScript("OnScrollRangeChanged", function(self, xrange, yrange)
                bankScrollbar:SetMinMaxValues(0, yrange)
                if yrange == 0 then
                    bankScrollbar:Hide()
                else
                    bankScrollbar:Show()
                end
            end)

            bankScrollFrame:EnableMouseWheel(true)
            bankScrollFrame:SetScript("OnMouseWheel", function(self, delta)
                local current = bankScrollbar:GetValue()
                local minVal, maxVal = bankScrollbar:GetMinMaxValues()
                if delta > 0 then
                    bankScrollbar:SetValue(math.max(minVal, current - 40))
                else
                    bankScrollbar:SetValue(math.min(maxVal, current + 40))
                end
            end)

            mainFrame.bankScrollbar = bankScrollbar

            -- Move inventory scroll container to right pane
            if mainFrame.scrollFrame and mainFrame.scrollChild then
                -- Create scroll container for right pane (inventory)
                local invScrollFrame = CreateFrame("ScrollFrame", "NihuiIVInvScrollFrame", mainFrame.splitView.rightPane)
                invScrollFrame:SetPoint("TOPLEFT", mainFrame.splitView.rightPane, "TOPLEFT", 10, -10)
                invScrollFrame:SetPoint("BOTTOMRIGHT", mainFrame.splitView.rightPane, "BOTTOMRIGHT", -25, 10)

                -- Move itemGrid to new scroll child
                local invScrollChild = CreateFrame("Frame", nil, invScrollFrame)
                local invScrollWidth = mainFrame.splitView.rightPane:GetWidth() - 35
                if not invScrollWidth or invScrollWidth <= 0 then
                    invScrollWidth = 400
                end
                invScrollChild:SetSize(invScrollWidth, 1)
                invScrollFrame:SetScrollChild(invScrollChild)

                -- Move itemGrid
                mainFrame.itemGrid:SetParent(invScrollChild)
                mainFrame.itemGrid:ClearAllPoints()
                mainFrame.itemGrid:SetPoint("TOPLEFT", invScrollChild, "TOPLEFT", 0, 0)
                mainFrame.itemGrid:SetWidth(invScrollWidth)

                -- Inventory scrollbar
                local invScrollbar = CreateFrame("Slider", "NihuiIVInvScrollBar", mainFrame.splitView.rightPane)
                invScrollbar:SetPoint("TOPRIGHT", mainFrame.splitView.rightPane, "TOPRIGHT", -6, -16)
                invScrollbar:SetPoint("BOTTOMRIGHT", mainFrame.splitView.rightPane, "BOTTOMRIGHT", -6, 16)
                invScrollbar:SetMinMaxValues(0, 1)
                invScrollbar:SetValueStep(1)
                invScrollbar:SetValue(0)
                invScrollbar:SetWidth(12)
                invScrollbar:SetOrientation("VERTICAL")

                local invThumb = invScrollbar:CreateTexture(nil, "OVERLAY")
                invThumb:SetColorTexture(0.5, 0.5, 0.5, 0.8)
                invThumb:SetSize(12, 40)
                invScrollbar:SetThumbTexture(invThumb)

                local invScrollBg = invScrollbar:CreateTexture(nil, "BACKGROUND")
                invScrollBg:SetAllPoints()
                invScrollBg:SetColorTexture(0, 0, 0, 0.3)

                invScrollbar:SetScript("OnValueChanged", function(self, value)
                    invScrollFrame:SetVerticalScroll(value)
                end)

                invScrollFrame:SetScript("OnScrollRangeChanged", function(self, xrange, yrange)
                    invScrollbar:SetMinMaxValues(0, yrange)
                    if yrange == 0 then
                        invScrollbar:Hide()
                    else
                        invScrollbar:Show()
                    end
                end)

                invScrollFrame:EnableMouseWheel(true)
                invScrollFrame:SetScript("OnMouseWheel", function(self, delta)
                    local current = invScrollbar:GetValue()
                    local minVal, maxVal = invScrollbar:GetMinMaxValues()
                    if delta > 0 then
                        invScrollbar:SetValue(math.max(minVal, current - 40))
                    else
                        invScrollbar:SetValue(math.min(maxVal, current + 40))
                    end
                end)

                -- Store references
                mainFrame.invScrollFrame = invScrollFrame
                mainFrame.invScrollChild = invScrollChild
                mainFrame.invScrollbar = invScrollbar
            end
        end

        -- Show split view
        if mainFrame.splitView then
            mainFrame.splitView:Show()
        end
        if mainFrame.bankTabs then
            mainFrame.bankTabs:Show()
        end

    else
        -- Bottom right for bags
        mainFrame:ClearAllPoints()
        mainFrame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -50, 150)
        mainFrame:SetSize(560, 600)
        mainFrame.title:SetText("|cff9482c9Inventory|r")

        -- Hide split view
        if mainFrame.splitView then
            mainFrame.splitView:Hide()
        end
        if mainFrame.bankTabs then
            mainFrame.bankTabs:Hide()
        end

        -- Show normal inventory view
        if mainFrame.scrollFrame then
            mainFrame.scrollFrame:Show()
        end
        if mainFrame.itemGrid then
            mainFrame.itemGrid:SetParent(mainFrame.scrollChild)
            mainFrame.itemGrid:Show()
        end
    end
end
