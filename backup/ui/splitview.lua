-- ui/splitview.lua - Split view with resizable divider (like shadcn resizable)
local addonName, ns = ...

ns.UI.SplitView = {}

-- Create a split view container with resizable divider
-- Usage: ns.UI.SplitView.Create(parent, options)
-- options = {
--   orientation = "HORIZONTAL" or "VERTICAL" (default: HORIZONTAL)
--   defaultRatio = 0.5 (default split ratio, 0.5 = 50/50)
--   minSize = {left = 300, right = 300} (minimum sizes)
-- }
function ns.UI.SplitView.Create(parent, options)
    options = options or {}
    local orientation = options.orientation or "HORIZONTAL" -- HORIZONTAL = left/right, VERTICAL = top/bottom
    local defaultRatio = options.defaultRatio or 0.5
    local minSize = options.minSize or {left = 300, right = 300}

    local splitView = CreateFrame("Frame", nil, parent)
    splitView:SetAllPoints(parent)

    -- Left/Top pane
    local leftPane = CreateFrame("Frame", nil, splitView, "BackdropTemplate")
    leftPane:SetPoint("TOPLEFT", splitView, "TOPLEFT", 0, 0)
    leftPane:SetPoint("BOTTOMLEFT", splitView, "BOTTOMLEFT", 0, 0)

    -- Right/Bottom pane
    local rightPane = CreateFrame("Frame", nil, splitView, "BackdropTemplate")
    rightPane:SetPoint("TOPRIGHT", splitView, "TOPRIGHT", 0, 0)
    rightPane:SetPoint("BOTTOMRIGHT", splitView, "BOTTOMRIGHT", 0, 0)

    -- Resizable divider (handle)
    local divider = CreateFrame("Frame", nil, splitView, "BackdropTemplate")
    divider:SetFrameLevel(splitView:GetFrameLevel() + 5) -- On top

    if orientation == "HORIZONTAL" then
        divider:SetSize(8, 100) -- Width 8px, height will be set dynamically
        divider:SetPoint("TOP", splitView, "TOP", 0, 0)
        divider:SetPoint("BOTTOM", splitView, "BOTTOM", 0, 0)
    else
        divider:SetSize(100, 8) -- Height 8px, width will be set dynamically
        divider:SetPoint("LEFT", splitView, "LEFT", 0, 0)
        divider:SetPoint("RIGHT", splitView, "RIGHT", 0, 0)
    end

    -- Divider backdrop
    divider:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    divider:SetBackdropColor(0.2, 0.2, 0.2, 0.5)
    divider:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)

    -- Divider icon (resize indicator)
    local dividerIcon = divider:CreateTexture(nil, "OVERLAY")
    dividerIcon:SetSize(16, 16)
    dividerIcon:SetPoint("CENTER", divider, "CENTER", 0, 0)

    if orientation == "HORIZONTAL" then
        dividerIcon:SetAtlas("charactercreate-customize-dropdownbox-arrows-side") -- Left/right arrows
        dividerIcon:SetRotation(math.rad(90)) -- Rotate 90 degrees
    else
        dividerIcon:SetAtlas("charactercreate-customize-dropdownbox-arrows") -- Up/down arrows
    end

    -- Highlight on hover
    divider:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.3, 0.3, 0.3, 0.8)
        self:SetBackdropBorderColor(0.58, 0.51, 0.79, 1) -- Nihui purple

        if orientation == "HORIZONTAL" then
            SetCursor("CAST_CURSOR") -- Shows resize cursor
        else
            SetCursor("CAST_CURSOR")
        end
    end)

    divider:SetScript("OnLeave", function(self)
        if not self.isDragging then
            self:SetBackdropColor(0.2, 0.2, 0.2, 0.5)
            self:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)
        end
        ResetCursor()
    end)

    -- Dragging behavior
    divider:EnableMouse(true)
    divider:SetMovable(true)
    divider.isDragging = false

    divider:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            self.isDragging = true
            self:SetBackdropColor(0.58, 0.51, 0.79, 0.5) -- Nihui purple while dragging
        end
    end)

    divider:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            self.isDragging = false
            self:SetBackdropColor(0.2, 0.2, 0.2, 0.5)
        end
    end)

    divider:SetScript("OnUpdate", function(self)
        if not self.isDragging then return end

        local parentWidth = splitView:GetWidth()
        local parentHeight = splitView:GetHeight()
        local mouseX, mouseY = GetCursorPosition()
        local scale = splitView:GetEffectiveScale()
        mouseX = mouseX / scale
        mouseY = mouseY / scale

        local parentLeft = splitView:GetLeft()
        local parentBottom = splitView:GetBottom()

        if orientation == "HORIZONTAL" then
            -- Calculate new ratio based on mouse X position
            local relativeX = mouseX - parentLeft
            local ratio = relativeX / parentWidth

            -- Clamp ratio to min sizes
            local minLeftRatio = minSize.left / parentWidth
            local minRightRatio = minSize.right / parentWidth
            ratio = math.max(minLeftRatio, math.min(1 - minRightRatio, ratio))

            -- Update split
            splitView:UpdateSplit(ratio)
        else
            -- Calculate new ratio based on mouse Y position
            local relativeY = mouseY - parentBottom
            local ratio = relativeY / parentHeight

            -- Clamp ratio to min sizes
            local minTopRatio = minSize.top / parentHeight
            local minBottomRatio = minSize.bottom / parentHeight
            ratio = math.max(minBottomRatio, math.min(1 - minTopRatio, ratio))

            -- Update split
            splitView:UpdateSplit(ratio)
        end
    end)

    -- Update split function
    function splitView:UpdateSplit(ratio)
        self.currentRatio = ratio

        if orientation == "HORIZONTAL" then
            local totalWidth = self:GetWidth()
            local leftWidth = totalWidth * ratio
            local rightWidth = totalWidth * (1 - ratio)

            -- Update left pane width
            leftPane:SetWidth(leftWidth - 4) -- -4 for half of divider width

            -- Update right pane width
            rightPane:SetWidth(rightWidth - 4)

            -- Position divider
            divider:ClearAllPoints()
            divider:SetPoint("TOP", self, "TOP", 0, 0)
            divider:SetPoint("BOTTOM", self, "BOTTOM", 0, 0)
            divider:SetPoint("LEFT", self, "LEFT", leftWidth - 4, 0)
        else
            local totalHeight = self:GetHeight()
            local topHeight = totalHeight * (1 - ratio) -- Inverted for top/bottom
            local bottomHeight = totalHeight * ratio

            -- Update top pane height
            leftPane:SetHeight(topHeight - 4)

            -- Update bottom pane height
            rightPane:SetHeight(bottomHeight - 4)

            -- Position divider
            divider:ClearAllPoints()
            divider:SetPoint("LEFT", self, "LEFT", 0, 0)
            divider:SetPoint("RIGHT", self, "RIGHT", 0, 0)
            divider:SetPoint("BOTTOM", self, "BOTTOM", 0, bottomHeight - 4)
        end

        -- Trigger callback if provided
        if self.onResize then
            self.onResize(ratio, leftPane, rightPane)
        end
    end

    -- Initialize split with default ratio
    splitView.currentRatio = defaultRatio
    splitView.orientation = orientation
    splitView.leftPane = leftPane
    splitView.rightPane = rightPane
    splitView.divider = divider

    -- Update on parent resize
    splitView:SetScript("OnSizeChanged", function(self)
        self:UpdateSplit(self.currentRatio)
    end)

    -- Initial update (delayed to ensure parent size is set)
    C_Timer.After(0, function()
        splitView:UpdateSplit(defaultRatio)
    end)

    return splitView
end
