-- ui/scrollbar.lua - Modern Blizzard ScrollBox integration
local addonName, ns = ...

ns.UI.Scrollbar = {}

local scrollBox = nil
local scrollBar = nil

-- Create modern scroll container
function ns.UI.Scrollbar.Create(parent)
    if scrollBox then
        return scrollBox, scrollBar
    end

    -- Create ScrollBox (modern scroll container)
    scrollBox = CreateFrame("Frame", "NihuiIVScrollBox", parent, "WowScrollBoxList")
    scrollBox:SetAllPoints(parent)

    -- Create ScrollBar
    scrollBar = CreateFrame("EventFrame", "NihuiIVScrollBar", parent, "MinimalScrollBar")
    scrollBar:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -5, -5)
    scrollBar:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -5, 5)
    scrollBar:SetWidth(12)

    -- Hide scrollbar by default (will show when needed)
    scrollBar:Hide()

    -- Create scroll view
    local scrollView = CreateScrollBoxListLinearView()
    scrollView:SetElementInitializer("Frame", function(frame, elementData)
        -- This will be called for each "row" in the scroll
        -- For inventory, each row contains multiple item slots
        ns.UI.Scrollbar.InitializeRow(frame, elementData)
    end)

    -- Initialize ScrollBox with ScrollBar and View
    ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, scrollView)

    -- Store reference
    ns.UI.Scrollbar.scrollBox = scrollBox
    ns.UI.Scrollbar.scrollBar = scrollBar
    ns.UI.Scrollbar.scrollView = scrollView

    return scrollBox, scrollBar
end

-- Initialize a row in the scroll view
function ns.UI.Scrollbar.InitializeRow(frame, elementData)
    if not frame.itemSlots then
        frame.itemSlots = {}
    end

    local columns = ns.db.columns or 12
    local slotSize = ns.db.slotSize or 40
    local gap = ns.db.slotGap or 4
    local totalSlotSize = slotSize + gap

    -- Create slots for this row if needed
    for col = 1, columns do
        if not frame.itemSlots[col] then
            local slot = CreateFrame("Frame", nil, frame)
            slot:SetSize(slotSize, slotSize)
            slot:SetPoint("LEFT", frame, "LEFT", (col - 1) * totalSlotSize, 0)
            frame.itemSlots[col] = slot
        end
    end

    -- Update slots with item data from this row
    if elementData and elementData.items then
        for col, itemData in ipairs(elementData.items) do
            if frame.itemSlots[col] and itemData then
                -- Update slot with item
                ns.UI.Slots.UpdateSlot(frame.itemSlots[col], itemData)
                frame.itemSlots[col]:Show()
            elseif frame.itemSlots[col] then
                frame.itemSlots[col]:Hide()
            end
        end
    end
end

-- Update scroll content with item data
function ns.UI.Scrollbar.UpdateContent(items)
    if not scrollBox or not ns.UI.Scrollbar.scrollView then
        return
    end

    local columns = ns.db.columns or 12
    local slotSize = ns.db.slotSize or 40
    local gap = ns.db.slotGap or 4
    local totalSlotSize = slotSize + gap

    -- Convert flat item list into rows
    local rows = {}
    local currentRow = {}

    for i, item in ipairs(items) do
        table.insert(currentRow, item)

        -- When row is full, add to rows
        if #currentRow >= columns then
            table.insert(rows, {items = currentRow, height = totalSlotSize})
            currentRow = {}
        end
    end

    -- Add remaining items as last row
    if #currentRow > 0 then
        table.insert(rows, {items = currentRow, height = totalSlotSize})
    end

    -- Create data provider
    local dataProvider = CreateDataProvider()
    for _, rowData in ipairs(rows) do
        dataProvider:Insert(rowData)
    end

    -- Set data provider to scroll view
    scrollBox:SetDataProvider(dataProvider)

    -- Show/hide scrollbar based on content height
    local contentHeight = #rows * totalSlotSize
    local visibleHeight = scrollBox:GetHeight()

    if contentHeight > visibleHeight then
        scrollBar:Show()
    else
        scrollBar:Hide()
    end
end

-- Scroll to top
function ns.UI.Scrollbar.ScrollToTop()
    if scrollBox then
        scrollBox:ScrollToBegin()
    end
end

-- Scroll to bottom
function ns.UI.Scrollbar.ScrollToBottom()
    if scrollBox then
        scrollBox:ScrollToEnd()
    end
end
