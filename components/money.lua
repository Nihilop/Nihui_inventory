-- components/money.lua - Money display component (pure logic, no layout)
-- Extracted from BetterBags - handles money display, formatting, and interactions
local addonName, ns = ...

ns.Components = ns.Components or {}
ns.Components.Money = {}

-- Money component prototype
local MoneyProto = {}

-- Update money display
function MoneyProto:Update()
    local currentMoney = 0

    if self.isWarbank then
        -- Warband bank money
        currentMoney = C_Bank and C_Bank.FetchDepositedMoney
            and C_Bank.FetchDepositedMoney(Enum.BankType.Account) or 0
    else
        -- Character money
        currentMoney = GetMoney()
    end

    -- Break down into gold, silver, copper
    local gold = floor(currentMoney / 1e4)
    local silver = floor(currentMoney / 100 % 100)
    local copper = currentMoney % 100

    -- Update buttons
    if self.goldButton then
        self.goldButton:SetText(BreakUpLargeNumbers(gold))
    end

    if self.silverButton then
        self.silverButton:SetText(tostring(silver))
        self.silverButton:SetWidth(self.silverButton:GetTextWidth() + 13)
    end

    if self.copperButton then
        self.copperButton:SetText(tostring(copper))
        self.copperButton:SetWidth(self.copperButton:GetTextWidth() + 13)
    end

    -- Store values for external access
    self.gold = gold
    self.silver = silver
    self.copper = copper
    self.total = currentMoney
end

-- Show the money frame
function MoneyProto:Show()
    if self.frame then
        self.frame:Show()
    end
end

-- Hide the money frame
function MoneyProto:Hide()
    if self.frame then
        self.frame:Hide()
    end
end

-- Set parent frame
function MoneyProto:SetParent(parent)
    if self.frame then
        self.frame:SetParent(parent)
    end
end

-- Set point
function MoneyProto:SetPoint(...)
    if self.frame then
        self.frame:SetPoint(...)
    end
end

-- Get frame
function MoneyProto:GetFrame()
    return self.frame
end

-- Destroy the money component
function MoneyProto:Destroy()
    if self.eventFrame then
        self.eventFrame:UnregisterAllEvents()
        self.eventFrame:SetScript("OnEvent", nil)
    end

    if self.frame then
        self.frame:Hide()
        self.frame = nil
    end
end

-- Create a coin button (gold, silver, or copper)
local function CreateCoinButton(kind, parent)
    local button = CreateFrame("Button", nil, parent)
    button:EnableMouse(false)
    button:SetSize(32, 13)

    if kind == "copper" then
        button:SetPoint("RIGHT", 0, 0)
    else
        button:SetPoint("RIGHT", parent, "LEFT", -4, 0)
    end

    -- Set coin texture
    button:SetNormalAtlas("coin-" .. kind)
    button:GetNormalTexture():ClearAllPoints()
    button:GetNormalTexture():SetPoint("RIGHT", 0, 0)
    button:GetNormalTexture():SetSize(13, 13)

    -- Create font string for value
    local fontString = button:CreateFontString(nil, "OVERLAY")
    button:SetFontString(fontString)
    button:SetNormalFontObject("Number12Font")
    fontString:SetPoint("RIGHT", -13, 0)

    button:Show()
    return button
end

-- Create a new money component
-- @param parent - Parent frame (optional)
-- @param isWarbank - true for warband bank money, false for character money
-- @return Money component
function ns.Components.Money.Create(parent, isWarbank)
    local money = setmetatable({}, { __index = MoneyProto })
    money.isWarbank = isWarbank or false

    -- Create main frame
    local frame = CreateFrame("Frame", nil, parent or UIParent)
    frame:SetSize(128, 18)
    money.frame = frame

    -- Create overlay for click interactions
    local overlay = CreateFrame("Frame", nil, frame)
    overlay:SetAllPoints()
    overlay:SetAlpha(0.5)
    overlay:EnableMouse(true)
    money.overlay = overlay

    -- Click handlers (BetterBags behavior)
    overlay:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            if money.isWarbank then
                -- Warbank: withdraw money
                StaticPopup_Show("BANK_MONEY_WITHDRAW", nil, nil, {bankType = Enum.BankType.Account})
            else
                -- Character: pick up money
                StaticPopup_Show("PICKUP_MONEY")
            end
        elseif button == "RightButton" then
            if money.isWarbank then
                -- Warbank: deposit money
                StaticPopup_Show("BANK_MONEY_DEPOSIT", nil, nil, {bankType = Enum.BankType.Account})
            end
        end
    end)

    -- Tooltip
    overlay:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP", 0, 5)
        if money.isWarbank then
            GameTooltip:AddDoubleLine("Left Click", "Withdraw money", 1, 0.81, 0, 1, 1, 1)
            GameTooltip:AddDoubleLine("Right Click", "Deposit money", 1, 0.81, 0, 1, 1, 1)
        else
            GameTooltip:AddDoubleLine("Left Click", "Pick up money", 1, 0.81, 0, 1, 1, 1)
        end
        GameTooltip:Show()
    end)

    overlay:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Add highlight texture
    local highlight = overlay:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    highlight:SetBlendMode("ADD")
    highlight:SetAllPoints()

    -- Create coin buttons (right to left: copper, silver, gold)
    money.copperButton = CreateCoinButton("copper", frame)
    money.silverButton = CreateCoinButton("silver", money.copperButton)
    money.goldButton = CreateCoinButton("gold", money.silverButton)

    -- Register for money updates
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_MONEY")
    eventFrame:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_MONEY" then
            money:Update()
        end
    end)
    money.eventFrame = eventFrame

    -- Initial update
    money:Update()

    frame:Show()

    return money
end

-- Get formatted money string (simple text format)
-- @param amount - Money amount in copper
-- @param abbreviated - Use abbreviated format (K, M)
-- @return Formatted string
function ns.Components.Money.GetFormattedString(amount, abbreviated)
    return GetMoneyString(amount, abbreviated)
end

-- Break down money into gold, silver, copper
-- @param amount - Money amount in copper
-- @return gold, silver, copper
function ns.Components.Money.BreakDown(amount)
    local gold = floor(amount / 1e4)
    local silver = floor(amount / 100 % 100)
    local copper = amount % 100
    return gold, silver, copper
end
