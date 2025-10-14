-- components/currency.lua - Currency display component (pure logic, no layout)
-- Extracted from BetterBags - handles event currencies (Bronze, etc.)
local addonName, ns = ...

ns.Components = ns.Components or {}
ns.Components.Currency = {}

-- Currency item prototype
local CurrencyItemProto = {}

function CurrencyItemProto:Release()
    if self.frame then
        self.frame:ClearAllPoints()
        self.frame:Hide()
    end
end

function CurrencyItemProto:SetTexture(textureID)
    if self.icon then
        self.icon:SetTexture(textureID)
    end
end

function CurrencyItemProto:SetCount(count)
    if self.count then
        self.count:SetText(BreakUpLargeNumbers(count))

        -- CRITICAL: Recalculate frame width after text is set
        -- This ensures proper alignment of multiple currencies
        if self.frame and self.icon then
            local textWidth = self.count:GetStringWidth()
            self.frame:SetWidth(18 + 5 + textWidth)
        end
    end
end

function CurrencyItemProto:SetName(name)
    if self.name then
        self.name:SetText(name)
    end
end

function CurrencyItemProto:GetFrame()
    return self.frame
end

-- Currency grid prototype
local CurrencyGridProto = {}

function CurrencyGridProto:Update()
    -- Clear existing icons
    for _, item in pairs(self.iconItems) do
        item:Release()
    end
    self.iconItems = {}

    local index = 1
    local showCount = 0
    local currencyListSize = C_CurrencyInfo.GetCurrencyListSize()

    repeat
        local info = C_CurrencyInfo.GetCurrencyListInfo(index)

        if info then
            -- Expand headers to see all currencies
            if info.isHeader then
                C_CurrencyInfo.ExpandCurrencyList(index, true)
            end

            -- Only show currencies marked as "show in backpack" (max 7)
            if info.isShowInBackpack and not info.isHeader and showCount < 7 then
                showCount = showCount + 1

                -- Get or create currency item
                local item = self:GetCurrencyItem(index, info)
                if item then
                    item:SetTexture(info.iconFileID)
                    item:SetCount(info.quantity)

                    -- Position in row (RIGHT to LEFT)
                    if showCount == 1 then
                        item:GetFrame():SetPoint("RIGHT", self.container, "RIGHT", 0, 0)
                    else
                        item:GetFrame():SetPoint("RIGHT", self.iconItems[showCount - 1]:GetFrame(), "LEFT", -8, 0)
                    end

                    item:GetFrame():Show()
                    self.iconItems[showCount] = item
                end
            end
        end

        index = index + 1
    until index > currencyListSize

    -- Calculate total width
    if showCount > 0 then
        local totalWidth = 0
        for i = 1, showCount do
            local item = self.iconItems[i]
            if item and item:GetFrame() then
                totalWidth = totalWidth + item:GetFrame():GetWidth()
                if i > 1 then
                    totalWidth = totalWidth + 8 -- Spacing
                end
            end
        end
        self.container:SetWidth(totalWidth)
    else
        self.container:SetWidth(1)
    end

    -- Callback
    if self.onUpdate then
        self.onUpdate(showCount)
    end
end

function CurrencyGridProto:GetCurrencyItem(index, info)
    if not info then return nil end

    -- Create new currency item
    local item = setmetatable({}, { __index = CurrencyItemProto })

    local frame = CreateFrame("Frame", nil, self.container)
    frame:SetSize(80, 20)
    item.frame = frame

    -- Icon texture
    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(18, 18)
    icon:SetPoint("LEFT", frame, "LEFT", 0, 0)
    item.icon = icon

    -- Count text
    local count = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    count:SetPoint("LEFT", icon, "RIGHT", 5, 0)
    item.count = count

    -- Store currency index for tooltip
    frame.currencyIndex = index

    -- Tooltip on hover
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetCurrencyToken(self.currencyIndex)
        GameTooltip:Show()
    end)

    frame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Calculate width based on text
    local textWidth = count:GetStringWidth()
    frame:SetWidth(18 + 5 + textWidth)

    return item
end

function CurrencyGridProto:Show()
    if self.container then
        self.container:Show()
    end
end

function CurrencyGridProto:Hide()
    if self.container then
        self.container:Hide()
    end
end

function CurrencyGridProto:SetParent(parent)
    if self.container then
        self.container:SetParent(parent)
    end
end

function CurrencyGridProto:SetPoint(...)
    if self.container then
        self.container:SetPoint(...)
    end
end

function CurrencyGridProto:GetContainer()
    return self.container
end

function CurrencyGridProto:Destroy()
    if self.eventFrame then
        self.eventFrame:UnregisterAllEvents()
        self.eventFrame:SetScript("OnEvent", nil)
    end

    for _, item in pairs(self.iconItems) do
        item:Release()
    end

    if self.container then
        self.container:Hide()
        self.container = nil
    end
end

-- Create a new currency grid component
-- @param parent - Parent frame (optional)
-- @param onUpdate - Callback function(currencyCount) when currencies update
-- @return Currency grid component
function ns.Components.Currency.Create(parent, onUpdate)
    local grid = setmetatable({}, { __index = CurrencyGridProto })
    grid.iconItems = {}
    grid.onUpdate = onUpdate

    -- Create container frame
    local container = CreateFrame("Frame", nil, parent or UIParent)
    container:SetHeight(20)
    container:SetWidth(1)
    grid.container = container

    -- Register for currency updates
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
    eventFrame:SetScript("OnEvent", function(self, event)
        if event == "CURRENCY_DISPLAY_UPDATE" then
            grid:Update()
        end
    end)
    grid.eventFrame = eventFrame

    -- Initial update
    grid:Update()

    container:Show()

    return grid
end

-- Get all currencies that should be shown in backpack
-- @return table of {index, name, iconFileID, quantity, isHeader}
function ns.Components.Currency.GetBackpackCurrencies()
    local currencies = {}
    local index = 1
    local currencyListSize = C_CurrencyInfo.GetCurrencyListSize()

    repeat
        local info = C_CurrencyInfo.GetCurrencyListInfo(index)

        if info then
            -- Expand headers
            if info.isHeader then
                C_CurrencyInfo.ExpandCurrencyList(index, true)
            end

            -- Only currencies marked for backpack
            if info.isShowInBackpack and not info.isHeader then
                table.insert(currencies, {
                    index = index,
                    name = info.name,
                    iconFileID = info.iconFileID,
                    quantity = info.quantity,
                    isHeader = info.isHeader,
                })
            end
        end

        index = index + 1
    until index > currencyListSize

    return currencies
end
